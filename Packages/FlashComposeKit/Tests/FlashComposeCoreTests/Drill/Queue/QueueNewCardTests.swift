import FlashComposeCore
import Testing

/// New cards: drawn uniformly at random from the candidates the caller passes, by the
/// generator it injects (`docs/product/requirements.md` §3.2).
@Suite("Queue new cards")
struct QueueNewCardTests {
    typealias Fixture = QueueFixture

    static func firstCard(seed: UInt64, candidates: [Card]) throws -> DealtCard? {
        var session = DrillSession()
        var generator = SeededGenerator(seed: seed)
        let input = try QueueInput(
            today: DomainValuesFixture.day(Fixture.today),
            catalog: Fixture.catalog(candidates),
            progress: [:],
            candidates: candidates,
            answeredToday: [],
        )
        return session.deal(for: input, using: &generator)
    }

    @Test(arguments: [0, 1, 42, 9_999] as [UInt64])
    func `the same seed and inputs deal the same new card`(seed: UInt64) throws {
        let candidates = try Fixture.cards(0 ..< 1_800)

        let first = try Self.firstCard(seed: seed, candidates: candidates)
        let second = try Self.firstCard(seed: seed, candidates: candidates)

        #expect(first != nil)
        #expect(first == second)
        #expect(first?.pile == .new)
    }

    @Test
    func `over many seeds every candidate is dealt first, about equally often`() throws {
        let candidates = try Fixture.cards(0 ..< 5)
        let seeds: [UInt64] = Array(0 ..< 1_000)

        let firsts = try seeds
            .compactMap { try Self.firstCard(seed: $0, candidates: candidates)?.card }
        let tally = Dictionary(grouping: firsts, by: \.id).mapValues(\.count)

        #expect(firsts.count == seeds.count)
        #expect(Set(tally.keys) == Set(candidates.map(\.id)))
        // Uniform: each of 5 expects 200 of 1,000; 140...260 is over four standard
        // deviations (sqrt(1000 × 0.2 × 0.8) ≈ 12.6) either side.
        #expect(tally.values.allSatisfy { (140 ... 260).contains($0) })
    }

    @Test
    func `new cards keep coming until every candidate is answered, each once`() throws {
        let candidates = try Fixture.cards(0 ..< 6)
        var driver = try QueueDriver(
            catalog: Fixture.catalog(candidates),
            candidates: candidates,
            progress: [:],
        )
        driver.session = DrillSession(tuning: Tuning(fsrs: .default, reAsk: ReAskTuning(
            afterAgain: 4,
            afterHard: 8,
            afterNewCardsFirstGood: 12,
            maximumPerCard: 0,
        )))

        let dealt = driver.run(limit: 20) { _ in .good }

        #expect(dealt.allSatisfy { $0.pile == .new })
        #expect(Set(dealt.map(\.card.id)) == Set(candidates.map(\.id)))
        #expect(dealt.count == candidates.count)
    }

    /// A scope change mid-session: the next new card comes from the new list, and a
    /// waiting re-ask stays.
    @Test
    func `a new candidate list steers the next new card and keeps waiting re-asks`() throws {
        let before = try Fixture.cards(0 ..< 3)
        let after = try Fixture.cards(10 ..< 13)
        var driver = try QueueDriver(
            catalog: Fixture.catalog(before + after),
            candidates: before,
            progress: [:],
        )
        let firstDealt = driver.deal()
        let missed = try #require(firstDealt)
        driver.grade(.again)
        #expect(driver.counts.reAsk == 1)

        driver.candidates = after
        let nextDealt = driver.deal()
        let next = try #require(nextDealt)

        #expect(before.contains(missed.card))
        #expect(next.pile == .new)
        #expect(after.contains(next.card))
        #expect(driver.counts.reAsk == 1)
    }
}
