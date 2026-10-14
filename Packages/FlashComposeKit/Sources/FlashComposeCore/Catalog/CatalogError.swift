/// Why the card catalog could not be loaded; either case means the app has no catalog,
/// never part of one (`docs/architecture.md` › Card catalog).
///
/// It carries nothing of the files: no path, no key, and no decoder message, which can
/// quote card text. The integrity test loads the real files under `just test`, so a
/// broken file fails there before a build ships.
public enum CatalogError: Error, Equatable, Sendable {
    /// A file was read but is not the JSON the catalog expects: malformed, missing a key,
    /// or holding a card id or level the domain types reject.
    case decodeFailed
    /// A file the catalog needs is missing from the bundle or could not be read.
    case readFailed
}
