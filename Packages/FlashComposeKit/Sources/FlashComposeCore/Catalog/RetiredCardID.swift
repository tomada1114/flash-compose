/// A card id that is no longer in the catalog and never may be again
/// (`docs/architecture.md` › Card identity): a new card cannot take it, and progress
/// stored under it is ignored.
public struct RetiredCardID: Hashable, Sendable {
    /// The retired id.
    public let id: CardID
    /// The card that took this card's place when it was rewritten into a new question,
    /// or `nil` when the card was deleted outright.
    public let replacedBy: CardID?

    /// Creates an entry of `retired-ids.json`.
    public init(id: CardID, replacedBy: CardID?) {
        self.id = id
        self.replacedBy = replacedBy
    }
}
