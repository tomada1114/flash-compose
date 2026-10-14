/// A subtopic's id as the catalog spells it, such as `home`.
///
/// Its own type for the reason ``TopicID`` gives: a subtopic can never be passed where a
/// topic is meant, and which ids exist is the catalog's to say.
public struct SubtopicID: Hashable, Sendable {
    /// The id exactly as the catalog spells it.
    public let rawValue: String

    /// Wraps an id read from the catalog.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
