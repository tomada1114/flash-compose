/// The drill header's three counts and the pile the card on screen counts in
/// (`docs/product/ux-flows.md` §2).
public struct HeaderCounts: Hashable, Sendable {
    /// 新規: never-seen cards in the scope, the card on screen included.
    public let new: Int
    /// 復習: cards due today in every topic and level not yet answered today, the card on
    /// screen included.
    public let review: Int
    /// もう一度: cards waiting for a re-ask, the card on screen included when it is one.
    public let reAsk: Int
    /// The pile the card on screen came from, which the header underlines; `nil` when no
    /// card waits for a grade, as on the done screen.
    public let currentPile: DrillPile?

    /// Gathers the counts; ``DrillSession/counts(for:)`` is what decides them.
    public init(new: Int, review: Int, reAsk: Int, currentPile: DrillPile?) {
        self.new = new
        self.review = review
        self.reAsk = reAsk
        self.currentPile = currentPile
    }
}
