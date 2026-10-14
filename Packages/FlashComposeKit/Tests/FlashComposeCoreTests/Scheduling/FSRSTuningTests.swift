import FlashComposeCore
import Testing

/// The scheduler's parameters: the shipped values (requirements §3.3), and proof the
/// scheduler reads each tunable rather than a copy of it.
@Suite("FSRS-6 tuning")
struct FSRSTuningTests {
    typealias Day = DomainValuesFixture

    /// ts-fsrs 5.4.2's `default_w`, as the issue and the old app's `tuning.ts` list them.
    static let tsFSRSDefaultWeights: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666,
        0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658,
        0.1542,
    ]

    static func tuning(
        maximumIntervalDays: Int,
        shortestIntervalDays: Int,
        fuzz: FSRSFuzz,
    ) -> FSRSTuning {
        FSRSTuning(
            weights: .default,
            desiredRetention: 0.9,
            maximumIntervalDays: maximumIntervalDays,
            shortestIntervalDays: shortestIntervalDays,
            fuzz: fuzz,
        )
    }

    /// A card graded good on 2026-10-01 and again on its due day, 2026-10-04.
    static func goodTwice(_ scheduler: FSRSScheduler, card: String) throws -> GradePreview {
        let id = try CardID(card)
        let first = try scheduler.schedule(nil, grade: .good, on: Day.day("2026-10-01"), card: id)
        return try scheduler.preview(first.state, on: Day.day("2026-10-04"), card: id)
    }

    @Test
    func `the default holds ts-fsrs's 21 weights, retention 0.9, and 1 to 365 days`() {
        let fsrs = Tuning.default.fsrs
        #expect(fsrs.weights.values.indices.map { fsrs.weights.values[$0] } == Self
            .tsFSRSDefaultWeights)
        #expect(fsrs.desiredRetention == 0.9)
        #expect(fsrs.maximumIntervalDays == 365)
        #expect(fsrs.shortestIntervalDays == 1)
    }

    @Test
    func `the default fuzz leaves under 2_5 days alone and moves 15, 10, and 5 percent`() {
        let fuzz = Tuning.default.fsrs.fuzz
        #expect(fuzz.thresholdDays == 2.5)
        #expect(fuzz.floorDays == 2)
        #expect(fuzz.ranges == [
            FSRSFuzzRange(start: 2.5, end: 7, factor: 0.15),
            FSRSFuzzRange(start: 7, end: 20, factor: 0.1),
            FSRSFuzzRange(start: 20, end: .infinity, factor: 0.05),
        ])
    }

    @Test
    func `weights are made from exactly 21 values`() throws {
        var changed = Self.tsFSRSDefaultWeights
        changed[20] = 0.5
        #expect(try FSRSWeights(Self.tsFSRSDefaultWeights) == .default)
        #expect(try FSRSWeights(changed) != .default)
        #expect(
            Tuning.default
                == Tuning(
                    fsrs: Self.tuning(
                        maximumIntervalDays: 365,
                        shortestIntervalDays: 1,
                        fuzz: .default,
                    ),
                    reAsk: .default,
                ),
        )
    }

    @Test(arguments: [0, 20, 22])
    func `weights of any other count are rejected with the count given`(count: Int) {
        let values = Array(Self.tsFSRSDefaultWeights.prefix(count))
            + Array(repeating: 0.1, count: max(0, count - Self.tsFSRSDefaultWeights.count))
        #expect(throws: FSRSWeightsError.wrongCount(count)) {
            try FSRSWeights(values)
        }
    }

    /// The cap applies to each grade's own interval; spreading the grades a day apart
    /// afterwards can still put good one day past it, as ts-fsrs does — the golden
    /// vectors hold a 366-day good (cap-2 on 2030-10-19). Expected values from the old
    /// app's port run with a 10-day cap.
    @Test(arguments: [
        ("c_2a3b4c5d", [1, 9, 10]),
        ("c_3y4z5a6b", [1, 10, 11]),
        ("c_7k2m9x4q", [1, 8, 9]),
    ])
    func `the longest interval caps each grade before the grades are spread apart`(
        card: String,
        expected: [Int],
    ) throws {
        let scheduler = FSRSScheduler(tuning: Self.tuning(
            maximumIntervalDays: 10,
            shortestIntervalDays: 1,
            fuzz: .default,
        ))
        let preview = try Self.goodTwice(scheduler, card: card)
        #expect([preview.again, preview.hard, preview.good].map(\.intervalDays) == expected)
    }

    @Test
    func `the shortest interval floors a new card's grades`() throws {
        let scheduler = FSRSScheduler(tuning: Self.tuning(
            maximumIntervalDays: 365,
            shortestIntervalDays: 2,
            fuzz: .default,
        ))
        let preview = try scheduler.preview(
            nil,
            on: Day.day("2026-10-01"),
            card: CardID("c_7k2m9x4q"),
        )
        // Each stability rounds below 2, so each grade starts at 2, then rises by a day.
        #expect([preview.again, preview.hard, preview.good].map(\.intervalDays) == [2, 3, 4])
    }

    @Test
    func `without fuzz every card gets the stability rounded to days`() throws {
        let noFuzz = FSRSFuzz(thresholdDays: .infinity, floorDays: 2, ranges: [])
        let scheduler = FSRSScheduler(tuning: Self.tuning(
            maximumIntervalDays: 365,
            shortestIntervalDays: 1,
            fuzz: noFuzz,
        ))
        for card in ["c_2a3b4c5d", "c_3y4z5a6b", "c_7k2m9x4q"] {
            // Stability 13.82690327 (golden card-1's second good) at retention 0.9.
            #expect(try Self.goodTwice(scheduler, card: card).good.intervalDays == 14, "\(card)")
        }
    }
}
