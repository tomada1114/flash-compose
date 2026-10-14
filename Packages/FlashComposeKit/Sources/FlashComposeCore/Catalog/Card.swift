/// One drill card: a Japanese prompt, its model English answer, other acceptable answers,
/// and a one-line point (`docs/product/requirements.md` §3.1).
///
/// Cards ship read-only inside the app and are never stored, so this value is what the
/// catalog decodes into and what the drill shows. Its properties are spelled as the
/// catalog's JSON keys are, except ``japanese`` and ``english``: the JSON's `ja` and `en`
/// are shorter than the lint's `identifier_name` rule allows, so the decoder maps those
/// two keys by name. The content rules — non-empty text, at least one alternative, known
/// topic, subtopic, and grammar tags — are the catalog integrity test's to hold, against
/// the real files, rather than this initializer's: a card is only ever made from those
/// files.
public struct Card: Identifiable, Hashable, Sendable {
    /// The card's identity, which its progress is stored under.
    public let id: CardID
    /// The Japanese prompt the learner answers; `ja` in the catalog's JSON.
    public let japanese: String
    /// The model English answer revealed after the learner speaks; `en` in the catalog's
    /// JSON.
    public let english: String
    /// Other answers that count; two or three in the shipped catalog.
    public let alternatives: [String]
    /// A one-line explanation, in Japanese, shown with the answer.
    public let point: String
    /// The topic the card belongs to, which the scope can turn off.
    public let topic: TopicID
    /// The subtopic within ``topic``.
    public let subtopic: SubtopicID
    /// How hard the card is, which the scope can turn off.
    public let level: Level
    /// The grammar items the card practices.
    public let grammar: [GrammarTagID]

    /// Creates a card from values that already passed their own checks (``CardID``,
    /// ``Level``).
    public init(
        id: CardID,
        japanese: String,
        english: String,
        alternatives: [String],
        point: String,
        topic: TopicID,
        subtopic: SubtopicID,
        level: Level,
        grammar: [GrammarTagID],
    ) {
        self.id = id
        self.japanese = japanese
        self.english = english
        self.alternatives = alternatives
        self.point = point
        self.topic = topic
        self.subtopic = subtopic
        self.level = level
        self.grammar = grammar
    }
}
