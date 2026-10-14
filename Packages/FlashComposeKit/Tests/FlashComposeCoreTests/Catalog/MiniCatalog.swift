import Foundation

/// A small, complete catalog directory written as text, so a loader test can break exactly
/// one file and know every other file is valid.
///
/// The taxonomy lists `meetings` before `email-chat`, the reverse of their alphabetical
/// order, so a test can tell taxonomy order from a directory listing's.
struct MiniCatalog {
    /// One card's JSON, as the catalog spells its keys, with `id` and `level` raw so a
    /// test can write one the domain types reject.
    struct CardJSON {
        var id: String
        var english = "(answer)"
        var subtopic = "meetings"
        var level = "2"

        var text: String {
            """
            {
                "id": "\(id)",
                "ja": "(prompt)",
                "en": "\(english)",
                "alternatives": ["(alternative)"],
                "point": "(point)",
                "topic": "work",
                "subtopic": "\(subtopic)",
                "level": \(level),
                "grammar": ["modals"]
            }
            """
        }
    }

    static let taxonomy = """
    {
        "version": 1,
        "topics": [
            {
                "id": "work",
                "ja": "仕事",
                "subtopics": [
                    { "id": "meetings", "ja": "会議", "scene": "(ignored)" },
                    { "id": "email-chat", "ja": "メール・チャット", "scene": "(ignored)" }
                ]
            }
        ]
    }
    """

    static let levels = """
    {
        "version": 1,
        "levels": [
            { "level": 1, "toeic": "300", "cefr": "A1+", "ielts": null, "summary": "(one)" },
            { "level": 2, "toeic": "400", "cefr": "A2", "ielts": null, "summary": "(two)" }
        ]
    }
    """

    static let grammar = """
    { "version": 1, "items": [{ "id": "modals", "ja": "助動詞", "minLevel": 2 }] }
    """

    static let retiredIDs = """
    [{ "id": "c_9w4n4b3u", "replacedBy": "c_2a3b4c5d" }, { "id": "c_2g8s4t5k" }]
    """

    var taxonomy = Self.taxonomy
    var levels = Self.levels
    var grammar = Self.grammar
    var retiredIDs = Self.retiredIDs
    var meetings = Self.cards([
        CardJSON(id: "c_2a3b4c5d", english: "Let's start."),
        CardJSON(id: "c_6e7f8g9h", english: "Any questions?"),
    ])
    var emailChat = Self.cards([
        CardJSON(id: "c_2j3k4m5n", english: "Thanks for the email.", subtopic: "email-chat"),
    ])

    /// A card file holding `cards`, in order.
    static func cards(_ cards: [CardJSON]) -> String {
        "[\n" + cards.map(\.text).joined(separator: ",\n") + "\n]\n"
    }

    /// Writes every file into `directory`, except the paths in `omitted`.
    func write(to directory: URL, omitting omitted: Set<String>) throws {
        let files = [
            "taxonomy.json": taxonomy,
            "levels.json": levels,
            "grammar.json": grammar,
            "retired-ids.json": retiredIDs,
            "cards/work/meetings.json": meetings,
            "cards/work/email-chat.json": emailChat,
        ]
        for (path, text) in files where !omitted.contains(path) {
            try CatalogFixture.write(text, to: path, in: directory)
        }
    }
}
