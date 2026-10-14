import FlashComposeCore
import Testing

@Suite("CardCatalog")
struct CardCatalogTests {
    typealias Fixture = CatalogFixture

    @Test
    func `cards run in taxonomy order, then file order`() async throws {
        let catalog = try await Fixture.bundled.value

        // The first card of the first file the taxonomy names (cards/daily/home.json),
        // and the last card of its last (cards/tech/product-talk.json).
        #expect(try catalog.cards.first?.id == CardID("c_2b2t3t4g"))
        #expect(try catalog.cards.last?.id == CardID("c_9x9g4h4c"))
        #expect(catalog.cards.first?.subtopic == SubtopicID("home"))
        #expect(catalog.cards.last?.subtopic == SubtopicID("product-talk"))
    }

    @Test
    func `a card is found by its id, and an id the catalog lacks finds nothing`() async throws {
        let catalog = try await Fixture.bundled.value
        let found = try catalog.card(id: CardID("c_2b2t3t4g"))

        #expect(found?.english == "I may have left it unlocked.")
        #expect(try catalog.card(id: CardID("c_2a2a2a2a")) == nil)
    }

    @Test
    func `a retired id finds no card`() async throws {
        let catalog = try await Fixture.bundled.value
        #expect(try catalog.card(id: CardID("c_4h2v2r6v")) == nil)
    }

    @Test
    func `topics keep the taxonomy's order, Japanese names, and subtopics`() async throws {
        let catalog = try await Fixture.bundled.value
        let home = SubtopicDefinition(id: SubtopicID("home"), name: "家・家事")

        #expect(catalog.topics.map(\.id.rawValue) == ["daily", "social", "work", "travel", "tech"])
        #expect(catalog.topics.map(\.name) == ["日常", "雑談・人付き合い", "仕事", "旅行", "IT・技術"])
        #expect(catalog.topics.map(\.subtopics.count) == [8, 6, 10, 6, 7])
        #expect(catalog.topics.first?.subtopics.first == home)
    }

    @Test
    func `levels carry their TOEIC and CEFR hints and summary`() async throws {
        let catalog = try await Fixture.bundled.value
        let toeic = ["300", "400", "500", "600", "730", "800", "860", "900", "950", "990+"]
        let cefr = ["A1+", "A2", "A2+", "B1-", "B1+", "B2-", "B2", "B2+", "C1-", "C1"]

        #expect(catalog.levels.map(\.level) == Level.allCases)
        #expect(catalog.levels.map(\.toeic) == toeic)
        #expect(catalog.levels.map(\.cefr) == cefr)
        #expect(catalog.levels.first?.summary == "中 1 相当。be 動詞・現在形・命令文。語彙は身の回りの基本語")
    }

    @Test
    func `grammar tags carry their Japanese names in file order`() async throws {
        let catalog = try await Fixture.bundled.value
        let firstID = GrammarTagID("be-and-present-simple")
        let first = GrammarTagDefinition(id: firstID, name: "be 動詞・現在形")
        let last = GrammarTagDefinition(id: GrammarTagID("inversion"), name: "倒置")

        #expect(catalog.grammarTags.first == first)
        #expect(catalog.grammarTags.last == last)
    }

    @Test
    func `retired ids keep their replacement when they have one`() async throws {
        let catalog = try await Fixture.bundled.value
        let replaced = try RetiredCardID(id: CardID("c_4h2v2r6v"), replacedBy: CardID("c_9j5e2g3p"))
        let deleted = try RetiredCardID(id: CardID("c_2g8s4t5k"), replacedBy: nil)

        #expect(catalog.retiredIDs.first == replaced)
        #expect(catalog.retiredIDs.contains(deleted))
    }

    @Test
    func `a duplicated id keeps both cards and finds the first`() async throws {
        let catalog = try await Fixture.bundled.value
        let first = try #require(catalog.cards.first)
        var edited = Fixture.EditableCard(first)
        edited.english = "(the second card with this id)"
        let twin = edited.card

        let duplicated = Fixture.catalog(catalog, cards: [first, twin])

        #expect(duplicated.cards == [first, twin])
        #expect(duplicated.card(id: first.id) == first)
    }

    @Test
    func `an empty catalog finds nothing`() throws {
        let empty = CardCatalog(cards: [], topics: [], levels: [], grammarTags: [], retiredIDs: [])

        #expect(empty.cards.isEmpty)
        #expect(try empty.card(id: CardID("c_2b2t3t4g")) == nil)
    }
}
