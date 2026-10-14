/// One card's stored progress: the row the progress store keeps per card that has moved
/// (`docs/product/requirements.md` §5).
///
/// Keyed by ``CardID`` — never by position, file, or text — so a fix to a card's wording
/// keeps its schedule, and progress under an id the catalog no longer has is simply never
/// matched (`docs/architecture.md` › Card identity).
public struct CardProgress: Hashable, Sendable {
    /// The card this progress belongs to.
    public let cardID: CardID
    /// Where the scheduler last left the card.
    public let state: FSRSState

    /// Pairs a card with its current state.
    public init(cardID: CardID, state: FSRSState) {
        self.cardID = cardID
        self.state = state
    }
}
