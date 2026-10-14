import FlashComposeCore
import Testing

/// What comes next: due reviews before new cards, the least likely remembered first, a
/// card answered today never again except as a re-ask, and nothing at the end of the day
/// (`docs/product/requirements.md` §3.2, §3.3, §3.5).
@Suite("Queue order")
struct QueueOrderTests {
    typealias Fixture = QueueFixture

    /// Example 1: two due reviews from topics and levels the scope leaves out — the one
    /// last answered longer ago (lower retrievability) first — then a new card.
    @Test
    func `due reviews come first, least likely remembered first, then a new card`() throws {
        let older = try Fixture.card(0, topic: ScopeFixture.travel, level: 9)
        let newer = try Fixture.card(1, topic: ScopeFixture.tech, level: 2)
        let fresh = try Fixture.cards(10 ..< 30)
        let progress = try Fixture.byID([
            Fixture.progress(newer, last: "2026-10-11", due: Fixture.today),
            Fixture.progress(older, last: "2026-10-01", due: "2026-10-13"),
        ])
        let today = try DomainValuesFixture.day(Fixture.today)
        let scheduler = FSRSScheduler()
        let olderState = try #require(progress[older.id]?.state)
        let newerState = try #require(progress[newer.id]?.state)
        #expect(
            scheduler.retrievability(of: olderState, on: today)
                < scheduler.retrievability(of: newerState, on: today),
        )
        var driver = try QueueDriver(
            catalog: Fixture.catalog([newer, older] + fresh),
            candidates: fresh,
            progress: progress,
        )

        let dealt = driver.run(limit: 3) { _ in .good }

        #expect(dealt.prefix(2) == [
            DealtCard(card: older, pile: .review),
            DealtCard(card: newer, pile: .review),
        ])
        let third = try #require(dealt.last)
        #expect(third.pile == .new)
        #expect(fresh.contains(third.card))
    }

    @Test
    func `equal retrievability falls back to card id order, not catalog order`() throws {
        let lower = try Fixture.card(3)
        let higher = try Fixture.card(4)
        #expect(lower.id.rawValue < higher.id.rawValue)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([higher, lower]),
            candidates: [],
            progress: Fixture.dueToday([higher, lower]),
        )

        let dealt = driver.run(limit: 5) { _ in .good }

        #expect(dealt.map(\.card) == [lower, higher])
    }

    @Test
    func `a card due tomorrow, or under an id the catalog lacks, is never dealt`() throws {
        let notDue = try Fixture.card(0)
        let dropped = try Fixture.card(1)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([notDue]),
            candidates: [notDue],
            progress: Fixture.byID([
                Fixture.progress(notDue, last: Fixture.today, due: Fixture.tomorrow),
                Fixture.progress(dropped, last: "2026-10-01", due: "2026-10-02"),
            ]),
        )

        #expect(driver.deal() == nil)
        #expect(driver.counts == HeaderCounts(new: 0, review: 0, reAsk: 0, currentPile: nil))
    }

    @Test
    func `a card answered today is dealt neither as a review nor as a new card`() throws {
        let review = try Fixture.card(0)
        let fresh = try Fixture.card(1)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([review, fresh]),
            candidates: [review, fresh],
            progress: Fixture.dueToday([review]),
        )
        driver.answeredToday = [review.id, fresh.id]

        #expect(driver.deal() == nil)
    }

    @Test
    func `a candidate that has progress is not new, and comes only when it is due`() throws {
        let seen = try Fixture.card(0)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([seen]),
            candidates: [seen],
            progress: Fixture.byID([Fixture.progress(seen, last: "2026-10-12", due: "2026-10-16")]),
        )

        #expect(driver.deal() == nil)
    }

    @Test
    func `with no candidates, due reviews are still dealt`() throws {
        let review = try Fixture.card(0)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([review]),
            candidates: [],
            progress: Fixture.dueToday([review]),
        )

        #expect(driver.deal() == DealtCard(card: review, pile: .review))
    }

    /// Example 5: nothing due, no candidates, no re-asks.
    @Test
    func `nothing left deals no card and counts zero in every pile`() throws {
        var driver = try QueueDriver(
            catalog: Fixture.catalog([]),
            candidates: [],
            progress: [:],
        )
        let before = driver.session

        #expect(driver.deal() == nil)
        #expect(driver.session == before)
        #expect(driver.counts == HeaderCounts(new: 0, review: 0, reAsk: 0, currentPile: nil))
    }

    @Test
    func `the card on screen stays until it is graded, whatever the inputs say`() throws {
        let first = try Fixture.card(0)
        let second = try Fixture.card(1)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([first, second]),
            candidates: [],
            progress: Fixture.byID([
                Fixture.progress(first, stability: 1, last: "2026-10-01", due: "2026-10-02"),
                Fixture.progress(second, stability: 9, last: "2026-10-13", due: Fixture.today),
            ]),
        )
        let shown = driver.deal()
        driver.progress[first.id] = nil

        #expect(shown == DealtCard(card: first, pile: .review))
        #expect(driver.deal() == shown)
        #expect(driver.session.current == shown)
    }

    @Test
    func `a grade with no card on screen changes nothing`() {
        var session = DrillSession()
        let before = session

        session.record(.again)

        #expect(session == before)
    }
}
