/// Every card the app ships, with the definitions they refer to, decoded once at launch
/// and held in memory (`docs/architecture.md` › Card catalog).
///
/// The catalog is read-only data, so it is a value rather than a port: Core reads it from
/// its own bundle through ``CatalogLoader``, and a test or preview builds a small one with
/// ``init(cards:topics:levels:grammarTags:retiredIDs:)``. It is always the whole catalog —
/// a file that fails to load fails the load, so the app never runs on part of it.
public struct CardCatalog: Sendable {
    /// Every card, in taxonomy order — topic by topic, subtopic by subtopic — and within a
    /// subtopic in its file's order. A stable order, so anything that draws from it at
    /// random draws reproducibly from a seeded generator.
    public let cards: [Card]
    /// The topics, in the taxonomy's order, each with its subtopics.
    public let topics: [TopicDefinition]
    /// The levels, lowest first, as `levels.json` lists them.
    public let levels: [LevelDefinition]
    /// The grammar tags, as `grammar.json` lists them.
    public let grammarTags: [GrammarTagDefinition]
    /// Every id a card once had and no card may have again.
    public let retiredIDs: [RetiredCardID]

    private let cardsByID: [CardID: Card]

    /// Creates a catalog from values that already passed their own checks.
    ///
    /// The integrity rules — unique, unretired ids and known references — are the
    /// catalog integrity test's to hold against the real files, not this initializer's.
    /// A duplicated id therefore never traps here: ``cards`` keeps both cards, and
    /// ``card(id:)`` finds the first.
    public init(
        cards: [Card],
        topics: [TopicDefinition],
        levels: [LevelDefinition],
        grammarTags: [GrammarTagDefinition],
        retiredIDs: [RetiredCardID],
    ) {
        self.cards = cards
        self.topics = topics
        self.levels = levels
        self.grammarTags = grammarTags
        self.retiredIDs = retiredIDs
        cardsByID = Dictionary(cards.map { ($0.id, $0) }) { first, _ in first }
    }

    /// The card with `id`, or `nil` when the catalog has none — an id that was retired, or
    /// one stored by a build whose catalog had a card this one dropped.
    public func card(id: CardID) -> Card? {
        cardsByID[id]
    }
}
