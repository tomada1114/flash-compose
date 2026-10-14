import FlashComposeCore
import Testing

/// 04:00 passing: the same inputs with the new practice day recompute what is due, with
/// no clock read by the queue (`docs/product/requirements.md` §3.3, §4;
/// `docs/product/ux-flows.md` F7).
@Suite("Queue rollover")
struct QueueRolloverTests {
    typealias Fixture = QueueFixture
    typealias Day = DomainValuesFixture

    static func practiceDay(at instant: String) throws -> PracticeDay {
        try PracticeDay(instant: Day.instant(instant), timeZone: Day.zone("Asia/Tokyo"))
    }

    /// Example 4: answered at 03:50 on 2026-10-14 (practice day 2026-10-13) and due
    /// 2026-10-14, the card is dealt as a review once the queue is rebuilt at 04:05.
    @Test
    func `a card answered at 03_50 is a due review after 04_00`() throws {
        let card = try Fixture.card(0)
        let before = try Self.practiceDay(at: "2026-10-14T03:50:00+09:00")
        let after = try Self.practiceDay(at: "2026-10-14T04:05:00+09:00")
        #expect(try before == (Day.day("2026-10-13")))
        #expect(try after == (Day.day("2026-10-14")))
        var driver = try QueueDriver(
            catalog: Fixture.catalog([card]),
            candidates: [],
            progress: Fixture.byID([Fixture.progress(card, last: "2026-10-13", due: "2026-10-14")]),
        )
        driver.today = before
        driver.answeredToday = [card.id]
        #expect(driver.counts.review == 0)
        #expect(driver.deal() == nil)

        driver.today = after
        driver.answeredToday = []

        #expect(driver.counts.review == 1)
        #expect(driver.deal() == DealtCard(card: card, pile: .review))
        #expect(driver.counts == HeaderCounts(new: 0, review: 1, reAsk: 0, currentPile: .review))
    }

    @Test
    func `the card on screen at 04_00 keeps its pile`() throws {
        let card = try Fixture.card(0)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([card]),
            candidates: [],
            progress: Fixture.byID([Fixture.progress(card, last: "2026-10-10", due: "2026-10-13")]),
        )
        driver.today = try Day.day("2026-10-13")
        let shown = driver.deal()

        driver.today = try Day.day("2026-10-14")

        #expect(shown == DealtCard(card: card, pile: .review))
        #expect(driver.deal() == shown)
    }

    /// A card missed before 04:00 is due on the new day and also waiting as a re-ask: it
    /// comes back first as the re-ask, which moves nothing, and only then as the day's
    /// review — never twice in the queue at once.
    @Test
    func `a re-ask waiting across 04_00 comes as a re-ask, then the card as a review`() throws {
        let missed = try Fixture.card(0)
        let other = try Fixture.card(1)
        let fresh = try Fixture.cards(10 ..< 20)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([missed, other] + fresh),
            candidates: fresh,
            progress: Fixture.byID([
                Fixture.progress(missed, last: "2026-10-01", due: "2026-10-13"),
                Fixture.progress(other, last: "2026-10-05", due: "2026-10-13"),
            ]),
        )
        driver.today = try Day.day("2026-10-13")
        let first = driver.deal()
        driver.grade(.again)
        driver.today = try Day.day("2026-10-14")
        driver.answeredToday = []
        #expect(driver.counts.review == 2)
        #expect(driver.counts.reAsk == 1)

        let rest = driver.run(limit: 6) { _ in .good }

        #expect(first == DealtCard(card: missed, pile: .review))
        #expect(rest.map(\.pile) == [.review, .new, .new, .new, .reAsk, .review])
        #expect(rest[0].card == other)
        #expect(rest[4].card == missed)
        #expect(rest[5].card == missed)
    }
}
