import FlashComposeCore

/// Shared builders for the queue suites: cards, a catalog over them, and progress whose
/// days are literals.
enum QueueFixture {
    typealias Day = DomainValuesFixture

    static let today = "2026-10-14"
    static let tomorrow = "2026-10-15"
    /// The day ``dueToday(_:)`` says each card was last answered on.
    static let lastWeek = "2026-10-10"
    /// The arbitrary numbers a progress builder fills in where a test does not care.
    static let stability = 3.0
    static let difficulty = 5.0

    /// The card numbered `index` — in the daily topic at level 1 — with a well-formed
    /// distinct id.
    static func card(_ index: Int) throws -> Card {
        try ScopeFixture.card(index, topic: ScopeFixture.daily, level: ScopeFixture.level(1))
    }

    /// The card numbered `index` in `topic` at `level`.
    static func card(_ index: Int, topic: TopicID, level: Int) throws -> Card {
        try ScopeFixture.card(index, topic: topic, level: ScopeFixture.level(level))
    }

    /// Cards numbered `range`.
    static func cards(_ range: Range<Int>) throws -> [Card] {
        try range.map { try card($0) }
    }

    /// A catalog of exactly `cards`, in that order.
    static func catalog(_ cards: [Card]) -> CardCatalog {
        CardCatalog(cards: cards, topics: [], levels: [], grammarTags: [], retiredIDs: [])
    }

    /// Progress for `card`, last answered on `last` and due on `due`. An earlier `last`
    /// makes the card less likely remembered on a given day.
    static func progress(_ card: Card, last: String, due: String) throws -> CardProgress {
        try progress(card, stability: stability, last: last, due: due)
    }

    /// Progress for `card` with `stability`: a lower one makes it less likely remembered.
    static func progress(
        _ card: Card,
        stability: Double,
        last: String,
        due: String,
    ) throws -> CardProgress {
        try CardProgress(
            cardID: card.id,
            state: FSRSState(
                stability: stability,
                difficulty: difficulty,
                reps: 1,
                lapses: 0,
                lastDay: Day.day(last),
                dueDay: Day.day(due),
            ),
        )
    }

    /// Progress for each card, last answered on ``lastWeek`` and due today.
    static func dueToday(_ cards: [Card]) throws -> [CardID: CardProgress] {
        try byID(cards.map { try progress($0, last: lastWeek, due: today) })
    }

    static func byID(_ progress: [CardProgress]) -> [CardID: CardProgress] {
        Dictionary(uniqueKeysWithValues: progress.map { ($0.cardID, $0) })
    }
}
