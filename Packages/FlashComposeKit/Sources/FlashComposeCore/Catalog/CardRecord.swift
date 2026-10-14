// The catalog's JSON files as the decoder reads them. Each record builds its domain value
// while it decodes, through the validating initializers (`CardID`, `Level`), so an id or
// a level they refuse fails decoding like a missing key does — the domain types stay free
// of `Codable`, and nothing invalid is ever half-built. Keys the app does not use (a
// subtopic's `scene`, a level's `words` and `ielts`, a grammar tag's `example`, every
// file's `version`) are left unread.

/// `taxonomy.json`: the topics, in order, each with its subtopics.
struct TaxonomyFile: Decodable {
    let topics: [TopicRecord]
}

struct TopicRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name = "ja"
        case subtopics
    }

    let topic: TopicDefinition

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        topic = try TopicDefinition(
            id: TopicID(container.decode(String.self, forKey: .id)),
            name: container.decode(String.self, forKey: .name),
            subtopics: container.decode([SubtopicRecord].self, forKey: .subtopics).map(\.subtopic),
        )
    }
}

struct SubtopicRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name = "ja"
    }

    let subtopic: SubtopicDefinition

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subtopic = try SubtopicDefinition(
            id: SubtopicID(container.decode(String.self, forKey: .id)),
            name: container.decode(String.self, forKey: .name),
        )
    }
}

/// `levels.json`: one entry per level.
struct LevelsFile: Decodable {
    let levels: [LevelRecord]
}

struct LevelRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case level
        case toeic
        case cefr
        case summary
    }

    let level: LevelDefinition

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = try LevelDefinition(
            level: Level(container.decode(Int.self, forKey: .level)),
            toeic: container.decode(String.self, forKey: .toeic),
            cefr: container.decode(String.self, forKey: .cefr),
            summary: container.decode(String.self, forKey: .summary),
        )
    }
}

/// `grammar.json`: the grammar tags, under `items`.
struct GrammarFile: Decodable {
    let items: [GrammarTagRecord]
}

struct GrammarTagRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name = "ja"
    }

    let tag: GrammarTagDefinition

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tag = try GrammarTagDefinition(
            id: GrammarTagID(container.decode(String.self, forKey: .id)),
            name: container.decode(String.self, forKey: .name),
        )
    }
}

/// One entry of `retired-ids.json`, a top-level array.
struct RetiredCardIDRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case replacedBy
    }

    let retired: RetiredCardID

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let replacedBy = try container.decodeIfPresent(String.self, forKey: .replacedBy)
        retired = try RetiredCardID(
            id: CardID(container.decode(String.self, forKey: .id)),
            replacedBy: replacedBy.map { rawValue throws(CardIDError) in try CardID(rawValue) },
        )
    }
}

/// One card of a `cards/<topic>/<subtopic>.json` file, a top-level array. The JSON's `ja`
/// and `en` become ``Card/japanese`` and ``Card/english``.
struct CardRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case japanese = "ja"
        case english = "en"
        case alternatives
        case point
        case topic
        case subtopic
        case level
        case grammar
    }

    let card: Card

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        card = try Card(
            id: CardID(container.decode(String.self, forKey: .id)),
            japanese: container.decode(String.self, forKey: .japanese),
            english: container.decode(String.self, forKey: .english),
            alternatives: container.decode([String].self, forKey: .alternatives),
            point: container.decode(String.self, forKey: .point),
            topic: TopicID(container.decode(String.self, forKey: .topic)),
            subtopic: SubtopicID(container.decode(String.self, forKey: .subtopic)),
            level: Level(container.decode(Int.self, forKey: .level)),
            grammar: container.decode([String].self, forKey: .grammar).map(GrammarTagID.init),
        )
    }
}
