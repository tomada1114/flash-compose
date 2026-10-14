import FlashComposeCore
import Testing

/// Re-asks: a card coming back within the session after 4 (×), 8 (△), or 12 (a new
/// card's first ○) other cards, at most 10 times, and — once no first-time card is left —
/// straight away, in the order they fell due, never the card just shown while another
/// waits (`docs/product/requirements.md` §3.2, `docs/product/ux-flows.md` F2).
@Suite("Re-asks")
struct ReAskTests {
    typealias Fixture = QueueFixture

    static func tuning(afterAgain: Int, afterHard: Int, maximumPerCard: Int) -> Tuning {
        Tuning(fsrs: .default, reAsk: ReAskTuning(
            afterAgain: afterAgain,
            afterHard: afterHard,
            afterNewCardsFirstGood: 12,
            maximumPerCard: maximumPerCard,
        ))
    }

    /// Reviews of `cards`, each less likely remembered than the next: the first was last
    /// answered longest ago, so they are dealt in the order given.
    static func reviewsInOrder(_ cards: [Card]) throws -> [CardID: CardProgress] {
        try Fixture.byID(cards.enumerated().map { offset, card in
            try Fixture.progress(card, last: "2026-10-0\(offset + 1)", due: Fixture.today)
        })
    }

    /// The zero-based positions `card` was dealt at, with the pile of each.
    static func appearances(of card: Card, in dealt: [DealtCard]) -> [Int: DrillPile] {
        Dictionary(uniqueKeysWithValues: dealt.enumerated().compactMap { offset, next in
            next.card == card ? (offset, next.pile) : nil
        })
    }

    @Test
    func `the shipped gaps are 4, 8, and 12 cards, at most 10 re-asks per card`() {
        #expect(Tuning.default.reAsk == ReAskTuning(
            afterAgain: 4,
            afterHard: 8,
            afterNewCardsFirstGood: 12,
            maximumPerCard: 10,
        ))
    }

    /// Example 2: × on the 1st card returns as the 6th, △ on the 2nd as the 11th, and a
    /// new card's first ○ on the 3rd as the 16th; ○ on a review's re-ask ends it.
    @Test
    func `after ×, 4 other cards; after △, 8; after a new card's first ○, 12`() throws {
        let missed = try Fixture.card(0)
        let unsure = try Fixture.card(1)
        let fresh = try Fixture.cards(10 ..< 50)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([missed, unsure] + fresh),
            candidates: fresh,
            progress: Self.reviewsInOrder([missed, unsure]),
        )
        var gradesGiven = 0
        let dealt = driver.run(limit: 25) { _ in
            gradesGiven += 1
            return [.again, .hard][safe: gradesGiven - 1] ?? .good
        }
        let newGood = dealt[2].card

        #expect(dealt.count == 25)
        #expect(Self.appearances(of: missed, in: dealt) == [0: .review, 5: .reAsk])
        #expect(Self.appearances(of: unsure, in: dealt) == [1: .review, 10: .reAsk])
        #expect(Self.appearances(of: newGood, in: dealt) == [2: .new, 15: .reAsk])
    }

    @Test
    func `the header counts each re-ask while it waits`() throws {
        let missed = try Fixture.card(0)
        let unsure = try Fixture.card(1)
        let fresh = try Fixture.cards(10 ..< 20)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([missed, unsure] + fresh),
            candidates: fresh,
            progress: Self.reviewsInOrder([missed, unsure]),
        )
        let grades: [Grade] = [.again, .hard, .good]
        var waiting: [Int] = []

        for grade in grades {
            _ = driver.deal()
            driver.grade(grade)
            waiting.append(driver.counts.reAsk)
        }

        #expect(waiting == [1, 2, 3])
    }

    /// The old app's rule: a card dealt new gets one more re-ask after its first ○, even
    /// when that ○ comes on a re-ask after a ×.
    @Test
    func `a new card's first ○ on a re-ask after × still brings it back once more`() throws {
        let fresh = try Fixture.cards(0 ..< 40)
        var driver = try QueueDriver(
            catalog: Fixture.catalog(fresh),
            candidates: fresh,
            progress: [:],
        )
        let firstDealt = driver.deal()
        let missed = try #require(firstDealt)
        driver.grade(.again)

        let dealt = [missed] + driver.run(limit: 29) { _ in .good }

        #expect(Self.appearances(of: missed.card, in: dealt) == [
            0: .new,
            5: .reAsk,
            18: .reAsk,
        ])
    }

    /// A card alone and always missed: one review, then 10 re-asks — each dealt again at
    /// once because no other card waits — and no 11th.
    @Test
    func `the 11th re-ask of a card is refused`() throws {
        let missed = try Fixture.card(0)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([missed]),
            candidates: [],
            progress: Fixture.dueToday([missed]),
        )

        let dealt = driver.run(limit: 50) { _ in .again }

        #expect(dealt.count == 11)
        #expect(dealt.first == DealtCard(card: missed, pile: .review))
        #expect(dealt.dropFirst().allSatisfy { $0 == DealtCard(card: missed, pile: .reAsk) })
        #expect(driver.counts == HeaderCounts(new: 0, review: 0, reAsk: 0, currentPile: nil))
    }

    @Test(arguments: [0, 1, 3])
    func `the cap comes from Tuning`(maximumPerCard: Int) throws {
        let missed = try Fixture.card(0)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([missed]),
            candidates: [],
            progress: Fixture.dueToday([missed]),
        )
        driver.session = DrillSession(
            tuning: Self.tuning(afterAgain: 4, afterHard: 8, maximumPerCard: maximumPerCard),
        )

        let dealt = driver.run(limit: 50) { _ in .hard }

        #expect(dealt.count == 1 + maximumPerCard)
    }

    /// Example 3: with no first-time card left, the card just shown waits even though its
    /// re-ask fell due first, and comes right after the other one.
    @Test
    func `with nothing new left, the card just shown is skipped while another waits`() throws {
        let unsure = try Fixture.card(0)
        let missed = try Fixture.card(1)
        var driver = try QueueDriver(
            catalog: Fixture.catalog([unsure, missed]),
            candidates: [],
            progress: Self.reviewsInOrder([unsure, missed]),
        )
        var gradesGiven = 0

        let dealt = driver.run(limit: 10) { _ in
            gradesGiven += 1
            return [.hard, .again][safe: gradesGiven - 1] ?? .good
        }

        #expect(dealt == [
            DealtCard(card: unsure, pile: .review),
            DealtCard(card: missed, pile: .review),
            DealtCard(card: unsure, pile: .reAsk),
            DealtCard(card: missed, pile: .reAsk),
        ])
    }

    /// Due steps 10 (△ on the 1st), 7 (× on the 2nd), and 8 (× on the 3rd): once nothing
    /// else is left they come at once — 7, then 8, then 10.
    @Test
    func `with nothing new left, waiting re-asks come in the order they fell due`() throws {
        let cards = try Fixture.cards(0 ..< 3)
        var driver = try QueueDriver(
            catalog: Fixture.catalog(cards),
            candidates: [],
            progress: Self.reviewsInOrder(cards),
        )
        var gradesGiven = 0

        let dealt = driver.run(limit: 10) { _ in
            gradesGiven += 1
            return [.hard, .again, .again][safe: gradesGiven - 1] ?? .good
        }

        #expect(dealt.map(\.card) == [cards[0], cards[1], cards[2], cards[1], cards[2], cards[0]])
        #expect(dealt.suffix(3).allSatisfy { $0.pile == .reAsk })
    }

    /// With gaps of 2 (×) and 1 (△), × on the 1st card and △ on the 2nd both fall due at
    /// the 4th card: the one set first comes first.
    @Test
    func `re-asks falling due together come in the order they were set`() throws {
        let cards = try Fixture.cards(0 ..< 3)
        var driver = try QueueDriver(
            catalog: Fixture.catalog(cards),
            candidates: [],
            progress: Self.reviewsInOrder(cards),
        )
        driver.session = DrillSession(
            tuning: Self.tuning(afterAgain: 2, afterHard: 1, maximumPerCard: 10),
        )
        var gradesGiven = 0

        let dealt = driver.run(limit: 10) { _ in
            gradesGiven += 1
            return [.again, .hard][safe: gradesGiven - 1] ?? .good
        }

        #expect(dealt.map(\.card) == [cards[0], cards[1], cards[2], cards[0], cards[1]])
    }

    @Test
    func `a fresh session, as after a relaunch, has no waiting re-asks`() throws {
        let fresh = try Fixture.cards(0 ..< 3)
        let driver = try QueueDriver(
            catalog: Fixture.catalog(fresh),
            candidates: fresh,
            progress: [:],
        )

        #expect(driver.counts == HeaderCounts(new: 3, review: 0, reAsk: 0, currentPile: nil))
    }
}

extension Array {
    /// The element at `index`, or `nil` past either end.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
