/// The never-seen cards a scope holds and the ones it leaves out: what the drill's new
/// count and D3's outside-scope line show.
public struct NeverSeenCounts: Hashable, Sendable {
    /// Never-seen cards inside the scope.
    public let inScope: Int
    /// Never-seen cards the scope turns off.
    public let outsideScope: Int

    /// Pairs the two counts.
    public init(inScope: Int, outsideScope: Int) {
        self.inScope = inScope
        self.outsideScope = outsideScope
    }
}
