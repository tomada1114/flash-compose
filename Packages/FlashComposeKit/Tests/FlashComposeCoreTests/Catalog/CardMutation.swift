import FlashComposeCore
import Testing

/// One field of a card changed to a value that breaks one integrity rule.
enum CardMutation: Sendable, CustomTestStringConvertible {
    case alternatives([String])
    case english(String)
    case grammar([String])
    case japanese(String)
    case point(String)
    case subtopic(String)
    case topic(String)

    var testDescription: String {
        switch self {
        case let .alternatives(texts):
            "alternatives \(texts)"

        case let .english(text):
            "en \(text.debugDescription)"

        case let .grammar(tags):
            "grammar \(tags)"

        case let .japanese(text):
            "ja \(text.debugDescription)"

        case let .point(text):
            "point \(text.debugDescription)"

        case let .subtopic(subtopic):
            "subtopic \(subtopic)"

        case let .topic(topic):
            "topic \(topic)"
        }
    }

    func applied(to card: Card) -> Card {
        var edited = CatalogFixture.EditableCard(card)
        switch self {
        case let .alternatives(texts):
            edited.alternatives = texts

        case let .english(text):
            edited.english = text

        case let .grammar(tags):
            edited.grammar = tags.map(GrammarTagID.init)

        case let .japanese(text):
            edited.japanese = text

        case let .point(text):
            edited.point = text

        case let .subtopic(subtopic):
            edited.subtopic = SubtopicID(subtopic)

        case let .topic(topic):
            edited.topic = TopicID(topic)
        }
        return edited.card
    }
}
