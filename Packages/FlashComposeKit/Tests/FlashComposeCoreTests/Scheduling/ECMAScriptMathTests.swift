import FlashComposeCore
import Testing

/// JavaScript's rounding and ToUint32, on the inputs where Swift's own would differ.
@Suite("ECMAScript math")
struct ECMAScriptMathTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let input: Double
        let expected: Double

        var testDescription: String {
            "\(input) -> \(expected)"
        }
    }

    @Test(arguments: [
        Case(input: 2.5, expected: 3),
        Case(input: -2.5, expected: -2),
        Case(input: 0.49999999999999994, expected: 0),
        Case(input: 1.4, expected: 1),
        Case(input: -1.6, expected: -2),
        Case(input: 7, expected: 7),
    ])
    func `round matches Math.round, a tie going toward positive infinity`(case: Case) {
        #expect(ECMAScriptMath.round(`case`.input) == `case`.expected)
    }

    @Test
    func `round to decimals matches ts-fsrs's roundTo`() {
        #expect(ECMAScriptMath.round(5.1121707149, decimals: 8) == 5.11217071)
        #expect(ECMAScriptMath.round(0.123456785, decimals: 8) == 0.12345679)
    }

    @Test(arguments: [
        Case(input: 3.9, expected: 3),
        Case(input: 4_294_967_296, expected: 0),
        Case(input: 4_294_967_297.5, expected: 1),
        Case(input: -1.5, expected: 4_294_967_295),
    ])
    func `uint32 matches unsigned right shift by zero`(case: Case) {
        #expect(ECMAScriptMath.uint32(`case`.input) == `case`.expected)
    }
}
