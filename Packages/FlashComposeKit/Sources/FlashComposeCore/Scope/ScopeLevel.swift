/// One level as the scope screen lists it: the level and its TOEIC label from the
/// catalog's level definitions, shown verbatim.
public struct ScopeLevel: Hashable, Sendable {
    /// The level.
    public let level: Level
    /// The TOEIC score the catalog gives the level, such as `TOEIC 300`.
    public let toeicLabel: String

    /// Pairs a level with its TOEIC label.
    public init(level: Level, toeicLabel: String) {
        self.level = level
        self.toeicLabel = toeicLabel
    }
}
