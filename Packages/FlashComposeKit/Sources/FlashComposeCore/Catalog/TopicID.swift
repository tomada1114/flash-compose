/// A topic's id as the catalog spells it, such as `daily`.
///
/// Topics, subtopics, and grammar tags are each their own type, though all three are
/// strings, so a subtopic can never be passed where a topic is meant. Which ids exist is
/// the catalog's to say — its integrity test holds every card to the definitions — so the
/// initializer checks nothing.
public struct TopicID: Hashable, Sendable {
    /// The id exactly as the catalog spells it.
    public let rawValue: String

    /// Wraps an id read from the catalog or the stored scope.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
