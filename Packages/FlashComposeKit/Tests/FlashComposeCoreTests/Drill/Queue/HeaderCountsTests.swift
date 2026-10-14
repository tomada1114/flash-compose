import FlashComposeCore
import Testing

/// The drill header's 新規 / 復習 / もう一度 counts and the pile the card on screen counts
/// in, derived from the same inputs the queue deals from (`docs/product/ux-flows.md` §2).
@Suite("Header counts")
struct HeaderCountsTests {
    typealias Fixture = QueueFixture

    /// The wireframe's state: 1,820 never-seen cards in scope and 12 reviews due — from
    /// topics the scope leaves out — with cards around them that count in neither pile.
    static func wireframeDriver() throws -> QueueDriver {
        let neverSeen = try Fixture.cards(0 ..< 1_820)
        let reviews = try (2_000 ..< 2_012).map { index in
            try Fixture.card(index, topic: ScopeFixture.travel, level: 10)
        }
        let outsideScope = try (2_100 ..< 2_110).map { index in
            try Fixture.card(index, topic: ScopeFixture.travel, level: 1)
        }
        let notDue = try Fixture.card(2_200)
        let answered = try Fixture.card(2_201)
        let seenCandidate = try Fixture.card(2_202)
        var progress = try Fixture.dueToday(reviews + [answered])
        progress[notDue.id] = try Fixture.progress(notDue, last: "2026-10-12", due: "2026-10-20")
        progress[seenCandidate.id] = try Fixture.progress(
            seenCandidate,
            last: "2026-10-12",
            due: "2026-10-20",
        )
        let dropped = try Fixture.card(2_300)
        progress[dropped.id] = try Fixture.progress(dropped, last: "2026-10-01", due: "2026-10-02")
        var driver = try QueueDriver(
            catalog: Fixture.catalog(
                neverSeen + reviews + outsideScope + [notDue, answered, seenCandidate],
            ),
            candidates: neverSeen + [seenCandidate],
            progress: progress,
        )
        driver.answeredToday = [answered.id]
        return driver
    }

    @Test
    func `with 1,820 never-seen and 12 due and nothing waiting, it reads 1820 › 12 › 0`() throws {
        let driver = try Self.wireframeDriver()

        #expect(driver.counts == HeaderCounts(new: 1_820, review: 12, reAsk: 0, currentPile: nil))
    }

    @Test
    func `a review on screen counts in 復習 until a grade moves it on`() throws {
        var driver = try Self.wireframeDriver()

        let shownDealt = driver.deal()

        let shown = try #require(shownDealt)
        let onScreen = driver.counts
        driver.grade(.again)

        #expect(shown.pile == .review)
        #expect(onScreen == HeaderCounts(new: 1_820, review: 12, reAsk: 0, currentPile: .review))
        #expect(driver.counts == HeaderCounts(new: 1_820, review: 11, reAsk: 1, currentPile: nil))
    }

    @Test
    func `a new card on screen counts in 新規 until its first ○ moves it to もう一度`() throws {
        let fresh = try Fixture.cards(0 ..< 3)
        var driver = try QueueDriver(
            catalog: Fixture.catalog(fresh),
            candidates: fresh,
            progress: [:],
        )

        _ = driver.deal()
        let onScreen = driver.counts
        driver.grade(.good)

        #expect(onScreen == HeaderCounts(new: 3, review: 0, reAsk: 0, currentPile: .new))
        #expect(driver.counts == HeaderCounts(new: 2, review: 0, reAsk: 1, currentPile: nil))
    }

    @Test(arguments: [
        (Grade.good, 0),
        (Grade.hard, 1),
        (Grade.again, 1),
    ])
    func `a re-ask on screen counts in もう一度 until a grade lets it go`(
        grade: Grade,
        waitingAfter: Int,
    ) throws {
        let missed = try Fixture.card(0)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([missed]),
            candidates: [],
            progress: Fixture.dueToday([missed]),
        )
        _ = driver.deal()
        driver.grade(.again)

        let reAsk = driver.deal()
        let onScreen = driver.counts
        driver.grade(grade)

        #expect(reAsk == DealtCard(card: missed, pile: .reAsk))
        #expect(onScreen == HeaderCounts(new: 0, review: 0, reAsk: 1, currentPile: .reAsk))
        #expect(driver.counts == HeaderCounts(
            new: 0,
            review: 0,
            reAsk: waitingAfter,
            currentPile: nil,
        ))
    }

    @Test
    func `a narrower candidate list recounts 新規 and leaves 復習 and もう一度 alone`() throws {
        var driver = try Self.wireframeDriver()
        _ = driver.deal()
        driver.grade(.again)

        driver.candidates = Array(driver.candidates.prefix(33))

        #expect(driver.counts == HeaderCounts(new: 33, review: 11, reAsk: 1, currentPile: nil))
    }
}
