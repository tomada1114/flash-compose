import FlashComposeCore
import Testing

@Suite("ScopeSelection")
struct ScopeSelectionTests {
    typealias Fixture = ScopeFixture

    @Test
    func `an empty selection includes every card`() throws {
        let catalog = try Fixture.smallCatalog()
        #expect(catalog.cards.allSatisfy(ScopeSelection().includes))
    }

    @Test
    func `a card is in scope only when its topic and its level are on`() throws {
        let selection = try ScopeSelection(topicsOff: [Fixture.work], levelsOff: [Fixture.level(7)])
        #expect(try !selection.includes(Fixture.card(
            0,
            topic: Fixture.work,
            level: Fixture.level(5),
        )))
        #expect(try selection.includes(Fixture.card(
            1,
            topic: Fixture.travel,
            level: Fixture.level(5),
        )))
        #expect(try !selection.includes(Fixture.card(
            2,
            topic: Fixture.travel,
            level: Fixture.level(7),
        )))
    }

    @Test
    func `toggling turns a row off and back on`() throws {
        var selection = ScopeSelection()
        let ids = Fixture.topics.map(\.id)
        let changed1 = selection.toggle(Fixture.work, among: ids)
        #expect(changed1)
        #expect(!selection.isOn(Fixture.work))
        let changed2 = selection.toggle(Fixture.work, among: ids)
        #expect(changed2)
        #expect(selection == ScopeSelection())
        let seven = try Fixture.level(7)
        let changed3 = selection.toggle(seven, among: Level.allCases)
        #expect(changed3)
        #expect(!selection.isOn(seven))
        let changed4 = selection.toggle(seven, among: Level.allCases)
        #expect(changed4)
        #expect(selection == ScopeSelection())
    }

    @Test
    func `the last topic on stays on`() {
        var selection = ScopeSelection(topicsOff: [
            Fixture.daily,
            Fixture.social,
            Fixture.tech,
            Fixture.travel,
        ])
        let before = selection
        #expect(!selection.canToggle(Fixture.work, among: Fixture.topics.map(\.id)))
        let changed5 = selection.toggle(Fixture.work, among: Fixture.topics.map(\.id))
        #expect(!changed5)
        #expect(selection == before)
        #expect(selection.canToggle(Fixture.daily, among: Fixture.topics.map(\.id)))
    }

    @Test
    func `the last level on stays on`() throws {
        let seven = try Fixture.level(7)
        var selection = ScopeSelection(levelsOff: Set(Level.allCases.filter { $0 != seven }))
        let before = selection
        let changed6 = selection.toggle(seven, among: Level.allCases)
        #expect(!changed6)
        #expect(selection == before)
    }

    @Test
    func `an unknown off id does not count toward at least one staying on`() {
        let legacy = TopicID("legacy-topic")
        let ids = Fixture.topics.map(\.id)
        var selection = ScopeSelection(topicsOff: [
            legacy,
            Fixture.daily,
            Fixture.social,
            Fixture.tech,
        ])
        #expect(selection.canToggle(Fixture.work, among: ids))
        let changed7 = selection.toggle(Fixture.work, among: ids)
        #expect(changed7)
        #expect(!selection.canToggle(Fixture.travel, among: ids))
        let withoutLegacy = ScopeSelection(topicsOff: [Fixture.daily, Fixture.social, Fixture.tech])
        #expect(withoutLegacy.canToggle(Fixture.work, among: ids))
    }

    @Test
    func `a selection turning every catalog topic or level off is repaired to all on`() throws {
        let ids = Fixture.topics.map(\.id)
        let corrupt = ScopeSelection(topicsOff: Set(ids), levelsOff: Set(Level.allCases))
        #expect(corrupt.repaired(topics: ids, levels: Level.allCases) == ScopeSelection())
        let fine = try ScopeSelection(
            topicsOff: [Fixture.tech, TopicID("legacy")],
            levelsOff: [Fixture.level(3)],
        )
        #expect(fine.repaired(topics: ids, levels: Level.allCases) == fine)
        #expect(corrupt.repaired(topics: [], levels: []) == corrupt)
    }
}
