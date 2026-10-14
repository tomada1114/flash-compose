/// One drill session's queue: which card comes next, the re-asks waiting, and the header
/// counts (`docs/product/requirements.md` §3.2, `docs/architecture.md` › Session).
///
/// A value the drill's view model holds in memory and never stores, so a relaunch starts
/// a fresh session with no waiting re-ask. Everything else it reads arrives as a
/// ``QueueInput`` on each call, and its one random draw — which new card — comes from the
/// generator the caller injects, so the same inputs and seed always deal the same card.
///
/// The order: a re-ask that has fallen due; then the due review least likely remembered
/// (lowest FSRS retrievability, ties by card id), from every topic and level; then a
/// never-seen candidate, uniformly at random. When no first-time card — a due review or a
/// never-seen candidate — is left, waiting re-asks come at once in the order they fell
/// due, never the card just shown while another waits. A card waiting for a re-ask is not
/// dealt as a first-time card, so after 04:00 a card missed the day before comes back as
/// its re-ask first and as the day's review after.
///
/// Each call is linear in the catalog and the candidates: a review is found by one scan
/// rather than a sort.
public struct DrillSession: Sendable, Equatable {
    /// A card waiting to be asked again, and the step from which it may be.
    private struct ReAsk: Sendable, Equatable {
        let card: Card
        let dueStep: Int
    }

    /// A due review and how likely it is still remembered today.
    private struct Review {
        let card: Card
        let recall: Double

        /// Lower retrievability first; on a tie, the lower card id.
        func comesBefore(_ other: Self) -> Bool {
            recall == other.recall
                ? card.id.rawValue < other.card.id.rawValue
                : recall < other.recall
        }
    }

    private let tuning: Tuning
    /// The card dealt and not yet graded: ``deal(for:using:)`` keeps returning it until
    /// ``record(_:)`` lets it go.
    public private(set) var current: DealtCard?
    /// The card shown last, graded or not, for the "never the card just shown" rule.
    private var lastShown: CardID?
    /// How many cards this session has dealt; a re-ask's due step counts in it.
    private var step = 0
    /// Waiting re-asks in the order they were set, which breaks a tie in due step; at most
    /// one per card, since a card is never dealt while it waits.
    private var waiting: [ReAsk] = []
    /// How many times each card has been dealt as a re-ask this session.
    private var reAsksShown: [CardID: Int] = [:]
    /// Cards dealt new this session that have not yet had a ○.
    private var awaitingFirstGood: Set<CardID> = []

    /// A fresh session: nothing on screen and no re-ask waiting.
    public init(tuning: Tuning = .default) {
        self.tuning = tuning
    }

    /// The card to show: the one on screen while it waits for its grade, otherwise the
    /// next one dealt from `input`, or `nil` when nothing is left today (§3.5).
    ///
    /// Returning the card on screen until it is graded keeps it, and its pile, through a
    /// scope change or 04:00 passing (`docs/product/ux-flows.md` F3, F7). The generator is
    /// drawn from only when a new card is dealt.
    public mutating func deal(
        for input: QueueInput,
        using generator: inout some RandomNumberGenerator,
    ) -> DealtCard? {
        if let current {
            return current
        }
        let nextStep = step + 1
        let dealt: DealtCard
        if let index = earliestReAsk(dueBy: nextStep) {
            dealt = takeReAsk(at: index)
        } else if let firstTime = firstTimeCard(from: input, using: &generator) {
            dealt = firstTime
        } else if let index = earliestReAsk(dueBy: nil) {
            dealt = takeReAsk(at: index)
        } else {
            return nil
        }
        if dealt.pile == .new {
            awaitingFirstGood.insert(dealt.card.id)
        }
        step = nextStep
        current = dealt
        lastShown = dealt.card.id
        return dealt
    }

    /// Records the grade the card on screen was given, and sets its re-ask when the grade
    /// calls for one: × and △ always, ○ only as the first ○ of a card dealt new this
    /// session — until the card has had ``ReAskTuning/maximumPerCard`` re-asks.
    ///
    /// The schedule is not the queue's: the caller moves the card's progress on its first
    /// answer of the day and hands the new progress in with the next ``QueueInput``. With
    /// no card on screen this changes nothing.
    public mutating func record(_ grade: Grade) {
        guard let graded = current else {
            return
        }
        current = nil
        let id = graded.card.id
        let gap: Int? = switch grade {
        case .again:
            tuning.reAsk.afterAgain

        case .good:
            awaitingFirstGood.remove(id).map { _ in tuning.reAsk.afterNewCardsFirstGood }

        case .hard:
            tuning.reAsk.afterHard
        }
        guard let gap, reAsksShown[id, default: 0] < tuning.reAsk.maximumPerCard else {
            return
        }
        waiting.append(ReAsk(card: graded.card, dueStep: step + gap + 1))
    }

    /// The header's counts over `input`, with the card on screen in its pile.
    public func counts(for input: QueueInput) -> HeaderCounts {
        let onScreenReAsk = current?.pile == .reAsk ? 1 : 0
        return HeaderCounts(
            new: input.candidates.count(where: input.isNeverSeen),
            review: input.catalog.cards.count { input.dueProgress(of: $0) != nil },
            reAsk: waiting.count + onScreenReAsk,
            currentPile: current?.pile,
        )
    }

    /// The index of the waiting re-ask that fell due first — by `limit` when one is given —
    /// skipping the card just shown while another waits.
    private func earliestReAsk(dueBy limit: Int?) -> Int? {
        var earliest: Int?
        for index in waiting.indices {
            let reAsk = waiting[index]
            let isDue = limit.map { reAsk.dueStep <= $0 } ?? true
            let isJustShown = reAsk.card.id == lastShown && waiting.count > 1
            guard isDue, !isJustShown else {
                continue
            }
            if let best = earliest, waiting[best].dueStep <= reAsk.dueStep {
                continue
            }
            earliest = index
        }
        return earliest
    }

    private mutating func takeReAsk(at index: Int) -> DealtCard {
        let card = waiting.remove(at: index).card
        reAsksShown[card.id, default: 0] += 1
        return DealtCard(card: card, pile: .reAsk)
    }

    /// The due review least likely remembered, else a never-seen candidate at random;
    /// neither while the card waits for a re-ask.
    private func firstTimeCard(
        from input: QueueInput,
        using generator: inout some RandomNumberGenerator,
    ) -> DealtCard? {
        let waitingIDs = Set(waiting.map(\.card.id))
        if let review = leastRemembered(in: input, excluding: waitingIDs) {
            return DealtCard(card: review, pile: .review)
        }
        let fresh = input.candidates.filter { input.isNeverSeen($0) && !waitingIDs.contains($0.id) }
        guard !fresh.isEmpty else {
            return nil
        }
        let index = Int.random(in: fresh.indices, using: &generator)
        return DealtCard(card: fresh[index], pile: .new)
    }

    /// The due review with the lowest retrievability on `input.today`, ties broken by
    /// card id so the choice never depends on the catalog's order.
    private func leastRemembered(in input: QueueInput, excluding waitingIDs: Set<CardID>) -> Card? {
        let scheduler = FSRSScheduler(tuning: tuning.fsrs)
        var best: Review?
        for card in input.catalog.cards where !waitingIDs.contains(card.id) {
            guard let due = input.dueProgress(of: card) else {
                continue
            }
            let review = Review(
                card: card,
                recall: scheduler.retrievability(of: due.state, on: input.today),
            )
            if let leader = best, !review.comesBefore(leader) {
                continue
            }
            best = review
        }
        return best?.card
    }
}
