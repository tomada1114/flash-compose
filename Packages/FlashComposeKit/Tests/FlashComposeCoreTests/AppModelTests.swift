import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

/// ``AppModel``: the shared view models it builds over the ports `App/` hands it.
@MainActor
@Suite("AppModel")
struct AppModelTests {
    /// What the injected clock answers.
    static let now = Date(timeIntervalSinceReferenceDate: 3_600)

    /// An app model over `preferences` and `progressStore` whose clock is pinned to
    /// ``now``, and whose drill reads `cards` as its catalog.
    private static func appModel(
        preferences: some PreferencesStoring,
        progressStore: some ProgressStore = InMemoryProgressStore(),
        cards: [Card] = [],
    ) -> AppModel {
        let pinnedNow = now
        let catalog = DrillFixture.catalog(cards)
        var environment = DrillEnvironment(locale: Locale(identifier: "en_US"))
        environment.loadCatalog = { catalog }
        return AppModel(
            preferences: preferences,
            progressStore: progressStore,
            now: { pinnedNow },
            drillEnvironment: environment,
        )
    }

    // MARK: - The shared scope

    @Test
    func `building the app model reads no preference`() {
        let preferences = CountingPreferences()
        let model = Self.appModel(preferences: preferences)
        #expect(preferences.reads == 0)
        #expect(preferences.writes == 0)
        #expect(model.scope.selection == ScopeSelection())
    }

    @Test
    func `the scope reads and writes the preferences it was built over`() throws {
        let preferences = InMemoryPreferences()
        preferences.set("tech", for: PreferenceKeys.scopeTopicsOff)
        let model = Self.appModel(preferences: preferences)
        try model.scope.load(catalog: ScopeFixture.smallCatalog(), seenCardIDs: [])
        #expect(model.scope.selection == ScopeSelection(topicsOff: [ScopeFixture.tech]))
        model.scope.toggle(ScopeFixture.work)
        #expect(preferences.value(for: PreferenceKeys.scopeTopicsOff) == "tech,work")
    }

    // MARK: - The shared drill

    @Test
    func `building the app model reads nothing from the progress store`() async {
        let store = InMemoryProgressStore()
        let model = Self.appModel(
            preferences: InMemoryPreferences(),
            progressStore: store,
        )
        #expect(model.drill.phase == .starting)
        #expect(await store.calls.isEmpty)
    }

    @Test
    func `the drill starts over the progress store and the scope the app model holds`(
    ) async throws {
        let store = InMemoryProgressStore()
        let preferences = InMemoryPreferences()
        let cards = try DrillFixture.cards(3, from: 0)
        let model = Self.appModel(
            preferences: preferences,
            progressStore: store,
            cards: cards,
        )
        await model.drill.start()
        #expect(model.drill.phase == .ready(.question))
        #expect(await store.calls == [.loadProgress])
        #expect(model.scope.counts == NeverSeenCounts(inScope: 3, outsideScope: 0))
        model.drill.reveal()
        await model.drill.grade(.good)
        #expect(await store.answers.map(\.gradedAt) == [Self.now])
        #expect(model.scope.counts == NeverSeenCounts(inScope: 2, outsideScope: 0))
    }

    @Test
    func `a scope toggle on the app model steers the drill's new cards`() async throws {
        let preferences = InMemoryPreferences()
        let daily = try DrillFixture.cards(2, from: 0)
        let work = try QueueFixture.card(10, topic: ScopeFixture.work, level: 1)
        let model = Self.appModel(
            preferences: preferences,
            cards: daily + [work],
        )
        await model.drill.start()
        model.scope.toggle(ScopeFixture.daily)
        model.drill.scopeDidChange()
        #expect(model.drill.counts.new == 1)
        #expect(preferences.value(for: PreferenceKeys.scopeTopicsOff) == "daily")
    }

    @Test
    func `the start-up indicator watches the shared drill and starts hidden`() async {
        let model = Self.appModel(
            preferences: InMemoryPreferences(),
        )
        #expect(!model.startupIndicator.isVisible)
        await model.drill.start()
        #expect(!model.startupIndicator.isVisible)
    }

    /// The composition root's fallback: a store that cannot open shows E1.
    @Test
    func `an unavailable progress store leaves the drill on E1`() async {
        let model = Self.appModel(
            preferences: InMemoryPreferences(),
            progressStore: UnavailableProgressStore(),
        )
        await model.drill.start()
        #expect(model.drill.phase == .failed)
    }
}
