// FSRS-6's intervals and their fuzz, ported from the old app's port
// (tomada1114/instant-composition, packages/domain/src/fsrs-interval.ts) of ts-fsrs 5.4.2
// (src/algorithm.ts, src/help.ts, src/alea.ts and src/impl/long_term_scheduler.ts). Its
// Alea generator (Alea.swift) is a port of an algorithm by Johannes Baagøe, by way of
// David Bau's seedrandom; both notices follow, for the one MIT license they share.
//
// Copyright (c) 2026 Open Spaced Repetition
// Copyright (C) 2010 by Johannes Baagøe <baagoe@baagoe.org>
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

/// Days until the next review per grade, again < hard < good as ts-fsrs orders them.
struct FSRSIntervals: Equatable {
    let again: Int
    let hard: Int
    let good: Int
}

/// Each grade's interval from the stability it leads to, fuzzed by Alea.
struct FSRSIntervalModel: Sendable {
    /// ts-fsrs's fuzz always allows at least a day either way, before the bands add to it.
    private static let baseFuzzDays = 1.0

    private let intervalModifier: Double
    private let shortestDays: Double
    private let longestDays: Double
    private let fuzz: FSRSFuzz

    init(tuning: FSRSTuning, intervalModifier: Double) {
        self.intervalModifier = intervalModifier
        shortestDays = Double(tuning.shortestIntervalDays)
        longestDays = Double(tuning.maximumIntervalDays)
        fuzz = tuning.fuzz
    }

    /// Each grade's interval. Every grade's fuzz draws the same first number from a
    /// generator seeded with `seed` — ts-fsrs's card id and `reps` after this review — so
    /// cards graded alike on one day spread out while the same inputs always give the same
    /// day. Each grade's interval is at least a day longer than the one before it.
    func intervals(
        again: Double,
        hard: Double,
        good: Double,
        elapsedDays: Int,
        seed: String,
    ) -> FSRSIntervals {
        let elapsed = Double(elapsedDays)
        let hardDays = interval(stability: hard, elapsedDays: elapsed, seed: seed)
        let againDays = min(interval(stability: again, elapsedDays: elapsed, seed: seed), hardDays)
        let raisedHard = max(hardDays, againDays + 1)
        let goodDays = max(
            interval(stability: good, elapsedDays: elapsed, seed: seed),
            raisedHard + 1,
        )
        return FSRSIntervals(again: Int(againDays), hard: Int(raisedHard), good: Int(goodDays))
    }

    private func interval(stability: Double, elapsedDays: Double, seed: String) -> Double {
        let days = min(
            max(shortestDays, ECMAScriptMath.round(stability * intervalModifier)),
            longestDays,
        )
        return fuzzed(days, elapsedDays: elapsedDays, seed: seed)
    }

    /// An interval moved within `[max(floor, round(I − δ)), min(round(I + δ), longest)]`,
    /// never to a day the card has already waited past. Under the threshold it stays.
    private func fuzzed(_ interval: Double, elapsedDays: Double, seed: String) -> Double {
        guard interval >= fuzz.thresholdDays else {
            return interval
        }
        var delta = Self.baseFuzzDays
        for range in fuzz.ranges {
            delta += range.factor * max(min(interval, range.end) - range.start, 0)
        }
        let capped = min(interval, longestDays)
        var lowest = max(Double(fuzz.floorDays), ECMAScriptMath.round(capped - delta))
        let highest = min(ECMAScriptMath.round(capped + delta), longestDays)
        if capped > elapsedDays {
            lowest = max(lowest, elapsedDays + 1)
        }
        lowest = min(lowest, highest)
        return (Alea.firstNumber(seed: seed) * (highest - lowest + 1) + lowest).rounded(.down)
    }
}
