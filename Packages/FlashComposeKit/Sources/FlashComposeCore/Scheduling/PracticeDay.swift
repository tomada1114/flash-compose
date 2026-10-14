import Foundation

/// Why a ``PracticeDay`` could not be made from a year, a month, and a day.
///
/// It names the rule that failed and carries nothing of the rejected date.
public enum PracticeDayError: Error, Equatable, Sendable {
    /// The parts name no date in the Gregorian calendar between the years 1 and 9999,
    /// such as February 29 in a common year, month 13, or day 0.
    case notACalendarDate
}

/// A proleptic Gregorian date as its three parts, the form ``CivilCalendar`` converts a
/// day number to and from.
private struct CivilDate: Equatable {
    private enum Width {
        static let year = 4
        static let monthOrDay = 2
    }

    let year: Int
    let month: Int
    let day: Int

    /// `YYYY-MM-DD`, zero-padded.
    var isoString: String {
        "\(Self.padded(year, to: Width.year))-"
            + "\(Self.padded(month, to: Width.monthOrDay))-"
            + "\(Self.padded(day, to: Width.monthOrDay))"
    }

    private static func padded(_ value: Int, to width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}

/// Conversions between a proleptic Gregorian date and a count of days since 0000-03-01.
///
/// Howard Hinnant's `days_from_civil` and `civil_from_days`
/// (<https://howardhinnant.github.io/date_algorithms.html>): counting years from March puts
/// the leap day last, so every month's start is a fixed linear function of its index, and
/// 400-year eras of exactly 146,097 days repeat the whole leap-year pattern.
private enum CivilCalendar {
    static let supportedYears = 1 ... 9_999
    static let months = 1 ... 12
    static let daysOfMonth = 1 ... 31

    static let yearsPerEra = 400
    static let daysPerEra = 146_097
    static let daysPerCommonYear = 365
    static let yearsPerLeapCycle = 4
    static let yearsPerCentury = 100
    /// Days in the first 4 years of an era, minus one: a leap-day correction in
    /// ``date(dayNumber:)``.
    static let daysPerLeapCycleMinusOne = 1_460
    /// Days in the first 100 years of an era, minus one.
    static let daysPerCenturyMinusOne = 36_524
    /// March, the first month of a March-based year, as a calendar month number.
    static let march = 3
    /// A March-based month index of 10 or more is January or February of the next
    /// calendar year.
    static let monthsFromMarchToYearEnd = 10
    /// Every 5 months from March span 153 days (31, 30, 31, 30, 31), so a month's first
    /// day is `(153 × index + 2) / 5` days into the March-based year.
    static let daysPerFiveMonths = 153
    static let monthsPerFiveMonthCycle = 5
    static let monthStartRounding = 2
    static let monthsPerYear = 12

    static func dayNumber(of date: CivilDate) -> Int {
        let marchYear = date.month < march ? date.year - 1 : date.year
        let era = floorDivide(marchYear, by: yearsPerEra)
        let yearOfEra = marchYear - era * yearsPerEra
        let monthFromMarch = date.month < march
            ? date.month + monthsPerYear - march
            : date.month - march
        let dayOfYear = (daysPerFiveMonths * monthFromMarch + monthStartRounding)
            / monthsPerFiveMonthCycle + date.day - 1
        let dayOfEra = yearOfEra * daysPerCommonYear
            + yearOfEra / yearsPerLeapCycle
            - yearOfEra / yearsPerCentury
            + dayOfYear
        return era * daysPerEra + dayOfEra
    }

    static func date(dayNumber: Int) -> CivilDate {
        let era = floorDivide(dayNumber, by: daysPerEra)
        let dayOfEra = dayNumber - era * daysPerEra
        let yearOfEra = (
            dayOfEra
                - dayOfEra / daysPerLeapCycleMinusOne
                + dayOfEra / daysPerCenturyMinusOne
                - dayOfEra / (daysPerEra - 1),
        ) / daysPerCommonYear
        let dayOfYear = dayOfEra
            - (yearOfEra * daysPerCommonYear
                + yearOfEra / yearsPerLeapCycle
                - yearOfEra / yearsPerCentury)
        let monthFromMarch = (monthsPerFiveMonthCycle * dayOfYear + monthStartRounding)
            / daysPerFiveMonths
        let day = dayOfYear
            - (daysPerFiveMonths * monthFromMarch + monthStartRounding) / monthsPerFiveMonthCycle
            + 1
        let isNextCalendarYear = monthFromMarch >= monthsFromMarchToYearEnd
        let month = isNextCalendarYear
            ? monthFromMarch + march - monthsPerYear
            : monthFromMarch + march
        let year = yearOfEra + era * yearsPerEra + (isNextCalendarYear ? 1 : 0)
        return CivilDate(year: year, month: month, day: day)
    }

    /// Division rounding toward negative infinity, so a day before 0000-03-01 still falls
    /// in the era it belongs to; Swift's `/` rounds toward zero.
    private static func floorDivide(_ dividend: Int, by divisor: Int) -> Int {
        let quotient = dividend / divisor
        return dividend % divisor < 0 ? quotient - 1 : quotient
    }
}

/// The day an answer counts toward: a calendar date that starts at 04:00 local time, so a
/// late night belongs to the day it started in (`docs/product/requirements.md` §3.3).
///
/// A date, not an instant, because FSRS intervals and the elapsed days between reviews
/// count practice days rather than hours (`docs/architecture.md` › Scheduling): a card due
/// in one day is due the next practice day, however many hours that is away, and a
/// daylight-saving change can neither skip nor repeat one. Every interval is therefore
/// ``days(since:)`` of two practice days, never a difference of two instants.
///
/// The arithmetic is on the proleptic Gregorian calendar, whatever calendar the phone is
/// set to, so a phone set to the Japanese calendar keeps the same days.
public struct PracticeDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The local hour a practice day starts at: an answer at 03:59 counts toward the
    /// previous date, one at 04:00 toward the new one. Part of what a practice day means,
    /// not a tunable, so it lives here rather than in a tuning type.
    public static let boundaryHour = 4

    /// Days since 0000-03-01 in the proleptic Gregorian calendar: one number makes adding,
    /// subtracting, ordering, and hashing exact, with no calendar or time zone involved.
    private let dayNumber: Int

    /// The calendar year.
    public var year: Int {
        CivilCalendar.date(dayNumber: dayNumber).year
    }

    /// The month, from 1 for January to 12 for December.
    public var month: Int {
        CivilCalendar.date(dayNumber: dayNumber).month
    }

    /// The day of the month, from 1.
    public var day: Int {
        CivilCalendar.date(dayNumber: dayNumber).day
    }

    /// The date as `YYYY-MM-DD`, such as `2026-10-14`, which is how a test failure or a
    /// log line shows it.
    public var description: String {
        CivilCalendar.date(dayNumber: dayNumber).isoString
    }

    /// The practice day `instant` belongs to on a wall clock in `timeZone`: the date the
    /// clock shows, or the date before while it still reads earlier than
    /// ``boundaryHour``.
    ///
    /// The zone is passed in, never read from the process, because the practice day
    /// follows the phone's time zone at the moment of each answer (requirements §4): the
    /// caller hands over the zone current at that answer. The hour is read from the wall
    /// clock rather than by moving the instant back four hours, so on a 23- or 25-hour
    /// daylight-saving day 04:00 local still starts the new practice day.
    public init(instant: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let wallDate = CivilCalendar.dayNumber(of: CivilDate(
            year: calendar.component(.year, from: instant),
            month: calendar.component(.month, from: instant),
            day: calendar.component(.day, from: instant),
        ))
        let hour = calendar.component(.hour, from: instant)
        dayNumber = hour < Self.boundaryHour ? wallDate - 1 : wallDate
    }

    /// The practice day on a given date, for tests and for the store reading a stored
    /// day back.
    ///
    /// An impossible date is rejected rather than rolled over into the next month, so a
    /// corrupted stored value is caught where it enters Core instead of silently moving a
    /// card's schedule.
    public init(year: Int, month: Int, day: Int) throws(PracticeDayError) {
        guard CivilCalendar.supportedYears.contains(year),
              CivilCalendar.months.contains(month),
              CivilCalendar.daysOfMonth.contains(day)
        else {
            throw .notACalendarDate
        }
        let date = CivilDate(year: year, month: month, day: day)
        let candidate = CivilCalendar.dayNumber(of: date)
        guard CivilCalendar.date(dayNumber: candidate) == date else {
            throw .notACalendarDate
        }
        dayNumber = candidate
    }

    private init(dayNumber: Int) {
        self.dayNumber = dayNumber
    }

    /// Earlier days first.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    /// The practice day `days` calendar days after this one, or before it for a negative
    /// count: how a scheduled interval turns into a due day.
    public func adding(days: Int) -> Self {
        Self(dayNumber: dayNumber + days)
    }

    /// The whole calendar days from `earlier` to this day (`self − earlier`), negative
    /// when `earlier` is in fact later: the elapsed days FSRS reads, counted in practice
    /// days rather than hours.
    public func days(since earlier: Self) -> Int {
        dayNumber - earlier.dayNumber
    }
}
