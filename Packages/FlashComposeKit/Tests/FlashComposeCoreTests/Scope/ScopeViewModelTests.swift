import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

@MainActor
@Suite("ScopeViewModel")
struct ScopeViewModelTests {
    typealias Fixture = ScopeFixture

    private static func loaded(
        _ catalog: ScopeCatalog,
        preferences: some PreferencesStoring = InMemoryPreferences(),
        seen: Set<CardID> = [],
    ) -> ScopeViewModel {
        let model = ScopeViewModel(preferences: preferences, locale: Fixture.english)
        model.load(catalog: catalog, seenCardIDs: seen)
        return model
    }

    @Test
    func `rows list the topics in order and the levels with their TOEIC labels`() throws {
        let model = try Self.loaded(Fixture.smallCatalog())
        #expect(model.topicRows.map(\.title) == ["日常", "雑談・人付き合い", "仕事", "旅行", "IT・技術"])
        #expect(model.topicRows.allSatisfy { $0.isOn && !$0.isDisabled && $0.detail == nil })
        #expect(model.levelRows.map(\.title) == (1 ... 10).map { "L\($0)" })
        #expect(model.levelRows.first?.detail == "TOEIC 300")
        #expect(model.levelRows.last?.detail == "TOEIC 990+")
        #expect(model.topicsNote == nil)
        #expect(model.levelsNote == nil)
    }

    @Test
    func `narrowToTravelLevelOne`() throws {
        let preferences = InMemoryPreferences()
        let model = try Self.loaded(Fixture.fullCatalog(), preferences: preferences)
        #expect(model.countText.english == "Unseen in this scope: 1,952")
        for topic in [Fixture.daily, Fixture.social, Fixture.work, Fixture.tech] {
            model.toggle(topic)
        }
        for number in 2 ... 10 {
            try model.toggle(Fixture.level(number))
        }
        #expect(preferences.value(for: PreferenceKeys.scopeTopicsOff) == "daily,social,tech,work")
        #expect(preferences.value(for: PreferenceKeys.scopeLevelsOff) == "2,3,4,5,6,7,8,9,10")
        #expect(model.counts == NeverSeenCounts(inScope: 33, outsideScope: 1_919))
        #expect(model.countText.english == "Unseen in this scope: 33")
        #expect(model.countText.key == "scope.unseenCount")
        #expect(model.topicsNote?.key == "scope.pickAtLeastOne")
        #expect(model.levelsNote?.key == "scope.pickAtLeastOne")
    }

    @Test
    func `disabledLastRow`() throws {
        let preferences = CountingPreferences()
        preferences.set("daily,social,tech,travel", for: PreferenceKeys.scopeTopicsOff)
        let model = try Self.loaded(Fixture.smallCatalog(), preferences: preferences)
        let writes = preferences.writes
        let work = try #require(model.topicRows.first { $0.id == Fixture.work })
        #expect(work.isOn && work.isDisabled)
        #expect(model.topicRows.filter(\.isDisabled).count == 1)
        model.toggle(Fixture.work)
        #expect(preferences.writes == writes)
        #expect(model.selection.isOn(Fixture.work))
        #expect(model.topicsNote?.english == "Pick at least one")
    }

    @Test
    func `the last level on is disabled and refuses a tap`() throws {
        let preferences = CountingPreferences()
        preferences.set("1,2,3,4,5,6,8,9,10", for: PreferenceKeys.scopeLevelsOff)
        let model = try Self.loaded(Fixture.smallCatalog(), preferences: preferences)
        let writes = preferences.writes
        let seven = try Fixture.level(7)
        #expect(model.levelRows.first { $0.id == seven }?.isDisabled == true)
        model.toggle(seven)
        #expect(preferences.writes == writes)
        #expect(model.levelsNote != nil)
    }

    @Test
    func `unknownIdIgnored`() throws {
        let preferences = InMemoryPreferences()
        preferences.set("legacy-topic,travel", for: PreferenceKeys.scopeTopicsOff)
        let catalog = try Fixture.smallCatalog()
        let model = Self.loaded(catalog, preferences: preferences)
        #expect(model.topicRows.count(where: \.isOn) == 4)
        #expect(model.topicsNote == nil)
        #expect(model.topicRows.allSatisfy { !$0.isDisabled })
        let travelOnly = catalog.neverSeenCounts(
            in: ScopeSelection(topicsOff: [Fixture.travel]),
            seenCardIDs: [],
        )
        #expect(model.counts == travelOnly)
    }

    @Test
    func `a stored selection turning every topic off reads as all on`() throws {
        let preferences = InMemoryPreferences()
        preferences.set("daily,social,tech,travel,work", for: PreferenceKeys.scopeTopicsOff)
        let model = try Self.loaded(Fixture.smallCatalog(), preferences: preferences)
        let allOn = model.topicRows.allSatisfy(\.isOn)
        #expect(allOn)
    }

    @Test
    func `a toggle saves at once and recounts`() throws {
        let preferences = InMemoryPreferences()
        let model = try Self.loaded(Fixture.smallCatalog(), preferences: preferences)
        let before = model.counts.inScope
        model.toggle(Fixture.travel)
        #expect(preferences.value(for: PreferenceKeys.scopeTopicsOff) == "travel")
        #expect(model.counts.inScope == before - 10)
        model.toggle(Fixture.travel)
        #expect(preferences.value(for: PreferenceKeys.scopeTopicsOff).isEmpty)
        #expect(model.counts.inScope == before)
        let reread = ScopeViewModel(preferences: preferences)
        try reread.load(catalog: Fixture.smallCatalog(), seenCardIDs: [])
        #expect(reread.selection == model.selection)
    }

    @Test
    func `the zero text replaces the count when every in-scope card is seen`() throws {
        let catalog = try Fixture.smallCatalog()
        let model = Self.loaded(catalog, seen: Set(catalog.cards.map(\.id)))
        #expect(model.counts.inScope == 0)
        #expect(model.countText.key == "scope.allShown")
        #expect(model.countText.english == "Every card in this scope shown")
    }

    @Test
    func `before load the model holds everything on and no rows`() {
        let model = ScopeViewModel(preferences: InMemoryPreferences())
        #expect(model.selection == ScopeSelection())
        #expect(model.topicRows.isEmpty)
        #expect(model.levelRows.isEmpty)
        #expect(model.countText.key == "scope.allShown")
    }
}
