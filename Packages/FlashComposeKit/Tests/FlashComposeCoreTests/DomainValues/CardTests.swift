import FlashComposeCore
import Testing

@Suite("Card")
struct CardTests {
    typealias Fixture = DomainValuesFixture

    static func card(alternatives: [String]) throws -> Card {
        try Card(
            id: Fixture.cardID("c_2t5h9y9g"),
            japanese: "(the Japanese prompt)",
            english: "If it rains tomorrow, I'll stay home.",
            alternatives: alternatives,
            point: "(a one-line point in Japanese)",
            topic: TopicID("daily"),
            subtopic: SubtopicID("home"),
            level: Level(3),
            grammar: [GrammarTagID("time-and-if-clauses")],
        )
    }

    @Test
    func `a card keeps every field it was given`() throws {
        let card = try Self.card(alternatives: [
            "If it rains tomorrow, I will stay at home.",
            "I'll stay home if it rains tomorrow.",
        ])

        #expect(try card.id == CardID("c_2t5h9y9g"))
        #expect(card.japanese == "(the Japanese prompt)")
        #expect(card.english == "If it rains tomorrow, I'll stay home.")
        #expect(card.alternatives == [
            "If it rains tomorrow, I will stay at home.",
            "I'll stay home if it rains tomorrow.",
        ])
        #expect(card.point == "(a one-line point in Japanese)")
        #expect(card.topic == TopicID("daily"))
        #expect(card.subtopic == SubtopicID("home"))
        #expect(try card.level == Level(3))
        #expect(card.grammar == [GrammarTagID("time-and-if-clauses")])
    }

    @Test
    func `a card with a single alternative is a card`() throws {
        let card = try Self.card(alternatives: ["I'll stay home if it rains tomorrow."])
        #expect(card.alternatives.count == 1)
    }

    @Test
    func `the taxonomy ids keep their text`() {
        #expect(TopicID("daily").rawValue == "daily")
        #expect(SubtopicID("home").rawValue == "home")
        #expect(GrammarTagID("time-and-if-clauses").rawValue == "time-and-if-clauses")
        #expect(TopicID("daily") != TopicID("work"))
        #expect(Set([SubtopicID("home"), SubtopicID("home"), SubtopicID("work")]).count == 2)
    }

    @Test
    func `the catalog values are Sendable`() {
        #expect(Fixture.requireSendable(Card.self))
        #expect(Fixture.requireSendable(CardID.self))
        #expect(Fixture.requireSendable(Level.self))
        #expect(Fixture.requireSendable(TopicID.self))
        #expect(Fixture.requireSendable(SubtopicID.self))
        #expect(Fixture.requireSendable(GrammarTagID.self))
    }
}
