import Foundation

/// One entry in the append-only answer log: a single grade, re-asks included
/// (`docs/product/requirements.md` §3.6).
///
/// Nothing in this version reads the log back except the tests; it is kept because a log
/// cannot be rebuilt later — for statistics, undo, or fitting FSRS to the learner — so
/// each entry records everything about the grade that could matter then, including the
/// state before and after, rather than only what today's scheduler needs.
public struct Answer: Hashable, Sendable {
    /// Whether an answer moved the card's schedule.
    ///
    /// Only the first answer of a practice day moves it; a re-ask, even one shown after
    /// 04:00 has started a new day, never does (§3.3). The log records which one it was
    /// so a later reader need not re-derive it.
    public enum Kind: Hashable, Sendable, CaseIterable {
        /// The card's first answer of its practice day, which the scheduler moved.
        case firstOfDay
        /// A repeat of a card graded again earlier in the session, which moved nothing.
        case reAsk
    }

    /// The card that was graded.
    public let cardID: CardID
    /// The instant the grade was tapped.
    public let gradedAt: Date
    /// The practice day ``gradedAt`` belonged to in the time zone current at that answer,
    /// stored because the zone itself is not.
    public let practiceDay: PracticeDay
    /// The learner's grade.
    public let grade: Grade
    /// Whether this answer moved the schedule.
    public let kind: Kind
    /// The card's state before the grade; `nil` for a card answered for the first time.
    public let before: FSRSState?
    /// The card's state after the grade — the same as ``before`` for a re-ask, which
    /// moves nothing.
    public let after: FSRSState
    /// How long the card was on screen before the learner revealed the answer, in seconds.
    public let secondsToReveal: Double

    /// Creates a log entry from a grade that has already been decided and scheduled.
    public init(
        cardID: CardID,
        gradedAt: Date,
        practiceDay: PracticeDay,
        grade: Grade,
        kind: Kind,
        before: FSRSState?,
        after: FSRSState,
        secondsToReveal: Double,
    ) {
        self.cardID = cardID
        self.gradedAt = gradedAt
        self.practiceDay = practiceDay
        self.grade = grade
        self.kind = kind
        self.before = before
        self.after = after
        self.secondsToReveal = secondsToReveal
    }
}
