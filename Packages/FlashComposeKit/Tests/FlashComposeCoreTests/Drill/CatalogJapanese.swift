import Foundation

/// The Japanese a key renders as, read from the String Catalog's source: `swift test`
/// copies the catalog uncompiled, so resolving a resource in `ja` would only return its
/// English `defaultValue`.
enum CatalogJapanese {
    /// Why a key could not be rendered; a typo in a test, never a product failure.
    enum Failure: Error {
        case noJapanese(String)
    }

    /// `Sources/FlashComposeCore/Resources/Localizable.xcstrings`, resolved from this file's
    /// path.
    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/FlashComposeCore/Resources/Localizable.xcstrings")

    /// The catalog's Japanese format for `key`, formatted with `arguments` as the app
    /// would format it.
    static func render(_ key: String, _ arguments: [any CVarArg]) throws -> String {
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL))
        let strings = (catalog as? [String: Any])?["strings"] as? [String: Any]
        let entry = strings?[key] as? [String: Any]
        let japanese = (entry?["localizations"] as? [String: Any])?["ja"] as? [String: Any]
        let unit = japanese?["stringUnit"] as? [String: Any]
        guard let format = unit?["value"] as? String else {
            throw Failure.noJapanese(key)
        }
        return String(format: format, arguments: arguments)
    }
}
