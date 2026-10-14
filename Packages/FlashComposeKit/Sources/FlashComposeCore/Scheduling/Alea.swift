// The first number of ts-fsrs 5.4.2's Alea generator (src/alea.ts), ported from the old
// app's port (tomada1114/instant-composition, packages/domain/src/fsrs-interval.ts). Alea
// is an algorithm by Johannes Baagøe, by way of David Bau's seedrandom; both notices
// follow, for the one MIT license they share.
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

/// The Alea generator, reduced to the one number the fuzz draws from it.
///
/// Every value is a `Double` doing exactly what JavaScript's Number does, so the same seed
/// gives the same number to the bit as in ts-fsrs. Not a `RandomNumberGenerator`: the
/// schedule must be a pure function of the card and its rep count, never of a generator's
/// history.
enum Alea {
    /// Alea's constants, from Baagøe's reference implementation.
    private enum Constant {
        /// `Mash`'s initial state.
        static let mashSeed = 4_022_871_197.0
        /// `Mash`'s multiplier.
        static let mashMultiplier = 0.02519603282416938
        /// The multiplier of Alea's `next()`.
        static let stepMultiplier = 2_091_639.0
        /// 2⁻³², which scales a 32-bit integer into `[0, 1)`.
        static let twoToTheMinus32 = 2.3283064365386963e-10
        /// The string each of Alea's three state words starts as the hash of.
        static let blank = " "
    }

    /// Alea's string hash, `Mash`; one instance per generator, as Alea makes them.
    private struct Mash {
        private var state = Constant.mashSeed

        mutating func hash(_ data: String) -> Double {
            for unit in data.utf16 {
                state += Double(unit)
                var hash = Constant.mashMultiplier * state
                state = ECMAScriptMath.uint32(hash)
                hash -= state
                hash *= state
                state = ECMAScriptMath.uint32(hash)
                hash -= state
                state += hash * ECMAScriptMath.twoToThe32
            }
            return ECMAScriptMath.uint32(state) * Constant.twoToTheMinus32
        }
    }

    /// The first number in `[0, 1)` an Alea generator seeded with `seed` gives.
    static func firstNumber(seed: String) -> Double {
        var mash = Mash()
        let first = mash.hash(Constant.blank)
        // Alea's other two state words: the first number never reads them, but the hash
        // state they leave behind is what the seed is then hashed from.
        _ = mash.hash(Constant.blank)
        _ = mash.hash(Constant.blank)
        let difference = first - mash.hash(seed)
        let word = difference < 0 ? difference + 1 : difference
        // One step of Alea's `next()`, its carry still at 1.
        let step = Constant.stepMultiplier * word + Constant.twoToTheMinus32
        return step - step.rounded(.towardZero)
    }
}
