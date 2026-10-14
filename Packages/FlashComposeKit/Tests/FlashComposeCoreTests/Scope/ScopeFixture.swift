import FlashComposeCore
import Foundation

/// Shared builders for the scope suites: a catalog shaped like the shipped one — 1,952
/// cards, five topics, ten levels, 33 of them 旅行 × L1 (`docs/product/requirements.md`
/// §3.5) — until #12's real catalog exists.
enum ScopeFixture {
    /// One topic id paired with one level: a cell of the catalog.
    struct Cell {
        let topic: TopicID
        let level: Level
    }

    static let daily = TopicID("daily")
    static let social = TopicID("social")
    static let work = TopicID("work")
    static let travel = TopicID("travel")
    static let tech = TopicID("tech")

    static let topics = [
        ScopeTopic(id: daily, name: "日常"),
        ScopeTopic(id: social, name: "雑談・人付き合い"),
        ScopeTopic(id: work, name: "仕事"),
        ScopeTopic(id: travel, name: "旅行"),
        ScopeTopic(id: tech, name: "IT・技術"),
    ]

    static let toeicLabels = [
        "TOEIC 300", "TOEIC 400", "TOEIC 500", "TOEIC 600", "TOEIC 700",
        "TOEIC 750", "TOEIC 800", "TOEIC 850", "TOEIC 900", "TOEIC 990+",
    ]

    static let levels = zip(Level.allCases, toeicLabels).map { level, label in
        ScopeLevel(level: level, toeicLabel: label)
    }

    /// The shipped catalog's size (`docs/product/requirements.md` §3.5).
    static let catalogSize = 1_952
    /// How many shipped cards are 旅行 × L1.
    static let travelLevelOneCount = 33
    /// The level every topic has one card at in ``smallCatalog()``.
    static let smallCatalogLevel = 5
    /// Where the small catalog's travel-per-level cards start numbering.
    static let smallCatalogOffset = 100

    static let digits = Array("23456789")
    static let letters = Array("abcdefghjkmnpqrstuvwxyz")

    /// A locale whose number format groups thousands with a comma.
    static let english = Locale(identifier: "en_US")

    /// A well-formed, distinct card id for every index below 33,856.
    static func cardID(_ index: Int) throws -> CardID {
        let pairs = digits.count * letters.count
        func pair(_ value: Int) -> String {
            "\(digits[value / letters.count])\(letters[value % letters.count])"
        }
        return try CardID("c_\(pair(index / pairs))\(pair(index % pairs))2a2a")
    }

    static func level(_ number: Int) throws -> Level {
        try Level(number)
    }

    static func card(_ index: Int, topic: TopicID, level: Level) throws -> Card {
        try Card(
            id: cardID(index),
            japanese: "日本語",
            english: "English",
            alternatives: ["Alternative"],
            point: "ポイント",
            topic: topic,
            subtopic: SubtopicID("sub"),
            level: level,
            grammar: [],
        )
    }

    /// 1,952 cards: the first 33 are 旅行 × L1, the rest cycle through every other topic
    /// and level pair.
    static func fullCards() throws -> [Card] {
        let lowest = try level(1)
        let travelLevelOne = try (0 ..< travelLevelOneCount).map { index in
            try card(index, topic: travel, level: lowest)
        }
        let otherCells = topics.flatMap { topic in
            Level.allCases.map { level in Cell(topic: topic.id, level: level) }
        }
        .filter { cell in cell.topic != travel || cell.level != lowest }
        let rest = try (travelLevelOneCount ..< catalogSize).map { index in
            let cell = otherCells[index % otherCells.count]
            return try card(index, topic: cell.topic, level: cell.level)
        }
        return travelLevelOne + rest
    }

    static func fullCatalog() throws -> ScopeCatalog {
        try ScopeCatalog(topics: topics, levels: levels, cards: fullCards())
    }

    /// A small catalog: one card per topic at L5, and one travel card per other level.
    static func smallCatalog() throws -> ScopeCatalog {
        let middle = try level(smallCatalogLevel)
        var cards = try topics.enumerated().map { offset, topic in
            try card(offset, topic: topic.id, level: middle)
        }
        let otherLevels = Level.allCases.filter { $0 != middle }
        cards += try otherLevels.enumerated().map { offset, level in
            try card(smallCatalogOffset + offset, topic: travel, level: level)
        }
        return ScopeCatalog(topics: topics, levels: levels, cards: cards)
    }
}
