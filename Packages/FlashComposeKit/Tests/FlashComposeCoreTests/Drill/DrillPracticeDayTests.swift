import FlashComposeCore
import Foundation
import Testing

/// REQ-009: the practice day is re-read when the scene becomes active and when 04:00
/// passes; a card on screen keeps its kind and labels, and its answer carries the day it
/// is graded on.
@MainActor
@Suite("Drill practice day")
struct DrillPracticeDayTests {
    typealias Fixture = DrillFixture

    /// A review due on the 13th, a card due on the 14th, and two new cards, at 03:58 on
    /// the 14th — still practice day 2026-10-13.
    private static func beforeFour() throws -> DrillSetup {
        let dueThirteenth = try QueueFixture.card(0)
        let dueFourteenth = try QueueFixture.card(1)
        var setup = try DrillSetup(cards: [dueThirteenth, dueFourteenth] + Fixture.cards(
            2,
            from: 10,
        ))
        setup.progress = try [
            Fixture.progress(dueThirteenth, last: "2026-10-06", due: Fixture.today),
            Fixture.progress(dueFourteenth, last: "2026-10-12", due: Fixture.tomorrow),
        ]
        setup.start = "2026-10-14T03:58:00+09:00"
        return setup
    }

    /// Example 4 (`docs/product/ux-flows.md` F7).
    @Test
    func `cardOnScreenKeepsItsKindAcrossBoundary`() async throws {
        let drill = try await Self.beforeFour().started()
        #expect(try drill.model.practiceDay == Fixture.day(Fixture.today))
        let shown = try #require(drill.model.card)
        #expect(shown.pile == .review)
        #expect(shown.gradeOptions.allSatisfy { $0.intervalDays != nil })
        #expect(drill.model.counts.review == 1)
        await drill.model.watchPracticeDay()
        #expect(drill.time.sleeps == [.seconds(120)])
        #expect(try drill.model.practiceDay == Fixture.day(Fixture.tomorrow))
        #expect(drill.model.card == shown)
        #expect(drill.model.counts.review == 2)
        drill.time.advance(by: .seconds(120))
        await drill.answer(.good)
        let answer = try #require(await drill.answers.first)
        #expect(try answer.practiceDay == Fixture.day(Fixture.tomorrow))
        #expect(try answer.after.lastDay == Fixture.day(Fixture.tomorrow))
        #expect(answer.kind == .firstOfDay)
        #expect(drill.model.card?.pile == .review)
        #expect(drill.model.counts.review == 1)
    }

    /// §4: if 04:00 passes during a session, the next card is dealt for the new day, even
    /// before the watch or the scene says so.
    @Test
    func `a grade after 04:00 deals the next card for the new day`() async throws {
        let drill = try await Self.beforeFour().started()
        drill.time.advance(by: .seconds(180))
        await drill.answer(.good)
        #expect(try drill.model.practiceDay == Fixture.day(Fixture.tomorrow))
        #expect(try drill.model.card?.card.id == QueueFixture.card(1).id)
        #expect(drill.model.card?.pile == .review)
    }

    /// F5: the done face, re-read after 04:00 when the scene becomes active.
    @Test
    func `scene activation after 04:00 turns the done face into a review`() async throws {
        let due = try QueueFixture.card(1)
        var setup = DrillSetup(cards: [due])
        setup.progress = try [Fixture.progress(due, last: "2026-10-12", due: Fixture.tomorrow)]
        let drill = try await setup.started()
        #expect(drill.model.face == .done)
        #expect(drill.model.nextReviewText?.english == "Next review: Tomorrow")
        drill.model.sceneDidBecomeActive()
        #expect(drill.model.face == .done)
        drill.time.advance(by: .seconds(20 * 3_600))
        drill.model.sceneDidBecomeActive()
        #expect(drill.model.face == .question)
        #expect(drill.model.card?.card.id == due.id)
        #expect(drill.model.counts == HeaderCounts(
            new: 0,
            review: 1,
            reAsk: 0,
            currentPile: .review,
        ))
    }

    @Test
    func `scene activation before the start-up does nothing`() throws {
        let drill = try DrillSetup(cards: Fixture.cards(1, from: 0)).build()
        drill.model.sceneDidBecomeActive()
        #expect(drill.model.practiceDay == nil)
        #expect(drill.model.phase == .starting)
    }

    /// The practice day follows the zone current at the answer (requirements §4).
    @Test
    func `an answer's practice day is read in the zone current at the answer`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(2, from: 0)).started()
        try drill.time.move(to: DomainValuesFixture.zone("America/Los_Angeles"))
        await drill.answer(.good)
        let answer = try #require(await drill.answers.first)
        #expect(try answer.practiceDay == Fixture.day("2026-10-12"))
    }

    /// The watch sleeps to each 04:00 in turn, re-reading the day each time, and ends
    /// when its task is cancelled.
    @Test
    func `the watch sleeps to each 04:00 and stops when cancelled`() async throws {
        var setup = try DrillSetup(cards: Fixture.cards(1, from: 0))
        setup.start = "2026-10-13T09:00:00+09:00"
        let drill = try await setup.started()
        drill.time.allowSleeps(2)
        await drill.model.watchPracticeDay()
        #expect(drill.time.sleeps == [.seconds(19 * 3_600), .seconds(24 * 3_600)])
        #expect(try drill.model.practiceDay == Fixture.day("2026-10-15"))
    }
}
