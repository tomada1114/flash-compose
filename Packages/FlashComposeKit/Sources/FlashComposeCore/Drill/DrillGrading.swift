import Foundation

/// The instant a grade was tapped and the practice day it falls on, in the zone current
/// then (`docs/product/requirements.md` §4).
struct GradeMoment {
    let instant: Date
    let day: PracticeDay
}

/// The schedule's side of the drill: what a dealt card's buttons show, and what a grade
/// saves (`docs/architecture.md` › Scheduling, What moves a card).
///
/// A value over the scheduler, with no state of its own, so ``DrillViewModel`` keeps the
/// session and this keeps the rule: only a card's first answer of a practice day moves
/// its schedule, never a re-ask (`docs/product/requirements.md` §3.3).
struct DrillGrading {
    /// A grade made ready to save, and what saving it changes.
    struct GradedAnswer {
        let answer: Answer
        let progress: CardProgress
        /// Whether the answer moved the schedule: the card's first of its practice day.
        let moved: Bool
        /// Whether the card had no progress before, so the scope's never-seen count
        /// changes once it is saved.
        let wasUnseen: Bool
    }

    let scheduler: FSRSScheduler

    /// The card as it is shown. When its answer would move the schedule on the day it is
    /// dealt for, each button carries the interval its grade would set; a re-ask, or a
    /// card already moved that day, shows none. Worked out once, so the labels stay as
    /// they are while the card is on screen.
    func present(_ dealt: DealtCard, in input: QueueInput, topicName: String) -> DrillCard {
        let previous = input.progress[dealt.card.id]?.state
        let moves = dealt.pile != .reAsk && previous?.lastDay != input.today
        let preview = moves
            ? scheduler.preview(previous, on: input.today, card: dealt.card.id)
            : nil
        return DrillCard(
            card: dealt.card,
            pile: dealt.pile,
            topicName: topicName,
            gradeOptions: GradeOption.displayOrder.map { grade in
                GradeOption(grade: grade, intervalDays: preview?[grade].intervalDays)
            },
        )
    }

    /// The answer and progress `grade` saves for `shown`, made at `moment`. It moves the
    /// schedule — scheduled on the grade's own practice day — when the card has no
    /// progress yet, or when it is not a re-ask and has not moved on that day; otherwise
    /// the state after is the state before.
    func answer(
        _ grade: Grade,
        of shown: DrillCard,
        previous: CardProgress?,
        at moment: GradeMoment,
        secondsToReveal: Double,
    ) -> GradedAnswer {
        let id = shown.card.id
        let moves = previous.map { shown.pile != .reAsk && $0.state.lastDay != moment.day }
            ?? true
        let after = (moves ? nil : previous?.state)
            ?? scheduler.schedule(previous?.state, grade: grade, on: moment.day, card: id).state
        let answer = Answer(
            cardID: id,
            gradedAt: moment.instant,
            practiceDay: moment.day,
            grade: grade,
            kind: moves ? .firstOfDay : .reAsk,
            before: previous?.state,
            after: after,
            secondsToReveal: secondsToReveal,
        )
        return GradedAnswer(
            answer: answer,
            progress: CardProgress(cardID: id, state: after),
            moved: moves,
            wasUnseen: previous == nil,
        )
    }
}
