// FSRS-6's memory formulas, ported from the old app's port (tomada1114/instant-composition,
// packages/domain/src/fsrs-memory.ts) of ts-fsrs 5.4.2 (src/algorithm.ts and src/help.ts),
// whose notice follows. The operations and their roundings are kept in ts-fsrs's order,
// so the golden vectors match to the last bit rather than within a tolerance.
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
import Foundation

/// What FSRS remembers of a card between reviews.
struct FSRSMemory: Equatable {
    let stability: Double
    let difficulty: Double
}

/// FSRS-6's long-term memory formulas over one set of weights.
struct FSRSMemoryModel: Sendable {
    /// What the formulas mean rather than how they are tuned: FSRS-6's own bounds and
    /// ts-fsrs's precision.
    private enum Invariant {
        /// ts-fsrs rounds every stored or compared value to 8 decimal places.
        static let decimals = 8
        static let minimumStability = 0.001
        static let maximumStability = 36_500.0
        /// A new card's stability is never below this, whatever `w0`…`w2` say.
        static let minimumInitialStability = 0.1
        static let difficulty = 1.0 ... 10.0
        /// The `11` of `(11 − D)` in the recall stability: a card at the hardest difficulty
        /// still gains.
        static let difficultyCeilingPlusOne = 11.0
        /// The `9` of `(10 − D) / 9`, the span of the difficulty range.
        static let difficultySpan = 9.0
        /// FSRS's easy rating, which no card is given but mean reversion reads.
        static let easyRating = 4
        /// The retrievability at `t = S`, by FSRS's definition of stability.
        static let retrievabilityAtStability = 0.9
    }

    /// Which of the 21 weights each formula reads, by FSRS-6's numbering.
    private enum Weight {
        static let initialDifficulty = 4
        static let initialDifficultyExponent = 5
        static let difficultyStep = 6
        static let meanReversion = 7
        static let recallGrowth = 8
        static let recallStabilityDecay = 9
        static let recallRetrievabilityGain = 10
        static let forgetScale = 11
        static let forgetDifficultyExponent = 12
        static let forgetStabilityExponent = 13
        static let forgetRetrievabilityGain = 14
        static let hardPenalty = 15
        static let decay = 20
    }

    private let weights: FSRSWeights
    /// `−w20`, the forgetting curve's exponent.
    private let decay: Double
    /// `F = 0.9^(1/decay) − 1`, so the curve reads 0.9 when `t` equals `S`.
    private let factor: Double

    /// Days of stability to days of interval: 1 at a desired retention of 0.9.
    let intervalModifier: Double

    init(tuning: FSRSTuning) {
        weights = tuning.weights
        let curveDecay = -tuning.weights[Weight.decay]
        let curveFactor = ECMAScriptMath.round(
            exp(pow(curveDecay, -1) * log(Invariant.retrievabilityAtStability)) - 1,
            decimals: Invariant.decimals,
        )
        decay = curveDecay
        factor = curveFactor
        intervalModifier = ECMAScriptMath.round(
            (pow(tuning.desiredRetention, 1 / curveDecay) - 1) / curveFactor,
            decimals: Invariant.decimals,
        )
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func rounded(_ value: Double) -> Double {
        ECMAScriptMath.round(value, decimals: Invariant.decimals)
    }

    /// `R(t, S) = (1 + F·t/S)^(−w20)`: the chance of recall `elapsedDays` after a review.
    func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        Self.rounded(pow(1 + (factor * elapsedDays) / stability, decay))
    }

    /// `S0 = w[G−1]`, floored at 0.1; `D0 = w4 − e^(w5·(G−1)) + 1`, clamped to 1…10.
    func initialMemory(grade: Grade) -> FSRSMemory {
        FSRSMemory(
            stability: max(weights[grade.rawValue - 1], Invariant.minimumInitialStability),
            difficulty: Self.clamp(
                initialDifficulty(rating: grade.rawValue),
                Invariant.difficulty.lowerBound,
                Invariant.difficulty.upperBound,
            ),
        )
    }

    /// The memory after a review `elapsedDays` after the last one. Long-term only: a lapse
    /// never ends above the stability it started from.
    func nextMemory(_ memory: FSRSMemory, elapsedDays: Double, grade: Grade) -> FSRSMemory {
        let recall = forgettingCurve(elapsedDays: elapsedDays, stability: memory.stability)
        let stability: Double = switch grade {
        case .again:
            Self.clamp(
                Self.rounded(memory.stability),
                Invariant.minimumStability,
                forgetStability(memory, recall: recall),
            )

        case .good, .hard:
            recallStability(memory, recall: recall, grade: grade)
        }
        return FSRSMemory(
            stability: stability,
            difficulty: nextDifficulty(memory.difficulty, grade: grade),
        )
    }

    private func initialDifficulty(rating: Int) -> Double {
        Self.rounded(
            weights[Weight.initialDifficulty]
                - exp(Double(rating - 1) * weights[Weight.initialDifficultyExponent]) + 1,
        )
    }

    /// The grade's step on D, damped toward 10, then reverted toward easy's D0 by w7.
    private func nextDifficulty(_ difficulty: Double, grade: Grade) -> Double {
        let delta = -weights[Weight.difficultyStep] * Double(grade.rawValue - Grade.good.rawValue)
        let damped = difficulty + Self.rounded(
            (delta * (Invariant.difficulty.upperBound - difficulty)) / Invariant.difficultySpan,
        )
        let reversion = weights[Weight.meanReversion]
        return Self.clamp(
            Self.rounded(
                reversion * initialDifficulty(rating: Invariant.easyRating)
                    + (1 - reversion) * damped,
            ),
            Invariant.difficulty.lowerBound,
            Invariant.difficulty.upperBound,
        )
    }

    private func recallStability(_ memory: FSRSMemory, recall: Double, grade: Grade) -> Double {
        let stability = memory.stability
        let hardPenalty = grade == .hard ? weights[Weight.hardPenalty] : 1
        // Left to right, as JavaScript multiplies `a * b * c * d * e`.
        let growth = exp(weights[Weight.recallGrowth])
            * (Invariant.difficultyCeilingPlusOne - memory.difficulty)
            * pow(stability, -weights[Weight.recallStabilityDecay])
            * (exp((1 - recall) * weights[Weight.recallRetrievabilityGain]) - 1)
            * hardPenalty
        return Self.rounded(
            Self.clamp(
                stability * (1 + growth),
                Invariant.minimumStability,
                Invariant.maximumStability,
            ),
        )
    }

    private func forgetStability(_ memory: FSRSMemory, recall: Double) -> Double {
        let value = weights[Weight.forgetScale]
            * pow(memory.difficulty, -weights[Weight.forgetDifficultyExponent])
            * (pow(memory.stability + 1, weights[Weight.forgetStabilityExponent]) - 1)
            * exp((1 - recall) * weights[Weight.forgetRetrievabilityGain])
        return Self.rounded(
            Self.clamp(value, Invariant.minimumStability, Invariant.maximumStability),
        )
    }
}
