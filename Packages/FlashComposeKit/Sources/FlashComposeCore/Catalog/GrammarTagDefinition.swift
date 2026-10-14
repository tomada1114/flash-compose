/// A grammar tag as `grammar.json` defines it.
public struct GrammarTagDefinition: Hashable, Sendable {
    /// The id cards name the tag by, such as `time-and-if-clauses`.
    public let id: GrammarTagID
    /// The tag's Japanese name, such as `倒置`; `ja` in the grammar file's JSON.
    public let name: String

    /// Creates a tag from its `grammar.json` entry, or a hand-built one for a test or
    /// preview.
    public init(id: GrammarTagID, name: String) {
        self.id = id
        self.name = name
    }
}
