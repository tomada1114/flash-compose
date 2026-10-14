/// A grammar tag's id as the catalog spells it, such as `time-and-if-clauses`.
///
/// Its own type for the reason ``TopicID`` gives: a tag can never be passed where a
/// topic or subtopic is meant, and which ids exist is the catalog's to say.
public struct GrammarTagID: Hashable, Sendable {
    /// The id exactly as the catalog spells it.
    public let rawValue: String

    /// Wraps an id read from the catalog.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
