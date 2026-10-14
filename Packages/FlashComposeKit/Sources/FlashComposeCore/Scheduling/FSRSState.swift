/// Where FSRS-6 has left one card: its memory, how often it has moved, and when it is
/// next due (`docs/product/requirements.md` §3.6).
///
/// Exactly the fields the scheduler needs to compute the next state from a grade, and the
/// ones the old app kept, so its golden vectors read straight into this shape. A card
/// that has never been graded has no state at all rather than a zeroed one, which is why
/// ``Answer/before`` is optional. The days are ``PracticeDay``s, so elapsed time and
/// intervals are always whole practice days.
public struct FSRSState: Hashable, Sendable {
    /// FSRS memory stability: roughly the days until recall probability falls to 90%.
    public let stability: Double
    /// FSRS difficulty, from 1 (easiest) to 10 (hardest).
    public let difficulty: Double
    /// Answers that moved the schedule — at most one per practice day.
    public let reps: Int
    /// Reviews graded again; a new card's first again is not one.
    public let lapses: Int
    /// The practice day of the last answer that moved the schedule.
    public let lastDay: PracticeDay
    /// The practice day the card is next due.
    public let dueDay: PracticeDay

    /// Creates a state; the scheduler is what decides its values, not this initializer.
    public init(
        stability: Double,
        difficulty: Double,
        reps: Int,
        lapses: Int,
        lastDay: PracticeDay,
        dueDay: PracticeDay,
    ) {
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.lapses = lapses
        self.lastDay = lastDay
        self.dueDay = dueDay
    }
}
