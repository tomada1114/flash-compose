import FlashComposeCore
import Foundation
import Testing

/// What the bundled files themselves hold, read as raw JSON rather than through the
/// loader, so a rule the loader cannot see — a file the taxonomy does not name, a key the
/// decoder ignores — still fails here.
@Suite("Catalog resources")
struct CatalogResourceTests {
    /// The keys a card is written with: the old repository's, without `createdAt` and
    /// `stamps`.
    static let cardKeys: Set = [
        "id", "ja", "en", "alternatives", "point", "topic", "subtopic", "level", "grammar",
    ]

    /// The names directly inside `directory`.
    static func names(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
    }

    /// Every card file in the bundle, as its path under the catalog directory,
    /// `cards/<topic>/<subtopic>.json`.
    static func cardFiles() throws -> [String] {
        let cards = try CatalogLoader.bundledDirectory().appending(path: "cards")
        return try names(in: cards).flatMap { topic in
            try names(in: cards.appending(path: topic)).map { file in "cards/\(topic)/\(file)" }
        }
    }

    /// The raw JSON array in the bundled file at `path`.
    static func array(at path: String) throws -> [[String: Any]] {
        let file = try CatalogLoader.bundledDirectory().appending(path: path)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        return try #require(object as? [[String: Any]])
    }

    @Test
    func `the bundle holds the four definition files beside the cards`() throws {
        let names = try Self.names(in: CatalogLoader.bundledDirectory())
        let expected: Set = [
            "cards",
            "taxonomy.json",
            "levels.json",
            "grammar.json",
            "retired-ids.json",
        ]
        #expect(Set(names) == expected)
    }

    @Test
    func `the card files are exactly the 37 subtopics the taxonomy names`() async throws {
        let catalog = try await CatalogFixture.bundled.value
        let named = catalog.topics.flatMap { topic in
            topic.subtopics.map { "cards/\(topic.id.rawValue)/\($0.id.rawValue).json" }
        }
        let files = try Self.cardFiles()

        #expect(files.count == 37)
        #expect(Set(files) == Set(named))
    }

    @Test
    func `every card is written with exactly the nine catalog keys`() throws {
        for file in try Self.cardFiles() {
            for card in try Self.array(at: file) {
                let id = card["id"] as? String ?? "(no id)"
                #expect(Set(card.keys) == Self.cardKeys, "\(id) in \(file)")
            }
        }
    }

    @Test
    func `every card sits in the file of its topic and subtopic`() throws {
        for file in try Self.cardFiles() {
            for card in try Self.array(at: file) {
                let id = card["id"] as? String ?? "(no id)"
                let topic = card["topic"] as? String ?? "(no topic)"
                let subtopic = card["subtopic"] as? String ?? "(no subtopic)"
                #expect(file == "cards/\(topic)/\(subtopic).json", "\(id) in \(file)")
            }
        }
    }

    @Test
    func `retired ids carry only an id and an optional replacement`() throws {
        let retired = try Self.array(at: "retired-ids.json")

        #expect(retired.count == 77)
        #expect(retired.allSatisfy { Set($0.keys).isSubset(of: ["id", "replacedBy"]) })
        #expect(retired.count { $0["replacedBy"] != nil } == 51)
        #expect(retired.allSatisfy { ($0["id"] as? String)?.hasPrefix("c_") == true })
    }

    @Test
    func `the bundled directory is the one load reads`() async throws {
        let fromDirectory = try await CatalogLoader.load(from: CatalogLoader.bundledDirectory())
        let bundled = try await CatalogFixture.bundled.value

        #expect(fromDirectory.cards == bundled.cards)
    }
}
