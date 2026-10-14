import FlashComposeCore

/// Plays the caller the queue serves (#18's `DrillViewModel`): it deals, and grades the
/// way a saved grade would leave the inputs — a first answer of the day moves the card to
/// tomorrow and marks it answered today; a re-ask moves nothing.
///
/// It starts on ``QueueFixture/today`` with a default session; a test sets ``today``,
/// ``session``, ``candidates``, or ``answeredToday`` to change what the next call reads.
struct QueueDriver {
    /// Any fixed seed: the suites assert on what a seed makes repeatable, not on which
    /// card it picks.
    static let seed: UInt64 = 7

    var session = DrillSession()
    var generator = SeededGenerator(seed: seed)
    let catalog: CardCatalog
    var candidates: [Card]
    var progress: [CardID: CardProgress]
    var answeredToday: Set<CardID> = []
    var today: PracticeDay

    var input: QueueInput {
        QueueInput(
            today: today,
            catalog: catalog,
            progress: progress,
            candidates: candidates,
            answeredToday: answeredToday,
        )
    }

    var counts: HeaderCounts {
        session.counts(for: input)
    }

    init(catalog: CardCatalog, candidates: [Card], progress: [CardID: CardProgress]) throws {
        self.catalog = catalog
        self.candidates = candidates
        self.progress = progress
        today = try DomainValuesFixture.day(QueueFixture.today)
    }

    mutating func deal() -> DealtCard? {
        session.deal(for: input, using: &generator)
    }

    mutating func grade(_ grade: Grade) {
        if let current = session.current, current.pile != .reAsk {
            let id = current.card.id
            progress[id] = CardProgress(
                cardID: id,
                state: FSRSState(
                    stability: QueueFixture.stability,
                    difficulty: QueueFixture.difficulty,
                    reps: 1,
                    lapses: 0,
                    lastDay: today,
                    dueDay: today.adding(days: 1),
                ),
            )
            answeredToday.insert(id)
        }
        session.record(grade)
    }

    /// Deals and grades with `grading` until nothing is left or `limit` cards have been
    /// dealt; returns the cards in the order they were dealt.
    mutating func run(limit: Int, grading: (DealtCard) -> Grade) -> [DealtCard] {
        var dealt: [DealtCard] = []
        while dealt.count < limit, let next = deal() {
            dealt.append(next)
            grade(grading(next))
        }
        return dealt
    }
}
