/// A subtopic as `taxonomy.json` defines it, within its ``TopicDefinition``.
public struct SubtopicDefinition: Hashable, Sendable {
    /// The id cards name the subtopic by, such as `home`.
    public let id: SubtopicID
    /// The subtopic's Japanese name, such as `家・家事`; `ja` in the taxonomy's JSON.
    public let name: String

    /// Creates a subtopic from its taxonomy entry, or a hand-built one for a test or
    /// preview.
    public init(id: SubtopicID, name: String) {
        self.id = id
        self.name = name
    }
}

/// A topic as `taxonomy.json` defines it: the learner's scope turns it on or off, and a
/// card's front names it.
public struct TopicDefinition: Hashable, Sendable {
    /// The id cards name the topic by, such as `daily`.
    public let id: TopicID
    /// The topic's Japanese name, such as `日常`; `ja` in the taxonomy's JSON.
    public let name: String
    /// The topic's subtopics, in the taxonomy's order.
    public let subtopics: [SubtopicDefinition]

    /// Creates a topic from its taxonomy entry, or a hand-built one for a test or preview.
    public init(id: TopicID, name: String, subtopics: [SubtopicDefinition]) {
        self.id = id
        self.name = name
        self.subtopics = subtopics
    }
}
