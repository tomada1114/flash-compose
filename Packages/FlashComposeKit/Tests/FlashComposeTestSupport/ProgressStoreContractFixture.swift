import FlashComposeCore
import Foundation

/// The grades ``ProgressStoreContract`` records, worked out by hand from the issue's
/// examples, so a failure message names the same values on every run.
///
/// Every number differs from every other — `before` from `after`, `reps` from `lapses` —
/// so a field the store swaps or drops shows, and the re-ask falls after 04:00 on the
/// next date, so its practice day differs from its state's last day. Every instant is a
/// distinct whole second, and later instants are recorded later, so sorting the log by
/// `gradedAt` gives the order the answers were recorded in.
struct ProgressStoreContractFixture {
    /// Why a fixture string could not be read: a typo in the fixture, never a store's fault.
    enum FixtureError: Error {
        case notADate(String)
    }

    /// The numbers the states and answers carry, named so each one is told apart.
    private enum Value {
        static let firstStability = 2.3065
        static let firstDifficulty = 2.11810397
        static let secondStability = 7.25
        static let secondDifficulty = 2.75
        static let otherStability = 0.212
        static let otherDifficulty = 6.4133
        static let failedStability = 19.5
        static let failedDifficulty = 2.5
        static let laterStability = 1.5
        static let laterDifficulty = 6.25
        static let twoReps = 2
        static let threeReps = 3
        static let firstSeconds = 4.2
        static let secondSeconds = 6.5
        static let otherSeconds = 12.75
        static let reAskSeconds = 3.0
        static let failedSeconds = 2.25
        static let laterSeconds = 8.5
        static let unreadableStability = 3.75
        static let unreadableDifficulty = 4.5
        static let revivedStability = 0.4072
        static let revivedDifficulty = 5.3
        static let revivedSeconds = 5.25
        static let fourReps = 4
        static let twoLapses = 2
    }

    /// One grade's own facts, apart from the card and its states.
    private struct Grading {
        let instant: String
        let day: String
        let grade: Grade
        let kind: Answer.Kind
        let secondsToReveal: Double
    }

    /// Each answer's own facts, in the order the contract records them.
    private enum Gradings {
        static let first = Grading(
            instant: "2026-10-14T09:00:00+09:00",
            day: "2026-10-14",
            grade: .good,
            kind: .firstOfDay,
            secondsToReveal: Value.firstSeconds,
        )
        static let second = Grading(
            instant: "2026-10-17T08:00:00+09:00",
            day: "2026-10-17",
            grade: .hard,
            kind: .firstOfDay,
            secondsToReveal: Value.secondSeconds,
        )
        static let other = Grading(
            instant: "2026-10-17T08:10:00+09:00",
            day: "2026-10-17",
            grade: .again,
            kind: .firstOfDay,
            secondsToReveal: Value.otherSeconds,
        )
        static let reAsk = Grading(
            instant: "2026-10-18T04:05:00+09:00",
            day: "2026-10-18",
            grade: .again,
            kind: .reAsk,
            secondsToReveal: Value.reAskSeconds,
        )
        static let failed = Grading(
            instant: "2026-10-18T07:00:00+09:00",
            day: "2026-10-18",
            grade: .good,
            kind: .firstOfDay,
            secondsToReveal: Value.failedSeconds,
        )
        static let later = Grading(
            instant: "2026-10-18T07:01:00+09:00",
            day: "2026-10-18",
            grade: .hard,
            kind: .firstOfDay,
            secondsToReveal: Value.laterSeconds,
        )
        static let revived = Grading(
            instant: "2026-10-18T07:05:00+09:00",
            day: "2026-10-18",
            grade: .hard,
            kind: .firstOfDay,
            secondsToReveal: Value.revivedSeconds,
        )
    }

    /// The states the grades leave behind.
    private struct States {
        let first: FSRSState
        let second: FSRSState
        let otherFirst: FSRSState
        let failed: FSRSState
        let otherLater: FSRSState

        init() throws {
            first = try FSRSState(
                stability: Value.firstStability,
                difficulty: Value.firstDifficulty,
                reps: 1,
                lapses: 0,
                lastDay: ProgressStoreContractFixture.day("2026-10-14"),
                dueDay: ProgressStoreContractFixture.day("2026-10-17"),
            )
            second = try FSRSState(
                stability: Value.secondStability,
                difficulty: Value.secondDifficulty,
                reps: Value.twoReps,
                lapses: 0,
                lastDay: ProgressStoreContractFixture.day("2026-10-17"),
                dueDay: ProgressStoreContractFixture.day("2026-10-27"),
            )
            otherFirst = try FSRSState(
                stability: Value.otherStability,
                difficulty: Value.otherDifficulty,
                reps: 1,
                lapses: 0,
                lastDay: ProgressStoreContractFixture.day("2026-10-17"),
                dueDay: ProgressStoreContractFixture.day("2026-10-18"),
            )
            failed = try FSRSState(
                stability: Value.failedStability,
                difficulty: Value.failedDifficulty,
                reps: Value.threeReps,
                lapses: 0,
                lastDay: ProgressStoreContractFixture.day("2026-10-18"),
                dueDay: ProgressStoreContractFixture.day("2026-11-09"),
            )
            otherLater = try FSRSState(
                stability: Value.laterStability,
                difficulty: Value.laterDifficulty,
                reps: Value.twoReps,
                lapses: 1,
                lastDay: ProgressStoreContractFixture.day("2026-10-18"),
                dueDay: ProgressStoreContractFixture.day("2026-10-20"),
            )
        }
    }

    /// The third card's states: the one its unreadable row held, and the one its first
    /// grade as a new card leaves.
    private struct ThirdCardStates {
        let unreadable: FSRSState
        let revived: FSRSState

        init() throws {
            unreadable = try FSRSState(
                stability: Value.unreadableStability,
                difficulty: Value.unreadableDifficulty,
                reps: Value.fourReps,
                lapses: Value.twoLapses,
                lastDay: ProgressStoreContractFixture.day("2026-10-16"),
                dueDay: ProgressStoreContractFixture.day("2026-10-19"),
            )
            revived = try FSRSState(
                stability: Value.revivedStability,
                difficulty: Value.revivedDifficulty,
                reps: 1,
                lapses: 0,
                lastDay: ProgressStoreContractFixture.day("2026-10-18"),
                dueDay: ProgressStoreContractFixture.day("2026-10-19"),
            )
        }
    }

    /// `c_2t5h9y9g` graded ○ on its first day, 2026-10-14 (Example 1).
    let firstAnswer: Answer
    let firstProgress: CardProgress
    /// The same card graded △ three days later, 2026-10-17 (Example 2).
    let secondAnswer: Answer
    let secondProgress: CardProgress
    /// A second card, `c_3w4x5y6z`, graded × on its first day.
    let otherAnswer: Answer
    let otherProgress: CardProgress
    /// The first card shown again after 04:00 the next date and graded ×: a re-ask, which
    /// moves nothing, so its progress stays ``secondProgress``.
    let reAskAnswer: Answer
    /// A grade of the first card the contract makes fail (Example 3).
    let failedAnswer: Answer
    let failedProgress: CardProgress
    /// A grade of the second card recorded after the failure.
    let laterAnswer: Answer
    let laterProgress: CardProgress
    /// A third card, `c_4a5b6c7d`, whose stored row the contract makes unreadable.
    let unreadableProgress: CardProgress
    /// That card graded △ as a new card — its unreadable row read as never seen — after
    /// the damage.
    let revivedAnswer: Answer
    let revivedProgress: CardProgress

    /// The log once the second card and the re-ask are in, and still after the failure.
    var answersBeforeFailure: [Answer] {
        [firstAnswer, secondAnswer, otherAnswer, reAskAnswer]
    }

    init() throws {
        let card = try CardID("c_2t5h9y9g")
        let other = try CardID("c_3w4x5y6z")
        let damaged = try CardID("c_4a5b6c7d")
        let states = try States()
        let third = try ThirdCardStates()

        firstAnswer = try Self.answer(card, Gradings.first, from: nil, to: states.first)
        firstProgress = CardProgress(cardID: card, state: states.first)
        secondAnswer = try Self.answer(
            card,
            Gradings.second,
            from: states.first,
            to: states.second,
        )
        secondProgress = CardProgress(cardID: card, state: states.second)
        otherAnswer = try Self.answer(other, Gradings.other, from: nil, to: states.otherFirst)
        otherProgress = CardProgress(cardID: other, state: states.otherFirst)
        reAskAnswer = try Self.answer(
            card,
            Gradings.reAsk,
            from: states.second,
            to: states.second,
        )
        failedAnswer = try Self.answer(
            card,
            Gradings.failed,
            from: states.second,
            to: states.failed,
        )
        failedProgress = CardProgress(cardID: card, state: states.failed)
        laterAnswer = try Self.answer(
            other,
            Gradings.later,
            from: states.otherFirst,
            to: states.otherLater,
        )
        laterProgress = CardProgress(cardID: other, state: states.otherLater)
        unreadableProgress = CardProgress(cardID: damaged, state: third.unreadable)
        revivedAnswer = try Self.answer(damaged, Gradings.revived, from: nil, to: third.revived)
        revivedProgress = CardProgress(cardID: damaged, state: third.revived)
    }

    /// The practice day a `"YYYY-MM-DD"` string names.
    private static func day(_ iso: String) throws -> PracticeDay {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
            .compactMap { Int($0) }
        let middle = parts.dropFirst().dropLast()
        guard let year = parts.first, let month = middle.first, let day = parts.last,
              middle.count == 1
        else {
            throw FixtureError.notADate(iso)
        }
        return try PracticeDay(year: year, month: month, day: day)
    }

    private static func answer(
        _ card: CardID,
        _ grading: Grading,
        from before: FSRSState?,
        to after: FSRSState,
    ) throws -> Answer {
        try Answer(
            cardID: card,
            gradedAt: Date(grading.instant, strategy: .iso8601),
            practiceDay: day(grading.day),
            grade: grading.grade,
            kind: grading.kind,
            before: before,
            after: after,
            secondsToReveal: grading.secondsToReveal,
        )
    }
}
