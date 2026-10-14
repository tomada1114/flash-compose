import FlashComposeCore
import Testing

/// The scheduler's promises to the drill: a new card's first grade, lapses, the next
/// state's reps and days, the fuzz seeded by the card, and retrievability.
///
/// Expected values are worked out by hand from the formulas or, where the fuzz decides
/// them, were computed by the old app's TypeScript port (`instant-composition@6fcefb2`,
/// `packages/domain/src/fsrs.ts`) for these card ids — never by this scheduler.
@Suite("FSRS-6 scheduler")
struct FSRSSchedulerTests {
    typealias Day = DomainValuesFixture

    let scheduler = FSRSScheduler()

    /// Example 3's review: stability 13.8 after two good answers, last answered on
    /// 2026-10-04 and due 2026-10-18.
    static func review(lastDay: String, dueDay: String) throws -> FSRSState {
        try FSRSState(
            stability: 13.8,
            difficulty: 2.11121424,
            reps: 2,
            lapses: 0,
            lastDay: Day.day(lastDay),
            dueDay: Day.day(dueDay),
        )
    }

    @Test
    func `a new card's first grades start at w0, w1, and w2 with one, two, and three days`() throws {
        let preview = try scheduler.preview(
            nil,
            on: Day.day("2026-10-01"),
            card: CardID("c_7k2m9x4q"),
        )
        #expect(preview.again.state.stability == 0.212)
        #expect(preview.again.state.difficulty == 6.4133)
        #expect(preview.hard.state.stability == 1.2931)
        #expect(preview.hard.state.difficulty == 5.11217071)
        #expect(preview.good.state.stability == 2.3065)
        #expect(preview.good.state.difficulty == 2.11810397)
        #expect([preview.again, preview.hard, preview.good].map(\.intervalDays) == [1, 2, 3])
    }

    @Test(arguments: [Grade.again, .hard, .good])
    func `a new card's first grade gives one rep, no lapse, and today as its last day`(
        grade: Grade,
    ) throws {
        let today = try Day.day("2026-10-01")
        let outcome = try scheduler.schedule(
            nil,
            grade: grade,
            on: today,
            card: CardID("c_7k2m9x4q"),
        )
        #expect(outcome.state.reps == 1)
        #expect(outcome.state.lapses == 0)
        #expect(outcome.state.lastDay == today)
        #expect(outcome.state.dueDay == today.adding(days: outcome.intervalDays))
    }

    @Test
    func `a review graded again counts a lapse and adds a rep`() throws {
        let review = try Self.review(lastDay: "2026-10-04", dueDay: "2026-10-18")
        let today = try Day.day("2026-10-18")
        let lapsed = try scheduler.schedule(
            review,
            grade: .again,
            on: today,
            card: CardID("c_7k2m9x4q"),
        )
        let expected = try FSRSState(
            stability: 1.72512159,
            difficulty: 7.39223814,
            reps: 3,
            lapses: 1,
            lastDay: today,
            dueDay: Day.day("2026-10-20"),
        )
        #expect(lapsed == GradeOutcome(state: expected, intervalDays: 2))
    }

    @Test(arguments: [Grade.hard, .good])
    func `a review graded hard or good keeps its lapses`(grade: Grade) throws {
        let review = try Self.review(lastDay: "2026-10-04", dueDay: "2026-10-18")
        let outcome = try scheduler.schedule(
            review,
            grade: grade,
            on: Day.day("2026-10-18"),
            card: CardID("c_7k2m9x4q"),
        )
        #expect(outcome.state.lapses == 0)
        #expect(outcome.state.reps == 3)
    }

    @Test
    func `a day before the last answer is scheduled as that same day`() throws {
        // Example 3 of the issue: the clock moved back two days.
        let review = try Self.review(lastDay: "2026-10-10", dueDay: "2026-10-24")
        let card = try CardID("c_7k2m9x4q")
        let today = try Day.day("2026-10-08")
        let preview = scheduler.preview(review, on: today, card: card)
        #expect(preview.again.state.stability == 1.46057929)
        #expect(preview.hard.state.stability == 13.8)
        #expect(preview.good.state.stability == 13.8)
        #expect([preview.again, preview.hard, preview.good].map(\.intervalDays) == [1, 14, 15])
        #expect(try preview.good.state.dueDay == Day.day("2026-10-23"))
        #expect(preview.good.state.lastDay == today)
    }

    @Test
    func `schedule gives the outcome the preview shows for each grade`() throws {
        let review = try Self.review(lastDay: "2026-10-04", dueDay: "2026-10-18")
        let card = try CardID("c_7k2m9x4q")
        let today = try Day.day("2026-10-20")
        let preview = scheduler.preview(review, on: today, card: card)
        #expect(scheduler.schedule(review, grade: .again, on: today, card: card) == preview.again)
        #expect(scheduler.schedule(review, grade: .hard, on: today, card: card) == preview.hard)
        #expect(scheduler.schedule(review, grade: .good, on: today, card: card) == preview.good)
    }

    @Test
    func `the same card, state, and day always give the same outcome`() throws {
        let review = try Self.review(lastDay: "2026-10-04", dueDay: "2026-10-18")
        let card = try CardID("c_3y4z5a6b")
        let today = try Day.day("2026-10-18")
        #expect(scheduler.preview(review, on: today, card: card) == scheduler.preview(
            review,
            on: today,
            card: card,
        ))
    }

    @Test
    func `ten cards graded good twice spread over the days their ids seed`() throws {
        let ids = [
            "c_2a3b4c5d", "c_3b4c5d6e", "c_4c5d6e7f", "c_5d6e7f8g", "c_6e7f8g9h",
            "c_7k2m9x4q", "c_8m9n2p3q", "c_9r2s3t4u", "c_2v3w4x5y", "c_3y4z5a6b",
        ]
        let first = try Day.day("2026-10-01")
        let second = try Day.day("2026-10-04")
        let intervals = try ids.map { id in
            let card = try CardID(id)
            let state = scheduler.schedule(nil, grade: .good, on: first, card: card).state
            return scheduler.schedule(state, grade: .good, on: second, card: card).intervalDays
        }
        #expect(intervals == [14, 15, 15, 15, 14, 13, 14, 13, 13, 16])
    }

    @Test
    func `retrievability is 1 on the day of the last answer`() throws {
        let review = try Self.review(lastDay: "2026-10-04", dueDay: "2026-10-18")
        #expect(try scheduler.retrievability(of: review, on: Day.day("2026-10-04")) == 1)
    }

    @Test
    func `retrievability is 0_9 when the days since the last answer equal the stability`() throws {
        let state = try FSRSState(
            stability: 10,
            difficulty: DomainValuesFixture.difficulty,
            reps: 1,
            lapses: 0,
            lastDay: Day.day("2026-10-01"),
            dueDay: Day.day("2026-10-11"),
        )
        #expect(try scheduler.retrievability(of: state, on: Day.day("2026-10-11")) == 0.9)
    }

    @Test
    func `retrievability reads a day before the last answer as no wait at all`() throws {
        let review = try Self.review(lastDay: "2026-10-05", dueDay: "2026-10-18")
        #expect(try scheduler.retrievability(of: review, on: Day.day("2026-10-01")) == 1)
    }
}
