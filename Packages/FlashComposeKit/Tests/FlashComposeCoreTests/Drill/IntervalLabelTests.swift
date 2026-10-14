import FlashComposeCore
import Foundation
import Testing

/// The one formatter for a grade button's interval (`docs/product/ux-flows.md` D2):
/// days up to 29, months from 30 days rounded half up, a year at 365.
@Suite("IntervalLabel")
struct IntervalLabelTests {
    /// Days in, the label worked out by hand, and its English and Japanese.
    struct Case: Sendable, CustomTestStringConvertible {
        let days: Int
        let label: IntervalLabel
        let english: String
        let japanese: String

        var testDescription: String {
            "\(days) days -> \(english)"
        }
    }

    static let cases: [Case] = [
        // Example 5.
        Case(days: 1, label: .days(1), english: "1 day", japanese: "1日"),
        Case(days: 29, label: .days(29), english: "29 days", japanese: "29日"),
        Case(days: 30, label: .months(1), english: "≈1 mo", japanese: "約1か月"),
        Case(days: 45, label: .months(2), english: "≈2 mo", japanese: "約2か月"),
        Case(days: 200, label: .months(7), english: "≈7 mo", japanese: "約7か月"),
        Case(days: 365, label: .year, english: "≈1 yr", japanese: "約1年"),
        // Each side of every bound.
        Case(days: 2, label: .days(2), english: "2 days", japanese: "2日"),
        Case(days: 44, label: .months(1), english: "≈1 mo", japanese: "約1か月"),
        Case(days: 344, label: .months(11), english: "≈11 mo", japanese: "約11か月"),
        Case(days: 345, label: .months(12), english: "≈12 mo", japanese: "約12か月"),
        Case(days: 364, label: .months(12), english: "≈12 mo", japanese: "約12か月"),
    ]

    @Test(arguments: cases)
    func `the label follows the interval's bounds`(_ testCase: Case) {
        #expect(IntervalLabel(days: testCase.days) == testCase.label)
    }

    @Test(arguments: cases)
    func `the label reads in English and in Japanese`(_ testCase: Case) throws {
        let text = IntervalLabel(days: testCase.days).text
        #expect(text.english == testCase.english)
        let argument: [any CVarArg] = switch testCase.label {
        case let .days(count) where count > 1:
            [count]

        case let .months(count):
            [count]

        case .days, .year:
            []
        }
        #expect(try CatalogJapanese.render(text.key, argument) == testCase.japanese)
    }

    @Test
    func `an interval shorter than a day still reads as one day`() {
        #expect(IntervalLabel(days: 0) == .days(1))
    }

    @Test
    func `an interval past the longest still reads as one year`() {
        #expect(IntervalLabel(days: 400) == .year)
    }
}
