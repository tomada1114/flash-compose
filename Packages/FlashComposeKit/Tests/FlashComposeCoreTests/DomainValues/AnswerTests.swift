import FlashComposeCore
import Foundation
import Testing

/// The values the progress store keeps: a card's FSRS state, its progress row, and the
/// answer log's entries.
@Suite("FSRSState, CardProgress, and Answer")
struct AnswerTests {
    typealias Fixture = DomainValuesFixture

    @Test
    func `an FSRS state keeps the six numbers and days it was given`() throws {
        let state = try FSRSState(
            stability: 3.25,
            difficulty: 5.5,
            reps: 2,
            lapses: 1,
            lastDay: Fixture.day("2026-10-13"),
            dueDay: Fixture.day("2026-10-16"),
        )

        #expect(state.stability == 3.25)
        #expect(state.difficulty == 5.5)
        #expect(state.reps == 2)
        #expect(state.lapses == 1)
        #expect(try state.lastDay == (Fixture.day("2026-10-13")))
        #expect(try state.dueDay == (Fixture.day("2026-10-16")))
    }

    @Test
    func `card progress pairs a card id with its state`() throws {
        let state = try Fixture.state(last: "2026-10-13", due: "2026-10-16")
        let progress = try CardProgress(cardID: Fixture.cardID("c_7k2m9x4q"), state: state)

        #expect(try progress.cardID == CardID("c_7k2m9x4q"))
        #expect(progress.state == state)
    }

    @Test
    func `a new card's first answer has no state before`() throws {
        let after = try Fixture.state(last: "2026-10-13", due: "2026-10-14")
        let answer = try Answer(
            cardID: Fixture.cardID("c_2t5h9y9g"),
            gradedAt: Fixture.instant("2026-10-14T01:30:00+09:00"),
            practiceDay: Fixture.day("2026-10-13"),
            grade: .again,
            kind: .firstOfDay,
            before: nil,
            after: after,
            secondsToReveal: 4.5,
        )

        #expect(try answer.cardID == CardID("c_2t5h9y9g"))
        #expect(try answer.gradedAt == (Fixture.instant("2026-10-13T16:30:00Z")))
        #expect(try answer.practiceDay == (Fixture.day("2026-10-13")))
        #expect(answer.grade == .again)
        #expect(answer.kind == .firstOfDay)
        #expect(answer.before == nil)
        #expect(answer.after == after)
        #expect(answer.secondsToReveal == 4.5)
    }

    @Test
    func `a re-ask records the state before it`() throws {
        let state = try Fixture.state(last: "2026-10-13", due: "2026-10-14")
        let answer = try Answer(
            cardID: Fixture.cardID("c_2t5h9y9g"),
            gradedAt: Fixture.instant("2026-10-13T22:00:00+09:00"),
            practiceDay: Fixture.day("2026-10-13"),
            grade: .good,
            kind: .reAsk,
            before: state,
            after: state,
            secondsToReveal: 2,
        )

        #expect(answer.kind == .reAsk)
        #expect(answer.before == state)
        #expect(Answer.Kind.allCases.count == 2)
    }

    @Test
    func `the progress values are Sendable`() {
        #expect(Fixture.requireSendable(FSRSState.self))
        #expect(Fixture.requireSendable(CardProgress.self))
        #expect(Fixture.requireSendable(Answer.self))
        #expect(Fixture.requireSendable(Answer.Kind.self))
        #expect(Fixture.requireSendable(Grade.self))
        #expect(Fixture.requireSendable(PracticeDay.self))
    }
}
