import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

/// A catalog loader whose first call fails (E1), whose second call waits until
/// ``release()``, and whose later calls return at once.
private actor StartupGate {
    private let catalog: CardCatalog
    private var hasFailed = false
    private var hasHeld = false
    private var held: CheckedContinuation<Void, Never>?
    private var heldWaiter: CheckedContinuation<Void, Never>?

    init(_ catalog: CardCatalog) {
        self.catalog = catalog
    }

    func load() async throws(CatalogError) -> CardCatalog {
        if !hasFailed {
            hasFailed = true
            throw .decodeFailed
        }
        if !hasHeld {
            hasHeld = true
            await withCheckedContinuation { continuation in
                held = continuation
                heldWaiter?.resume()
                heldWaiter = nil
            }
        }
        return catalog
    }

    func waitUntilHeld() async {
        guard held == nil else {
            return
        }
        await withCheckedContinuation { heldWaiter = $0 }
    }

    func release() {
        held?.resume()
        held = nil
    }
}

/// REQ-001: the start-up decodes the catalog and loads the progress, then shows D1 or
/// D3; either load failing is E1, which a retry leaves.
@MainActor
@Suite("Drill start-up")
struct DrillStartupTests {
    typealias Fixture = DrillFixture

    @Test
    func `building the drill reads nothing`() async throws {
        let drill = try DrillSetup(cards: Fixture.cards(3, from: 0)).build()
        #expect(drill.model.phase == .starting)
        #expect(drill.model.face == nil)
        #expect(drill.model.card == nil)
        #expect(drill.model.practiceDay == nil)
        #expect(await drill.store.calls.isEmpty)
    }

    /// The first launch: no progress, so a new card from the default scope, with 復習 0 and
    /// もう一度 0.
    @Test
    func `a first launch deals a new card from the default scope`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(5, from: 0)).started()
        #expect(drill.model.phase == .ready(.question))
        #expect(drill.model.card?.pile == .new)
        #expect(drill.model.counts == HeaderCounts(new: 5, review: 0, reAsk: 0, currentPile: .new))
        #expect(try drill.model.practiceDay == Fixture.day(Fixture.today))
        #expect(await drill.store.calls == [.loadProgress])
        #expect(drill.scope.counts == NeverSeenCounts(inScope: 5, outsideScope: 0))
        #expect(drill.scope.catalog.topics.map(\.name).first == "日常")
    }

    @Test
    func `the shipped catalog starts with every card new`() async throws {
        var setup = DrillSetup(cards: [])
        setup.catalog = { () async throws(CatalogError) -> CardCatalog in
            try await CatalogLoader.load()
        }
        let drill = try await setup.started()
        #expect(drill.model.counts.new == 1_952)
        #expect(drill.model.counts.review == 0)
        #expect(drill.model.card?.pile == .new)
    }

    @Test
    func `a failing catalog shows E1, and a retry reaches the drill`() async throws {
        let cards = try Fixture.cards(2, from: 0)
        let flaky = FlakyCatalog(Fixture.catalog(cards), failures: 1)
        var setup = DrillSetup(cards: cards)
        setup.catalog = { () throws(CatalogError) -> CardCatalog in try flaky.load() }
        let drill = try await setup.started()
        #expect(drill.model.phase == .failed)
        #expect(drill.model.card == nil)
        #expect(drill.model.failure == nil)
        await drill.model.retry()
        #expect(drill.model.phase == .ready(.question))
    }

    @Test
    func `a failing progress load shows E1, and a retry reaches the drill`() async throws {
        let drill = try DrillSetup(cards: Fixture.cards(2, from: 0)).build()
        await drill.store.fail(.loadProgress, with: .storageFailure)
        await drill.model.start()
        #expect(drill.model.phase == .failed)
        await drill.store.succeed(.loadProgress)
        await drill.model.retry()
        #expect(drill.model.phase == .ready(.question))
        #expect(await drill.store.calls == [.loadProgress, .loadProgress])
    }

    /// The composition root's null object: a store that cannot open is E1, not a crash.
    @Test
    func `an unavailable store shows E1`() async throws {
        let cards = try Fixture.cards(2, from: 0)
        let scope = ScopeViewModel(preferences: InMemoryPreferences())
        let catalog = Fixture.catalog(cards)
        var environment = DrillEnvironment()
        environment.loadCatalog = { catalog }
        let model = DrillViewModel(
            store: UnavailableProgressStore(),
            scope: scope,
            environment: environment,
        )
        await model.start()
        #expect(model.phase == .failed)
        await model.retry()
        #expect(model.phase == .failed)
    }

    @Test
    func `the start-up failure reads as E1's wording`() {
        #expect(DrillStrings.startFailureTitle.english == "Can't open the data")
        #expect(DrillStrings.startFailureMessage
            .english == "Couldn't load the cards or your progress")
        #expect(DrillStrings.retry.english == "Try Again")
    }

    @Test
    func `retry does nothing unless the start-up failed`() async throws {
        let drill = try DrillSetup(cards: Fixture.cards(2, from: 0)).build()
        await drill.model.retry()
        #expect(drill.model.phase == .starting)
        #expect(await drill.store.calls.isEmpty)
    }

    @Test
    func `a second start keeps the session`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(3, from: 0)).started()
        let first = drill.model.card
        await drill.answer(.again)
        await drill.model.start()
        #expect(drill.model.counts.reAsk == 1)
        #expect(drill.model.card != first)
        #expect(await drill.store.calls == [.loadProgress, .record])
    }

    /// The view leaving cancels its `.task`: nothing changes and no failure shows, so the
    /// next appearance starts again.
    @Test
    func `a cancelled start-up changes nothing`() async throws {
        let drill = try DrillSetup(cards: Fixture.cards(2, from: 0)).build()
        let task = Task { await drill.model.start() }
        task.cancel()
        await task.value
        #expect(drill.model.phase == .starting)
        #expect(drill.model.card == nil)
        #expect(drill.model.counts == HeaderCounts(new: 0, review: 0, reAsk: 0, currentPile: nil))
        await drill.model.start()
        #expect(drill.model.phase == .ready(.question))
    }

    @Test
    func `a cancelled retry goes back to E1 without a failure`() async throws {
        let drill = try DrillSetup(cards: Fixture.cards(2, from: 0)).build()
        await drill.store.fail(.loadProgress, with: .storageFailure)
        await drill.model.start()
        let task = Task { await drill.model.retry() }
        task.cancel()
        await task.value
        #expect(drill.model.phase == .failed)
        #expect(drill.model.failure == nil)
    }

    /// Two start-ups in flight, as a `.task` and a retry can be: one result applies, and
    /// the session is dealt once.
    @Test
    func `overlapping start-ups deal one session`() async throws {
        let drill = try DrillSetup(cards: Fixture.cards(2, from: 0)).build()
        async let older: Void = drill.model.start()
        async let newer: Void = drill.model.start()
        _ = await (older, newer)
        #expect(drill.model.phase == .ready(.question))
        #expect(drill.model.counts == HeaderCounts(new: 2, review: 0, reAsk: 0, currentPile: .new))
    }

    /// From E1, a retry in flight and a second start-up that is cancelled: the cancelled
    /// one goes back to E1, not to the blank start-up, so the retry button still works.
    @Test
    func `a cancelled start-up over a retry in flight goes back to E1`() async throws {
        let cards = try Fixture.cards(2, from: 0)
        let gate = StartupGate(DrillFixture.catalog(cards))
        var setup = DrillSetup(cards: cards)
        setup.catalog = { () async throws(CatalogError) -> CardCatalog in
            try await gate.load()
        }
        let drill = try setup.build()
        await drill.model.start()
        #expect(drill.model.phase == .failed)
        let retry = Task { await drill.model.retry() }
        await gate.waitUntilHeld()
        let cancelled = Task { await drill.model.start() }
        cancelled.cancel()
        await cancelled.value
        await gate.release()
        await retry.value
        #expect(drill.model.phase == .failed)
        #expect(drill.model.failure == nil)
        await drill.model.retry()
        #expect(drill.model.phase == .ready(.question))
    }
}
