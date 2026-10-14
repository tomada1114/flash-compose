/// One topic as the scope screen lists it: its id and its Japanese name, which is card
/// content shown verbatim, never a String Catalog key.
public struct ScopeTopic: Hashable, Sendable {
    /// The id cards and the stored scope name the topic by.
    public let id: TopicID
    /// The topic's Japanese name from the catalog, such as `旅行`.
    public let name: String

    /// Pairs a topic id with its name.
    public init(id: TopicID, name: String) {
        self.id = id
        self.name = name
    }
}
