/// Which pile a dealt card came from: what the card's front says it is, and the header
/// count underlined while it is on screen (`docs/product/ux-flows.md` §2).
///
/// A re-ask never moves the card's schedule (`docs/product/requirements.md` §3.3); a new
/// card or a review is the card's first answer of the day, which does.
public enum DrillPile: Hashable, Sendable, CaseIterable {
    /// 新規: a never-seen card from the scope.
    case new
    /// もう一度: a card shown again in this session because an earlier grade called for it.
    case reAsk
    /// 復習: a card due today, from any topic and level.
    case review
}

/// A card the queue dealt, with the pile it came from.
public struct DealtCard: Hashable, Sendable {
    /// The card to show.
    public let card: Card
    /// Why it was dealt.
    public let pile: DrillPile

    /// Pairs a card with its pile; the queue is what decides both.
    public init(card: Card, pile: DrillPile) {
        self.card = card
        self.pile = pile
    }
}
