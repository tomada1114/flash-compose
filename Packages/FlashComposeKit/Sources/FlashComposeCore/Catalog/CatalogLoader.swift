import Foundation

/// The catalog's files under one directory, each read and decoded into the one
/// ``CatalogError`` case that says which step failed.
private struct CatalogFiles {
    let directory: URL

    func decode<Value: Decodable>(
        _ type: Value.Type,
        at path: String,
    ) throws(CatalogError) -> Value {
        let data: Data
        do {
            data = try Data(contentsOf: directory.appending(path: path))
        } catch {
            throw .readFailed
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .decodeFailed
        }
    }
}

/// Reads the card catalog Core ships in its own bundle into one ``CardCatalog``.
///
/// No port stands in front of it: the catalog is read-only data inside Core's bundle, not
/// storage or an OS service, so there is nothing for an adapter to translate
/// (`docs/architecture.md` › Card catalog). A test hands ``load(from:)`` a directory of its
/// own instead.
public enum CatalogLoader {
    /// The directory, inside Core's resource bundle, that `Package.swift` copies
    /// `Resources/Catalog` to.
    static let directoryName = "Catalog"

    /// Decodes the bundled catalog — about 700 KB of JSON — off the main actor.
    ///
    /// `@concurrent` runs it on the global concurrent executor whichever actor awaits it,
    /// so the launch can open the progress store while the cards decode. Every file is
    /// read; one that cannot be read or decoded fails the whole load, and no partial
    /// catalog is ever returned.
    @concurrent
    public static func load() async throws(CatalogError) -> CardCatalog {
        try await load(from: bundledDirectory())
    }

    /// Decodes the catalog laid out under `directory` as `Resources/Catalog` is: the
    /// taxonomy, levels, grammar, and retired-id files, and one card file per subtopic
    /// the taxonomy names, at `cards/<topic>/<subtopic>.json`. A card file the taxonomy
    /// does not name is not read.
    @concurrent
    package static func load(from directory: URL) async throws(CatalogError) -> CardCatalog {
        let files = CatalogFiles(directory: directory)
        let topics = try files.decode(TaxonomyFile.self, at: "taxonomy.json").topics.map(\.topic)
        let levels = try files.decode(LevelsFile.self, at: "levels.json").levels.map(\.level)
        let grammarTags = try files.decode(GrammarFile.self, at: "grammar.json").items.map(\.tag)
        let retiredIDs = try files.decode([RetiredCardIDRecord].self, at: "retired-ids.json")
            .map(\.retired)
        var cards: [Card] = []
        for topic in topics {
            for subtopic in topic.subtopics {
                let path = "cards/\(topic.id.rawValue)/\(subtopic.id.rawValue).json"
                cards += try files.decode([CardRecord].self, at: path).map(\.card)
            }
        }
        return CardCatalog(
            cards: cards,
            topics: topics,
            levels: levels,
            grammarTags: grammarTags,
            retiredIDs: retiredIDs,
        )
    }

    /// Where the bundled catalog's files are: what ``load()`` reads, and what a test
    /// copies to break one file of otherwise real data.
    package static func bundledDirectory() throws(CatalogError) -> URL {
        guard let directory = Bundle.module.url(forResource: directoryName, withExtension: nil)
        else {
            throw .readFailed
        }
        return directory
    }
}
