import Foundation

/// How long a grade would put a card away, as its button says it (`docs/product/ux-flows.md`
/// D2): the one formatter every interval label goes through.
///
/// A value rather than a string, so the rounding is tested apart from the wording. Days
/// read as days up to 29; from 30 days a month is 30 days, rounded half up; 365 days, the
/// longest interval FSRS sets, reads as a year.
public enum IntervalLabel: Hashable, Sendable {
    /// Days, from 1 to 29.
    case days(Int)
    /// About this many months, from 1 to 12.
    case months(Int)
    /// About one year.
    case year

    /// The bounds the label changes at.
    private enum Bound {
        /// The first interval written in months rather than days.
        static let firstMonth = 30
        /// The days one month stands for.
        static let daysPerMonth = 30
        /// Half a month, added before dividing so a month rounds half up.
        static let halfMonth = 15
        /// The interval written as a year: FSRS's longest interval.
        static let year = 365
    }

    /// The label as the button shows it: `1日` / `1 day`, `29日` / `29 days`, `約2か月` /
    /// `≈2 mo`, `約1年` / `≈1 yr`.
    ///
    /// One day and more days are separate keys rather than a plural variation: `swift
    /// test` reads English from each `defaultValue`, which has no plural rule, and the
    /// only languages shipped are English, with two forms, and Japanese, with one.
    public var text: LocalizedStringResource {
        switch self {
        case let .days(count) where count == 1:
            LocalizedStringResource(
                "drill.interval.oneDay",
                defaultValue: "1 day",
                bundle: .module,
                comment: "Interval on a grade button: the card comes back in one day.",
            )

        case let .days(count):
            LocalizedStringResource(
                "drill.interval.days",
                defaultValue: "\(count) days",
                bundle: .module,
                comment: """
                Interval on a grade button: the card comes back in this many days, from 2 \
                to 29.
                """,
            )

        case let .months(count):
            LocalizedStringResource(
                "drill.interval.months",
                defaultValue: "≈\(count) mo",
                bundle: .module,
                comment: """
                Interval on a grade button: the card comes back in about this many months, \
                from 1 to 12.
                """,
            )

        case .year:
            LocalizedStringResource(
                "drill.interval.oneYear",
                defaultValue: "≈1 yr",
                bundle: .module,
                comment: "Interval on a grade button: the card comes back in about a year.",
            )
        }
    }

    /// The label for an interval of `days` days; anything under a day reads as one day,
    /// and anything from a year on as a year.
    public init(days: Int) {
        if days < Bound.firstMonth {
            self = .days(max(1, days))
        } else if days < Bound.year {
            self = .months((days + Bound.halfMonth) / Bound.daysPerMonth)
        } else {
            self = .year
        }
    }
}
