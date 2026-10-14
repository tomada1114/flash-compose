/// SplitMix64: the seeded generator the queue suites hand the session, so a draw is
/// repeatable. The standard library ships none (`designing-core-logic` › Inject
/// randomness).
struct SeededGenerator: RandomNumberGenerator {
    /// SplitMix64's published increment and mixing constants and shifts.
    private enum SplitMix {
        static let increment: UInt64 = 0x9E37_79B9_7F4A_7C15
        static let firstMultiplier: UInt64 = 0xBF58_476D_1CE4_E5B9
        static let secondMultiplier: UInt64 = 0x94D0_49BB_1331_11EB
        static let firstShift: UInt64 = 30
        static let secondShift: UInt64 = 27
        static let finalShift: UInt64 = 31
    }

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= SplitMix.increment
        var mixed = state
        mixed = (mixed ^ (mixed >> SplitMix.firstShift)) &* SplitMix.firstMultiplier
        mixed = (mixed ^ (mixed >> SplitMix.secondShift)) &* SplitMix.secondMultiplier
        return mixed ^ (mixed >> SplitMix.finalShift)
    }
}
