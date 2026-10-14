/// What the queue deals from and counts over, handed in afresh by the caller on every call
/// (`docs/architecture.md` › Core flows).
///
/// The queue reads no clock, store, or preference itself: a new practice day after 04:00,
/// a grade's new progress, or a scope change is simply a new input, so the same session
/// carries on across all three.
public struct QueueInput: Sendable {
    /// The practice day to deal for; due reviews are the cards due on or before it.
    public let today: PracticeDay
    /// Every card the app ships; progress under an id it lacks is never dealt or counted.
    public let catalog: CardCatalog
    /// Each recorded card's progress, keyed by its id.
    public let progress: [CardID: CardProgress]
    /// The cards new ones may come from, already narrowed to the scope by the caller
    /// (``ScopeSelection/includes(_:)``), so a later filter needs no change here. Only the
    /// never-seen among them — no progress, not answered today — are dealt as new.
    public let candidates: [Card]
    /// The cards whose first answer of ``today`` is already in. A re-ask's answer does not
    /// count: it moves nothing, so a card due today stays due after one.
    public let answeredToday: Set<CardID>

    /// Gathers what the queue reads.
    public init(
        today: PracticeDay,
        catalog: CardCatalog,
        progress: [CardID: CardProgress],
        candidates: [Card],
        answeredToday: Set<CardID>,
    ) {
        self.today = today
        self.catalog = catalog
        self.progress = progress
        self.candidates = candidates
        self.answeredToday = answeredToday
    }

    /// Whether `card` is never-seen: no progress and no answer today.
    func isNeverSeen(_ card: Card) -> Bool {
        progress[card.id] == nil && !answeredToday.contains(card.id)
    }

    /// `card`'s progress when it is due on ``today`` and not yet answered today.
    func dueProgress(of card: Card) -> CardProgress? {
        guard let recorded = progress[card.id], recorded.state.dueDay <= today,
              !answeredToday.contains(card.id)
        else {
            return nil
        }
        return recorded
    }
}
