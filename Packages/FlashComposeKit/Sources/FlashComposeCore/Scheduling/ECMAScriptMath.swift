// JavaScript's rounding and integer conversions, which ts-fsrs 5.4.2 (src/help.ts) and
// the old app's port of it compute with, so the port reproduces their results to the bit.
// ts-fsrs's notice follows.
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

/// JavaScript's `Math.round`, `>>> 0`, and ts-fsrs's `roundTo`, over `Double`.
package enum ECMAScriptMath {
    /// 2³², the modulus of a 32-bit unsigned integer.
    package static let twoToThe32 = 4_294_967_296.0
    /// 10, the base `roundTo` scales by.
    private static let decimalBase = 10.0
    /// The halfway point at which `Math.round` rounds up.
    private static let half = 0.5

    /// `Math.round(value)`: the nearest integer, a tie rounding toward +∞.
    ///
    /// Not `value.rounded()`, which rounds a tie away from zero (−2.5 to −3 where
    /// JavaScript gives −2), and not `floor(value + 0.5)`, whose addition itself rounds
    /// (0.49999999999999994 to 1). `value − floor(value)` is exact, so this is too.
    package static func round(_ value: Double) -> Double {
        let floor = value.rounded(.down)
        return value - floor >= half ? floor + 1 : floor
    }

    /// ts-fsrs's `roundTo(value, decimals)`: `Math.round(value · 10^decimals) / 10^decimals`.
    package static func round(_ value: Double, decimals: Int) -> Double {
        let factor = (0 ..< decimals).reduce(1.0) { product, _ in product * decimalBase }
        return round(value * factor) / factor
    }

    /// `value >>> 0`: JavaScript's ToUint32, the value truncated toward zero and reduced
    /// modulo 2³² into `0 ..< 2³²`, kept as the `Double` JavaScript keeps it as.
    package static func uint32(_ value: Double) -> Double {
        let remainder = value.rounded(.towardZero).truncatingRemainder(dividingBy: twoToThe32)
        return remainder < 0 ? remainder + twoToThe32 : remainder
    }
}
