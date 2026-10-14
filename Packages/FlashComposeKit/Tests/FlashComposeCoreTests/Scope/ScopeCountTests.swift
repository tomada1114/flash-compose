import FlashComposeCore
import Testing

@Suite("Never-seen counts")
struct ScopeCountTests {
    typealias Fixture = ScopeFixture

    static func travelLevelOne() throws -> ScopeSelection {
        try ScopeSelection(
            topicsOff: [Fixture.daily, Fixture.social, Fixture.work, Fixture.tech],
            levelsOff: Set((2 ... 10).map(Fixture.level)),
        )
    }

    @Test
    func `narrowed to travel L1 before any grade`() throws {
        let counts = try Fixture.fullCatalog().neverSeenCounts(
            in: Self.travelLevelOne(),
            seenCardIDs: [],
        )
        #expect(counts == NeverSeenCounts(inScope: 33, outsideScope: 1_919))
    }

    @Test
    func `outsideScope`() throws {
        let catalog = try Fixture.fullCatalog()
        let seen = Set(catalog.cards.filter { $0.topic != Fixture.travel }.map(\.id))
        let selection = ScopeSelection(topicsOff: [Fixture.travel])
        let travelCount = catalog.cards.count { $0.topic == Fixture.travel }
        let counts = catalog.neverSeenCounts(in: selection, seenCardIDs: seen)
        #expect(counts == NeverSeenCounts(inScope: 0, outsideScope: travelCount))
    }

    @Test
    func `zeroWhenAllSeen`() throws {
        let catalog = try Fixture.fullCatalog()
        let counts = catalog.neverSeenCounts(
            in: ScopeSelection(),
            seenCardIDs: Set(catalog.cards.map(\.id)),
        )
        #expect(counts == NeverSeenCounts(inScope: 0, outsideScope: 0))
    }

    @Test
    func `progress for a retired id counts nowhere and an unknown off id changes nothing`() throws {
        let catalog = try Fixture.smallCatalog()
        let retired = try Fixture.cardID(9_999)
        let plain = catalog.neverSeenCounts(
            in: ScopeSelection(topicsOff: [Fixture.tech]),
            seenCardIDs: [],
        )
        let withNoise = catalog.neverSeenCounts(
            in: ScopeSelection(topicsOff: [Fixture.tech, TopicID("legacy-topic")]),
            seenCardIDs: [retired],
        )
        #expect(plain == withNoise)
        #expect(plain.inScope + plain.outsideScope == catalog.cards.count)
    }

    @Test
    func `the catalog lists its ids in screen order`() throws {
        let catalog = try Fixture.smallCatalog()
        #expect(catalog.topicIDs == [
            Fixture.daily,
            Fixture.social,
            Fixture.work,
            Fixture.travel,
            Fixture.tech,
        ])
        #expect(catalog.levelValues == Level.allCases)
        #expect(ScopeCatalog.empty.cards.isEmpty)
    }
}
