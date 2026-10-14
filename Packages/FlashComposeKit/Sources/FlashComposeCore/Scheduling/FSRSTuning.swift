// The FSRS-6 scheduler's parameters: ts-fsrs 5.4.2's default weights (src/constant.ts,
// default_w) and its fuzz ranges (src/help.ts, FUZZ_RANGES), as the old app's port of it
// (tomada1114/instant-composition, packages/domain/src/tuning.ts and fsrs-interval.ts)
// held them. ts-fsrs's notice follows.
//
// MIT License
//
// Copyright (c) 2026 Open Spaced Repetition
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/// Why an ``FSRSWeights`` could not be made.
public enum FSRSWeightsError: Error, Equatable, Sendable {
    /// FSRS-6 reads exactly ``FSRSWeights/count`` weights; this many were given.
    case wrongCount(Int)
}

/// FSRS-6's 21 model weights, `w0` through `w20`.
///
/// Exactly ``count`` of them, checked where they are made, so a tuning with a weight
/// missing is rejected there rather than trapping on the first review that reads it.
public struct FSRSWeights: Sendable, Equatable {
    /// ts-fsrs 5.4.2's default for each weight, named for the part of FSRS-6 that reads it.
    private enum Default {
        static let initialStabilityAgain = 0.212
        static let initialStabilityHard = 1.2931
        static let initialStabilityGood = 2.3065
        static let initialStabilityEasy = 8.2956
        static let initialDifficulty = 6.4133
        static let initialDifficultyExponent = 0.8334
        static let difficultyStep = 3.0194
        static let meanReversion = 0.001
        static let recallGrowth = 1.8722
        static let recallStabilityDecay = 0.1666
        static let recallRetrievabilityGain = 0.796
        static let forgetScale = 1.4835
        static let forgetDifficultyExponent = 0.0614
        static let forgetStabilityExponent = 0.2629
        static let forgetRetrievabilityGain = 1.6483
        static let hardPenalty = 0.6014
        static let easyBonus = 1.8729
        static let shortTermGrowth = 0.5425
        static let shortTermOffset = 0.0912
        static let shortTermStabilityExponent = 0.0658
        static let decay = 0.1542
    }

    /// ts-fsrs 5.4.2's defaults, which the old app scheduled with and the golden vectors
    /// were computed from (requirements §3.3). Fitting them to the learner is not done.
    /// The easy and short-term weights (`w3`, `w16`…`w19`) are kept so the set is FSRS-6's
    /// whole, though the long-term scheduler with no easy grade never reads them.
    public static let `default` = Self(unchecked: [
        Default.initialStabilityAgain, Default.initialStabilityHard,
        Default.initialStabilityGood, Default.initialStabilityEasy,
        Default.initialDifficulty, Default.initialDifficultyExponent,
        Default.difficultyStep, Default.meanReversion,
        Default.recallGrowth, Default.recallStabilityDecay, Default.recallRetrievabilityGain,
        Default.forgetScale, Default.forgetDifficultyExponent,
        Default.forgetStabilityExponent, Default.forgetRetrievabilityGain,
        Default.hardPenalty, Default.easyBonus,
        Default.shortTermGrowth, Default.shortTermOffset, Default.shortTermStabilityExponent,
        Default.decay,
    ])

    /// How many weights FSRS-6 has.
    public static let count = 21

    /// The weights in FSRS's order: `values[0]` is `w0`.
    public let values: [Double]

    /// Wraps ``count`` weights in FSRS's order.
    public init(_ values: [Double]) throws(FSRSWeightsError) {
        guard values.count == Self.count else {
            throw .wrongCount(values.count)
        }
        self.values = values
    }

    /// For ``default``, whose count is not checked here but pinned by a test.
    private init(unchecked values: [Double]) {
        self.values = values
    }

    /// `w<index>`.
    subscript(index: Int) -> Double {
        values[index]
    }
}

/// One band of interval lengths and how much of it the fuzz may move an interval by.
public struct FSRSFuzzRange: Sendable, Equatable {
    /// Where the band starts, in days.
    public let start: Double
    /// Where it ends, in days; `.infinity` for the last band.
    public let end: Double
    /// The share of the part of an interval inside the band that the fuzz may add or take.
    public let factor: Double

    /// A band from `start` to `end` days moving an interval by up to `factor` of it.
    public init(start: Double, end: Double, factor: Double) {
        self.start = start
        self.end = end
        self.factor = factor
    }
}

/// How an interval is spread over the days around it, so cards graded alike on one day do
/// not all come back on the same day.
public struct FSRSFuzz: Sendable, Equatable {
    /// ts-fsrs's fuzz bounds and bands.
    private enum Default {
        static let thresholdDays = 2.5
        static let floorDays = 2
        static let shortBandEnd = 7.0
        static let middleBandEnd = 20.0
        static let shortBandFactor = 0.15
        static let middleBandFactor = 0.1
        static let longBandFactor = 0.05
    }

    /// ts-fsrs's: no fuzz under 2.5 days, never earlier than day 2, and bands of 15%, 10%,
    /// and 5% from 2.5, 7, and 20 days.
    public static let `default` = Self(
        thresholdDays: Default.thresholdDays,
        floorDays: Default.floorDays,
        ranges: [
            FSRSFuzzRange(
                start: Default.thresholdDays,
                end: Default.shortBandEnd,
                factor: Default.shortBandFactor,
            ),
            FSRSFuzzRange(
                start: Default.shortBandEnd,
                end: Default.middleBandEnd,
                factor: Default.middleBandFactor,
            ),
            FSRSFuzzRange(
                start: Default.middleBandEnd,
                end: .infinity,
                factor: Default.longBandFactor,
            ),
        ],
    )

    /// An interval shorter than this many days is never fuzzed: a day or two is too short
    /// to spread.
    public let thresholdDays: Double
    /// The earliest day a fuzzed interval may land on.
    public let floorDays: Int
    /// The bands whose shares add up to how far an interval may move.
    public let ranges: [FSRSFuzzRange]

    /// A fuzz that leaves intervals under `thresholdDays` alone, moves the rest within
    /// `ranges`, and never lands before `floorDays`.
    public init(thresholdDays: Double, floorDays: Int, ranges: [FSRSFuzzRange]) {
        self.thresholdDays = thresholdDays
        self.floorDays = floorDays
        self.ranges = ranges
    }
}

/// The FSRS-6 scheduler's parameters (requirements §3.3).
public struct FSRSTuning: Sendable, Equatable {
    /// The old app's parameters (requirements §3.3).
    private enum Default {
        static let desiredRetention = 0.9
        static let maximumIntervalDays = 365
        static let shortestIntervalDays = 1
    }

    /// The old app's parameters: the golden vectors hold the scheduler to exactly these.
    public static let `default` = Self(
        weights: .default,
        desiredRetention: Default.desiredRetention,
        maximumIntervalDays: Default.maximumIntervalDays,
        shortestIntervalDays: Default.shortestIntervalDays,
        fuzz: .default,
    )

    /// The model weights.
    public let weights: FSRSWeights
    /// The recall probability an interval aims for on its due day: 0.9 makes an interval
    /// equal to the card's stability.
    public let desiredRetention: Double
    /// The longest interval: a card is seen at least once a year.
    public let maximumIntervalDays: Int
    /// The shortest interval: a card graded again today is due tomorrow at the earliest,
    /// and returns today only as a re-ask (requirements §3.3).
    public let shortestIntervalDays: Int
    /// How intervals are spread.
    public let fuzz: FSRSFuzz

    /// Gathers the scheduler's parameters; the app uses ``default``.
    public init(
        weights: FSRSWeights,
        desiredRetention: Double,
        maximumIntervalDays: Int,
        shortestIntervalDays: Int,
        fuzz: FSRSFuzz,
    ) {
        self.weights = weights
        self.desiredRetention = desiredRetention
        self.maximumIntervalDays = maximumIntervalDays
        self.shortestIntervalDays = shortestIntervalDays
        self.fuzz = fuzz
    }
}
