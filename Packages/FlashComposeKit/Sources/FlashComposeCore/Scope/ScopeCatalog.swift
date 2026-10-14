/// What the scope needs from the card catalog: the topics in screen order, the levels
/// lowest first, and every card.
///
/// A plain value rather than the catalog's own type, so the scope depends on nothing but
/// the domain values; whoever loads the catalog builds one of these from it.
public struct ScopeCatalog: Hashable, Sendable {
    /// No topics, no levels, no cards: what the scope holds before the catalog arrives.
    public static let empty = Self(topics: [], levels: [], cards: [])

    /// The topics, in the order the scope screen lists them.
    public let topics: [ScopeTopic]
    /// The levels, in the order the scope screen lists them.
    public let levels: [ScopeLevel]
    /// Every card the catalog holds.
    public let cards: [Card]

    /// The topic ids, in screen order: what the last-on rule is judged over.
    public var topicIDs: [TopicID] {
        topics.map(\.id)
    }

    /// The levels, in screen order: what the last-on rule is judged over.
    public var levelValues: [Level] {
        levels.map(\.level)
    }

    /// Creates the scope's view of a catalog.
    public init(topics: [ScopeTopic], levels: [ScopeLevel], cards: [Card]) {
        self.topics = topics
        self.levels = levels
        self.cards = cards
    }

    /// How many cards nobody has seen yet, inside `selection` and outside it.
    ///
    /// A card is never-seen when `seenCardIDs` — the ids that have a progress row — does
    /// not hold its id. A progress row for an id the catalog no longer has is not a card,
    /// so it counts nowhere.
    public func neverSeenCounts(
        in selection: ScopeSelection,
        seenCardIDs: Set<CardID>,
    ) -> NeverSeenCounts {
        var inScope = 0
        var outsideScope = 0
        for card in cards where !seenCardIDs.contains(card.id) {
            if selection.includes(card) {
                inScope += 1
            } else {
                outsideScope += 1
            }
        }
        return NeverSeenCounts(inScope: inScope, outsideScope: outsideScope)
    }
}
