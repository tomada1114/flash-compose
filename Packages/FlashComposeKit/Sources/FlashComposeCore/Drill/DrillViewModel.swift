import Foundation
import Observation

/// The drill's view model (D1–D3, E1, E2): it starts the day, deals the card, reveals it,
/// takes the grade, saves it, and deals the next — composing the catalog, the progress
/// store, the queue, and the scope behind one model the drill screen only renders
/// (`docs/architecture.md` › Core flows, › Session).
///
/// Built once by ``AppModel`` over the ``ProgressStore`` port and the shared
/// ``ScopeViewModel``, reading nothing until ``start()``. The session — the card on
/// screen, its face, and the waiting re-asks — lives here in memory and is never stored,
/// so a relaunch starts a fresh one (`docs/product/requirements.md` §3.2).
///
/// Save, then advance: a grade is recorded in one ``ProgressStore/record(answer:progress:)``
/// call, and only once it returns does the next card appear, with the counts in the same
/// update. A failed save changes nothing and reports ``DrillFailure/saveFailed`` (E2).
/// Only a card's first answer of a practice day moves its schedule, never a re-ask
/// (§3.3).
///
/// Action-shaped: the view calls ``start()`` and ``watchPracticeDay()`` from `.task`,
/// ``reveal()`` and ``grade(_:)`` from the buttons, ``sceneDidBecomeActive()`` when the
/// scene becomes active, ``scopeDidChange()`` when ``ScopeViewModel/selection`` changes,
/// ``retry()`` from E1, and ``dismissFailure()`` from E2.
@MainActor
@Observable
public final class DrillViewModel {
    /// Which face of the drill is up once it has started.
    public enum Face: Hashable, Sendable {
        /// D2: the answer and the three grades.
        case answer
        /// D3: nothing is left today (`docs/product/requirements.md` §3.5).
        case done
        /// D1: the prompt and the reveal.
        case question
    }

    /// Where the drill stands.
    public enum Phase: Hashable, Sendable {
        /// E1: the catalog or the progress could not be loaded; ``retry()`` starts again.
        case failed
        /// The drill has started and shows `Face`.
        case ready(Face)
        /// Nothing has loaded yet: the launch screen and then the plain background show.
        case starting
    }

    /// What the queue deals from besides the scope: start-up's reads, and the practice
    /// day they are dealt for.
    private struct Deck {
        let catalog: CardCatalog
        let scopeCatalog: ScopeCatalog
        let topicNames: [TopicID: String]
        var progress: [CardID: CardProgress]
        var answeredToday: Set<CardID> = []
        var today: PracticeDay
        var session: DrillSession
    }

    /// Where the drill stands; ``Phase/starting`` until ``start()`` finishes.
    public private(set) var phase = Phase.starting
    /// The card on screen; `nil` before the start-up and on the done face.
    public private(set) var card: DrillCard?
    /// The header's counts and the pile the card on screen came from, changed in the same
    /// update as ``card``.
    public private(set) var counts = HeaderCounts(new: 0, review: 0, reAsk: 0, currentPile: nil)
    /// The failure to present (E2), or `nil`. Cleared by ``dismissFailure()``.
    public private(set) var failure: DrillFailure?
    /// Whether a grade is being saved: every grade tap until the next card is ignored.
    public private(set) var isGrading = false

    private var deck: Deck?
    /// How many start-ups have begun; one that returns after a newer one began drops its
    /// result.
    @ObservationIgnored private var startGeneration = 0
    /// The phase before the first start-up in flight, which a cancelled one restores.
    @ObservationIgnored private var phaseBeforeStart: Phase?
    /// Measures the time since the card on screen was dealt.
    @ObservationIgnored private var stopwatch: (@Sendable () -> Duration)?
    /// The seconds the question was on screen before the reveal, kept for the grade.
    @ObservationIgnored private var secondsToReveal: Double = 0
    @ObservationIgnored private var generator: any RandomNumberGenerator

    private let store: any ProgressStore
    private let scope: ScopeViewModel
    private let now: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone
    private let locale: Locale
    private let clock: any Clock<Duration>
    private let loadCatalog: @Sendable () async throws(CatalogError) -> CardCatalog
    private let tuning: Tuning
    private let grading: DrillGrading

    /// Builds the model over `store` and the shared `scope`, reading nothing until
    /// ``start()``. `now` stamps each answer; `environment` holds everything else the
    /// drill reads from the world.
    public init(
        store: any ProgressStore,
        scope: ScopeViewModel,
        now: @escaping @Sendable () -> Date = { Date() },
        environment: DrillEnvironment = DrillEnvironment(),
    ) {
        self.store = store
        self.scope = scope
        self.now = now
        timeZone = environment.timeZone
        locale = environment.locale
        clock = environment.clock
        generator = environment.generator
        loadCatalog = environment.loadCatalog
        tuning = environment.tuning
        grading = DrillGrading(scheduler: FSRSScheduler(tuning: environment.tuning.fsrs))
    }

    /// Loads the catalog and the progress, builds today's queue, and shows the first card
    /// (D1) or the done face (D3); either load failing shows E1.
    ///
    /// Once the drill has started this does nothing, so a view appearing again keeps the
    /// session. Safe to call while a start-up is in flight: the newest one wins, and an
    /// older one that returns later drops its result. A cancelled start-up is a no-op —
    /// ``phase`` goes back to what it was and no failure shows — read from
    /// `Task.isCancelled` after the loads, since neither load can report cancellation
    /// (`designing-errors` › Cancellation propagates).
    public func start() async {
        if case .ready = phase {
            return
        }
        phaseBeforeStart = phaseBeforeStart ?? phase
        phase = .starting
        startGeneration += 1
        let generation = startGeneration
        let outcome = await DrillStartup.read(catalog: loadCatalog, store: store)
        guard generation == startGeneration else {
            return
        }
        defer { phaseBeforeStart = nil }
        guard !Task.isCancelled else {
            phase = phaseBeforeStart ?? .starting
            return
        }
        switch outcome {
        case let .success(loaded):
            begin(with: loaded)

        case let .failure(reason):
            phase = .failed
            AppLog.drill.error("start failed: \(String(describing: reason), privacy: .public)")
        }
    }

    /// Repeats the start-up from E1; on any other phase it does nothing.
    public func retry() async {
        guard phase == .failed else {
            return
        }
        await start()
    }

    /// Shows the answer face and keeps how long the question was on screen. A second tap
    /// — on the answer face, or anywhere but the question face — does nothing, so the
    /// time is never measured twice.
    public func reveal() {
        guard phase == .ready(.question) else {
            return
        }
        secondsToReveal = stopwatch.map { $0() / .seconds(1) } ?? 0
        phase = .ready(.answer)
    }

    /// Records `grade` for the card on screen, then deals the next card.
    ///
    /// Only on the answer face, and only once: from this call until the next card is on
    /// screen every other grade is ignored. The schedule moves only on the card's first
    /// answer of the practice day the grade falls on, never on a re-ask; the answer and
    /// the card's progress go to the store in one call. If that call throws, nothing
    /// changes — the same card on the same face, the same counts, no re-ask set — and
    /// ``failure`` is set; grading again retries.
    public func grade(_ grade: Grade) async {
        guard phase == .ready(.answer), !isGrading, let shown = card, let current = deck else {
            return
        }
        isGrading = true
        defer { isGrading = false }
        let gradedAt = now()
        let graded = grading.answer(
            grade,
            of: shown,
            previous: current.progress[shown.card.id],
            at: GradeMoment(
                instant: gradedAt,
                day: PracticeDay(instant: gradedAt, timeZone: timeZone()),
            ),
            secondsToReveal: secondsToReveal,
        )
        do {
            try await store.record(answer: graded.answer, progress: graded.progress)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            failure = .saveFailed
            AppLog.drill.error("record failed: \(String(describing: error), privacy: .public)")
            return
        }
        apply(graded, grade: grade)
    }

    /// Clears ``failure`` once the alert has been dismissed.
    public func dismissFailure() {
        failure = nil
    }

    /// Re-reads the practice day when the scene becomes active (`docs/product/ux-flows.md`
    /// F5): after 04:00, 復習 is recounted, and the done face deals a review that fell due.
    public func sceneDidBecomeActive() {
        reevaluateToday()
    }

    /// Follows a change of ``ScopeViewModel/selection``: 新規 is recounted, the card on
    /// screen stays, and the done face deals a new card when the scope now holds one
    /// (`docs/product/ux-flows.md` F3).
    public func scopeDidChange() {
        refresh()
    }

    /// Wakes at each 04:00 in the current time zone and re-reads the practice day, as
    /// ``sceneDidBecomeActive()`` does, until the calling task is cancelled.
    public func watchPracticeDay() async {
        while !Task.isCancelled {
            let instant = now()
            let boundary = PracticeDayBoundary.next(after: instant, in: timeZone())
            do {
                try await clock.sleep(for: .seconds(boundary.timeIntervalSince(instant)))
            } catch {
                // Cancelled: the view that started the watch has gone.
                return
            }
            reevaluateToday()
        }
    }

    private func begin(with loaded: DrillStartup.Loaded) {
        let catalog = loaded.catalog
        let progress = Dictionary(loaded.progress.map { ($0.cardID, $0) }) { _, later in later }
        let scopeCatalog = ScopeCatalog(catalog)
        deck = Deck(
            catalog: catalog,
            scopeCatalog: scopeCatalog,
            topicNames: Dictionary(catalog.topics.map { ($0.id, $0.name) }) { first, _ in first },
            progress: progress,
            today: PracticeDay(instant: now(), timeZone: timeZone()),
            session: DrillSession(tuning: tuning),
        )
        scope.load(catalog: scopeCatalog, seenCardIDs: Set(progress.keys))
        dealNext()
    }

    /// Deals the next card — or none, the done face — and recounts, in one update.
    private func dealNext() {
        guard let input = queueInput() else {
            return
        }
        let dealt = deck?.session.deal(for: input, using: &generator)
        card = dealt.map { dealt in
            grading.present(
                dealt,
                in: input,
                topicName: deck?.topicNames[dealt.card.topic] ?? dealt.card.topic.rawValue,
            )
        }
        stopwatch = clock.stopwatch()
        secondsToReveal = 0
        phase = .ready(dealt == nil ? .done : .question)
        recount(input)
    }

    /// After the day or the scope changed: the done face deals again; a card on screen
    /// stays as it is, and only the counts follow.
    private func refresh() {
        if phase == .ready(.done) {
            dealNext()
        } else if let input = queueInput() {
            recount(input)
        }
    }

    private func reevaluateToday() {
        guard let today = deck?.today else {
            return
        }
        let day = PracticeDay(instant: now(), timeZone: timeZone())
        guard day != today else {
            return
        }
        startDay(day)
        refresh()
    }

    /// Moves the queue to `day`: nothing has been answered on it yet.
    private func startDay(_ day: PracticeDay) {
        deck?.today = day
        deck?.answeredToday = []
    }

    private func recount(_ input: QueueInput) {
        if let counted = deck?.session.counts(for: input) {
            counts = counted
        }
    }

    /// What the queue reads now: the deck, and the new cards the scope allows.
    private func queueInput() -> QueueInput? {
        guard let current = deck else {
            return nil
        }
        let selection = scope.selection
        return QueueInput(
            today: current.today,
            catalog: current.catalog,
            progress: current.progress,
            candidates: current.catalog.cards.filter { selection.includes($0) },
            answeredToday: current.answeredToday,
        )
    }

    /// Applies a saved grade: the queue moves forward (never back) to its practice day, a
    /// moved card's progress follows (and today's answers, if it was today's), the queue
    /// records it, the scope recounts a card no longer unseen, and the next card is dealt.
    private func apply(_ graded: DrillGrading.GradedAnswer, grade: Grade) {
        let id = graded.answer.cardID
        let day = graded.answer.practiceDay
        if let today = deck?.today, today < day {
            startDay(day)
        }
        if graded.moved {
            deck?.progress[id] = graded.progress
            if deck?.today == day {
                deck?.answeredToday.insert(id)
            }
        }
        deck?.session.record(grade)
        if graded.wasUnseen, let current = deck {
            scope.load(catalog: current.scopeCatalog, seenCardIDs: Set(current.progress.keys))
        }
        dealNext()
    }
}

// MARK: - What the faces show

extension DrillViewModel {
    /// The face that is up, or `nil` before the drill has started.
    public var face: Face? {
        guard case let .ready(face) = phase else {
            return nil
        }
        return face
    }

    /// The practice day the queue deals for, or `nil` before the start-up.
    public var practiceDay: PracticeDay? {
        deck?.today
    }

    /// The header (`docs/product/ux-flows.md` §2): the three counts, grouped in the
    /// drill's locale, the card on screen's pile, and what VoiceOver reads for them.
    public var header: DrillHeader {
        DrillHeader(counts: counts, locale: locale)
    }

    /// On the done face, the earliest due day over the cards that have progress and are
    /// in the catalog; `nil` on any other face, or when no card has one.
    public var nextReviewDay: PracticeDay? {
        guard face == .done, let current = deck else {
            return nil
        }
        return current.catalog.cards.compactMap { current.progress[$0.id]?.state.dueDay }.min()
    }

    /// D3's next-review line, such as `次の復習：10月15日（木）`; `nil` when it is left out.
    public var nextReviewText: LocalizedStringResource? {
        guard let day = nextReviewDay, let today = deck?.today else {
            return nil
        }
        return DrillStrings.nextReview(DayWording(locale: locale).text(for: day, today: today))
    }

    /// D3's line counting the never-seen cards outside the scope; `nil` on any other face
    /// and once every card has been seen.
    public var outsideScopeText: LocalizedStringResource? {
        let outside = scope.counts.outsideScope
        guard face == .done, outside > 0 else {
            return nil
        }
        return DrillStrings.outsideScope(formatted(outside))
    }

    private func formatted(_ count: Int) -> String {
        count.formatted(.number.locale(locale))
    }
}
