/// When a graded card comes back within the same session, and how often
/// (`docs/product/requirements.md` §3.2).
///
/// Each gap counts the other cards shown before the card returns, so a card graded on
/// the 1st card with a gap of 4 comes back as the 6th.
public struct ReAskTuning: Sendable, Equatable {
    /// The old app's `TUNING.reAsk`, which the requirements carry over unchanged.
    private enum Default {
        static let afterAgain = 4
        static let afterHard = 8
        static let afterNewCardsFirstGood = 12
        static let maximumPerCard = 10
    }

    /// The values the app ships with: 4, 8, and 12 cards, at most 10 re-asks per card.
    public static let `default` = Self(
        afterAgain: Default.afterAgain,
        afterHard: Default.afterHard,
        afterNewCardsFirstGood: Default.afterNewCardsFirstGood,
        maximumPerCard: Default.maximumPerCard,
    )

    /// Other cards before a card graded × returns: the shortest gap, because a card just
    /// forgotten needs another try soonest.
    public let afterAgain: Int
    /// Other cards before a card graded △ returns: longer than for ×, since the learner
    /// nearly had it.
    public let afterHard: Int
    /// Other cards before a card dealt new returns after its first ○: once more, after a
    /// longer gap, so a card met for the first time is recalled again before the session
    /// lets it go.
    public let afterNewCardsFirstGood: Int
    /// The most re-asks one card gets in a session, so a card that keeps being missed
    /// stops crowding out the rest; FSRS brings it back on a later day.
    public let maximumPerCard: Int

    /// Gathers the re-ask tunables; the app uses ``default``.
    public init(afterAgain: Int, afterHard: Int, afterNewCardsFirstGood: Int, maximumPerCard: Int) {
        self.afterAgain = afterAgain
        self.afterHard = afterHard
        self.afterNewCardsFirstGood = afterNewCardsFirstGood
        self.maximumPerCard = maximumPerCard
    }
}
