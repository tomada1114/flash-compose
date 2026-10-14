import FlashComposeCore
import Foundation
import Testing

@Suite("CatalogLoader")
struct CatalogLoaderTests {
    typealias CardJSON = MiniCatalog.CardJSON

    /// Writes all of `catalog` to a fresh directory and loads it.
    static func load(_ catalog: MiniCatalog) async throws -> CardCatalog {
        try await load(catalog, omitting: [])
    }

    /// Writes `catalog`, minus the paths in `omitted`, to a fresh directory and loads it.
    static func load(
        _ catalog: MiniCatalog,
        omitting omitted: Set<String>,
    ) async throws -> CardCatalog {
        let directory = try CatalogFixture.makeDirectory()
        defer { CatalogFixture.remove(directory) }
        try catalog.write(to: directory, omitting: omitted)
        return try await CatalogLoader.load(from: directory)
    }

    /// Expects loading `catalog` to fail as a decode failure.
    static func expectDecodeFailure(_ catalog: MiniCatalog) async {
        await #expect(throws: CatalogError.decodeFailed) {
            try await load(catalog)
        }
    }

    @Test
    func `the bundled catalog decodes Example 1's card field by field`() async throws {
        let catalog = try await CatalogLoader.load()
        let card = try #require(try catalog.card(id: CardID(CatalogFixture.fishingCardID)))
        let alternatives = [
            "I'll go fishing if it's sunny.",
            "If the weather's nice, I'll go fishing.",
        ]

        #expect(card.japanese == "晴れたら、釣りに行くよ。")
        #expect(card.english == "If it's sunny, I'll go fishing.")
        #expect(card.alternatives == alternatives)
        #expect(card.point == "未来のことでも if 節は現在形")
        #expect(card.topic == TopicID("daily"))
        #expect(card.subtopic == SubtopicID("hobbies"))
        #expect(try card.level == Level(5))
        #expect(card.grammar == [GrammarTagID("time-and-if-clauses")])
    }

    @MainActor
    @Test
    func `loading from the main actor returns the whole catalog`() async throws {
        let catalog = try await CatalogLoader.load()
        #expect(catalog.cards.count == 1_952)
    }

    @Test
    func `a complete directory decodes every file in taxonomy order`() async throws {
        let catalog = try await Self.load(MiniCatalog())
        let cardIDs = try ["c_2a3b4c5d", "c_6e7f8g9h", "c_2j3k4m5n"].map(CardID.init)
        let subtopics = [
            SubtopicDefinition(id: SubtopicID("meetings"), name: "会議"),
            SubtopicDefinition(id: SubtopicID("email-chat"), name: "メール・チャット"),
        ]
        let levels = try [
            LevelDefinition(level: Level(1), toeic: "300", cefr: "A1+", summary: "(one)"),
            LevelDefinition(level: Level(2), toeic: "400", cefr: "A2", summary: "(two)"),
        ]
        let retiredIDs = try [
            RetiredCardID(id: CardID("c_9w4n4b3u"), replacedBy: CardID("c_2a3b4c5d")),
            RetiredCardID(id: CardID("c_2g8s4t5k"), replacedBy: nil),
        ]

        #expect(catalog.cards.map(\.id) == cardIDs)
        let english = ["Let's start.", "Any questions?", "Thanks for the email."]
        let topic = TopicDefinition(id: TopicID("work"), name: "仕事", subtopics: subtopics)
        let tag = GrammarTagDefinition(id: GrammarTagID("modals"), name: "助動詞")

        #expect(catalog.cards.map(\.english) == english)
        #expect(catalog.topics == [topic])
        #expect(catalog.levels == levels)
        #expect(catalog.grammarTags == [tag])
        #expect(catalog.retiredIDs == retiredIDs)
    }

    @Test(arguments: [
        "taxonomy.json",
        "levels.json",
        "grammar.json",
        "retired-ids.json",
        "cards/work/meetings.json",
        "cards/work/email-chat.json",
    ])
    func `a missing file fails the whole load as a read failure`(path: String) async {
        await #expect(throws: CatalogError.readFailed) {
            try await Self.load(MiniCatalog(), omitting: [path])
        }
    }

    @Test
    func `a missing directory fails as a read failure`() async throws {
        let directory = try CatalogFixture.makeDirectory()
        CatalogFixture.remove(directory)

        await #expect(throws: CatalogError.readFailed) {
            try await CatalogLoader.load(from: directory)
        }
    }

    @Test
    func `invalid JSON in a work card file fails as a decode failure`() async {
        var catalog = MiniCatalog()
        catalog.emailChat = #"[{ "id": "c_2j3k4m5n", "#
        await Self.expectDecodeFailure(catalog)
    }

    @Test
    func `a card without its point fails as a decode failure`() async {
        var catalog = MiniCatalog()
        let point = #""point": "(point)","#
        catalog.meetings = catalog.meetings.replacingOccurrences(of: point, with: "")
        await Self.expectDecodeFailure(catalog)
    }

    @Test(arguments: ["11", "0", #""5""#])
    func `a card level outside 1 to 10 fails as a decode failure`(level: String) async {
        var catalog = MiniCatalog()
        catalog.meetings = MiniCatalog.cards([CardJSON(id: "c_2a3b4c5d", level: level)])
        await Self.expectDecodeFailure(catalog)
    }

    @Test(arguments: ["c_2a3b4c5", "c_0a3b4c5d", "C_2A3B4C5D", "v_5b6p8a8u"])
    func `a card id outside the format fails as a decode failure`(id: String) async {
        var catalog = MiniCatalog()
        catalog.meetings = MiniCatalog.cards([CardJSON(id: id)])
        await Self.expectDecodeFailure(catalog)
    }

    @Test(arguments: [
        #"[{ "id": "v_5b6p8a8u" }]"#,
        #"[{ "id": "c_9w4n4b3u", "replacedBy": "c_bad" }]"#,
        #"{ "id": "c_9w4n4b3u" }"#,
    ])
    func `a malformed retired id fails as a decode failure`(retiredIDs: String) async {
        var catalog = MiniCatalog()
        catalog.retiredIDs = retiredIDs
        await Self.expectDecodeFailure(catalog)
    }

    @Test
    func `a level definition outside 1 to 10 fails as a decode failure`() async {
        var catalog = MiniCatalog()
        catalog.levels = #"{ "levels": [{ "level": 11, "toeic": "", "cefr": "", "summary": "" }] }"#
        await Self.expectDecodeFailure(catalog)
    }

    @Test
    func `a taxonomy without topics fails as a decode failure`() async {
        var catalog = MiniCatalog()
        catalog.taxonomy = #"{ "version": 1 }"#
        await Self.expectDecodeFailure(catalog)
    }

    @Test
    func `a grammar file without items fails as a decode failure`() async {
        var catalog = MiniCatalog()
        catalog.grammar = "[]"
        await Self.expectDecodeFailure(catalog)
    }
}
