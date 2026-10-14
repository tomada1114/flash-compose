import FlashComposeCore
import FlashComposeTestSupport
import Testing

@Suite("ScopeSelection storage")
struct ScopeSelectionStorageTests {
    typealias Fixture = ScopeFixture

    @Test
    func `topics are written sorted and levels sorted numerically`() throws {
        let selection = try ScopeSelection(
            topicsOff: [Fixture.work, Fixture.daily, Fixture.tech, Fixture.social],
            levelsOff: Set((2 ... 10).map(Fixture.level)),
        )
        #expect(selection.encodedTopicsOff == "daily,social,tech,work")
        #expect(selection.encodedLevelsOff == "2,3,4,5,6,7,8,9,10")
        #expect(ScopeSelection().encodedTopicsOff.isEmpty)
        #expect(ScopeSelection().encodedLevelsOff.isEmpty)
    }

    @Test
    func `roundTrip`() throws {
        let preferences = InMemoryPreferences()
        let selection = try ScopeSelection(
            topicsOff: [Fixture.travel, TopicID("legacy-topic")],
            levelsOff: [Fixture.level(3), Fixture.level(10)],
        )
        selection.store(in: preferences)
        #expect(preferences.value(for: PreferenceKeys.scopeTopicsOff) == "legacy-topic,travel")
        #expect(preferences.value(for: PreferenceKeys.scopeLevelsOff) == "3,10")
        #expect(ScopeSelection.stored(in: preferences) == selection)
    }

    @Test
    func `nothing stored reads as everything on`() {
        #expect(ScopeSelection.stored(in: InMemoryPreferences()) == ScopeSelection())
    }

    @Test
    func `tokens that do not parse are dropped`() throws {
        let selection = ScopeSelection(
            encodedTopicsOff: "tech,,travel",
            encodedLevelsOff: "x,,3,abc,0,11, 4",
        )
        #expect(selection.topicsOff == [Fixture.tech, Fixture.travel])
        #expect(try selection.levelsOff == [Fixture.level(3)])
    }
}
