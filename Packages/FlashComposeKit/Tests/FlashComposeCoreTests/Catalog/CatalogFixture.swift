import FlashComposeCore
import Foundation

/// Shared values and builders for the catalog suites: the real bundled catalog, loaded
/// once, and throwaway catalog directories a test writes and removes itself.
enum CatalogFixture {
    /// Why a fixture could not be built; a mistake in a test, never a product failure.
    enum FixtureError: Error {
        case notAnArray(String)
    }

    /// A card's fields as `var`s, so a test changes one and rebuilds the card.
    struct EditableCard {
        var japanese: String
        var english: String
        var alternatives: [String]
        var point: String
        var topic: TopicID
        var subtopic: SubtopicID
        var grammar: [GrammarTagID]
        let original: Card

        /// The card with the edited fields and the original's id and level.
        var card: Card {
            Card(
                id: original.id,
                japanese: japanese,
                english: english,
                alternatives: alternatives,
                point: point,
                topic: topic,
                subtopic: subtopic,
                level: original.level,
                grammar: grammar,
            )
        }

        init(_ card: Card) {
            japanese = card.japanese
            english = card.english
            alternatives = card.alternatives
            point = card.point
            topic = card.topic
            subtopic = card.subtopic
            grammar = card.grammar
            original = card
        }
    }

    /// The real catalog `CatalogLoader.load()` reads from the bundle, decoded once for
    /// every suite that only reads it.
    static let bundled = Task { try await CatalogLoader.load() }

    /// The card Example 1 of issue #12 spells out field by field: the first card of
    /// `cards/daily/hobbies.json`.
    static let fishingCardID = "c_2h3m7c9v"

    /// A fresh, empty directory of its own, so parallel tests never share a file.
    static func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FlashComposeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Removes a directory ``makeDirectory()`` made.
    static func remove(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A writable copy of the bundled catalog directory, named `Catalog` inside a fresh
    /// directory of its own, for a test that mutates one file of otherwise real data.
    static func copyOfBundledCatalog() throws -> URL {
        let copy = try makeDirectory().appending(path: "Catalog")
        try FileManager.default.copyItem(at: CatalogLoader.bundledDirectory(), to: copy)
        return copy
    }

    /// Writes `text` to `path` under `directory`, creating the folders on the way.
    static func write(_ text: String, to path: String, in directory: URL) throws {
        let file = directory.appending(path: path)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try Data(text.utf8).write(to: file)
    }

    /// Rewrites the JSON array at `path` with `change` applied to its elements.
    static func editArray(
        at path: String,
        in directory: URL,
        _ change: (inout [[String: Any]]) -> Void,
    ) throws {
        let file = directory.appending(path: path)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        guard var elements = object as? [[String: Any]] else {
            throw FixtureError.notAnArray(path)
        }
        change(&elements)
        try JSONSerialization.data(withJSONObject: elements).write(to: file)
    }

    /// The catalog with its cards replaced and everything else kept.
    static func catalog(_ catalog: CardCatalog, cards: [Card]) -> CardCatalog {
        CardCatalog(
            cards: cards,
            topics: catalog.topics,
            levels: catalog.levels,
            grammarTags: catalog.grammarTags,
            retiredIDs: catalog.retiredIDs,
        )
    }

    /// The catalog with its retired ids replaced and everything else kept.
    static func catalog(_ catalog: CardCatalog, retiredIDs: [RetiredCardID]) -> CardCatalog {
        CardCatalog(
            cards: catalog.cards,
            topics: catalog.topics,
            levels: catalog.levels,
            grammarTags: catalog.grammarTags,
            retiredIDs: retiredIDs,
        )
    }
}
