import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

/// ``AppModel``: the shared view models it builds over the ports `App/` hands it, and the
/// view model it builds for a pushed route.
@MainActor
@Suite("AppModel")
struct AppModelTests {
    typealias Fixture = TodoListViewModelFixture

    /// An app model over `repository`, `preferences`, and `progressStore` whose clock and
    /// identifier source are pinned to the fixture's, and whose drill reads `cards` as its
    /// catalog.
    private static func appModel(
        over repository: some TodoRepository,
        preferences: some PreferencesStoring,
        progressStore: some ProgressStore = InMemoryProgressStore(),
        cards: [Card] = [],
    ) -> AppModel {
        let pinnedNow = Fixture.now
        let pinnedID = Fixture.fixedID
        let catalog = DrillFixture.catalog(cards)
        var environment = DrillEnvironment(locale: Locale(identifier: "en_US"))
        environment.loadCatalog = { catalog }
        return AppModel(
            repository: repository,
            preferences: preferences,
            progressStore: progressStore,
            now: { pinnedNow },
            makeID: { pinnedID },
            drillEnvironment: environment,
        )
    }

    // MARK: - The shared list

    @Test
    func `building the app model reads nothing from either port`() async {
        let repository = InMemoryTodoRepository()
        let preferences = InMemoryPreferences()
        let model = Self.appModel(over: repository, preferences: preferences)
        #expect(model.todoList.phase == .idle)
        #expect(await repository.calls.isEmpty)
    }

    @Test
    func `the list loads from the repository and the preferences it was handed`() async throws {
        let milk = try Fixture.item("Milk", minute: 1)
        let preferences = InMemoryPreferences()
        preferences.set(true, for: PreferenceKeys.hideCompleted)
        let model = Self.appModel(
            over: InMemoryTodoRepository(items: [milk]),
            preferences: preferences,
        )
        await model.todoList.load()
        #expect(model.todoList.items == [milk])
        #expect(model.todoList.hideCompleted)
    }

    @Test
    func `the list stamps a new item with the injected clock and identifier`() async throws {
        let repository = InMemoryTodoRepository()
        let model = Self.appModel(over: repository, preferences: InMemoryPreferences())
        model.todoList.draftTitle = "Milk"
        await model.todoList.addDraft()
        let expected = try TodoItem(id: Fixture.fixedID, title: "Milk", createdAt: Fixture.now)
        #expect(model.todoList.items == [expected])
        #expect(await repository.snapshot == [expected])
    }

    // MARK: - The shared scope

    @Test
    func `building the app model reads no preference`() {
        let preferences = CountingPreferences()
        let model = Self.appModel(over: InMemoryTodoRepository(), preferences: preferences)
        #expect(preferences.reads == 0)
        #expect(preferences.writes == 0)
        #expect(model.scope.selection == ScopeSelection())
    }

    @Test
    func `the scope reads and writes the preferences it was built over`() throws {
        let preferences = InMemoryPreferences()
        preferences.set("tech", for: PreferenceKeys.scopeTopicsOff)
        let model = Self.appModel(over: InMemoryTodoRepository(), preferences: preferences)
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
            over: InMemoryTodoRepository(),
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
            over: InMemoryTodoRepository(),
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
        #expect(await store.answers.map(\.gradedAt) == [Fixture.now])
        #expect(model.scope.counts == NeverSeenCounts(inScope: 2, outsideScope: 0))
    }

    @Test
    func `a scope toggle on the app model steers the drill's new cards`() async throws {
        let preferences = InMemoryPreferences()
        let daily = try DrillFixture.cards(2, from: 0)
        let work = try QueueFixture.card(10, topic: ScopeFixture.work, level: 1)
        let model = Self.appModel(
            over: InMemoryTodoRepository(),
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
            over: InMemoryTodoRepository(),
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
            over: InMemoryTodoRepository(),
            preferences: InMemoryPreferences(),
            progressStore: UnavailableProgressStore(),
        )
        await model.drill.start()
        #expect(model.drill.phase == .failed)
    }

    // MARK: - A route's view model

    @Test
    func `a detail model shows the item the list loaded`() async throws {
        let milk = try Fixture.item("Milk", minute: 1)
        let bread = try Fixture.item("Bread", minute: 2)
        let model = Self.appModel(
            over: InMemoryTodoRepository(items: [milk, bread]),
            preferences: InMemoryPreferences(),
        )
        await model.todoList.load()
        #expect(model.makeTodoDetailViewModel(id: bread.id).content == .item(bread))
    }

    @Test
    func `a detail model loads the shared list, not a copy of its own`() async throws {
        let milk = try Fixture.item("Milk", minute: 1)
        let model = Self.appModel(
            over: InMemoryTodoRepository(items: [milk]),
            preferences: InMemoryPreferences(),
        )
        let detail = model.makeTodoDetailViewModel(id: milk.id)
        await detail.load()
        #expect(model.todoList.phase == .loaded)
        #expect(model.todoList.items == [milk])
    }

    @Test
    func `a toggle on a detail model is the list's toggle`() async throws {
        let milk = try Fixture.item("Milk", minute: 1)
        let model = Self.appModel(
            over: InMemoryTodoRepository(items: [milk]),
            preferences: InMemoryPreferences(),
        )
        await model.todoList.load()
        await model.makeTodoDetailViewModel(id: milk.id).toggle()
        #expect(model.todoList.item(withID: milk.id)?.isDone == true)
    }

    /// Two windows can push the same item: each gets a model of its own, and both show
    /// the one state the list holds.
    @Test
    func `each call builds a new detail model over the same state`() async throws {
        let milk = try Fixture.item("Milk", minute: 1)
        let model = Self.appModel(
            over: InMemoryTodoRepository(items: [milk]),
            preferences: InMemoryPreferences(),
        )
        await model.todoList.load()
        let first = model.makeTodoDetailViewModel(id: milk.id)
        let second = model.makeTodoDetailViewModel(id: milk.id)
        #expect(first !== second)
        await first.toggle()
        var done = milk
        done.isDone = true
        #expect(second.content == .item(done))
    }
}
