import FlashComposeCore
import Testing

/// A practice day as a calendar date: built from its parts, compared, printed, and moved
/// by whole days.
@Suite("PracticeDay as a calendar date")
struct PracticeDayCalendarTests {
    typealias Fixture = DomainValuesFixture

    @Test(arguments: [
        // Example 3.
        ("2026-10-01", 3, "2026-10-04"),
        ("2026-12-31", 1, "2027-01-01"),
        ("2028-02-28", 1, "2028-02-29"),
        // Months, years, and leap years.
        ("2028-02-29", 1, "2028-03-01"),
        ("2026-02-28", 1, "2026-03-01"),
        ("2100-02-28", 1, "2100-03-01"),
        ("2000-02-28", 1, "2000-02-29"),
        ("2026-01-31", 1, "2026-02-01"),
        ("2026-10-14", 365, "2027-10-14"),
        ("2027-10-14", 365, "2028-10-13"),
        ("2026-10-14", 0, "2026-10-14"),
        // Backwards.
        ("2026-03-01", -1, "2026-02-28"),
        ("2027-01-01", -1, "2026-12-31"),
        ("2028-03-01", -1, "2028-02-29"),
        // The US daylight-saving dates are ordinary calendar days.
        ("2026-03-07", 1, "2026-03-08"),
        ("2026-03-08", 1, "2026-03-09"),
        ("2026-10-31", 1, "2026-11-01"),
        ("2026-11-01", 1, "2026-11-02"),
    ])
    func `adding days is calendar arithmetic`(start: String, days: Int, expected: String) throws {
        #expect(try Fixture.day(start).adding(days: days) == (Fixture.day(expected)))
    }

    @Test(arguments: [
        // Example 3.
        ("2026-10-01", "2026-10-04", 3),
        ("2026-10-04", "2026-10-01", -3),
        ("2026-10-14", "2026-10-14", 0),
        ("2026-12-31", "2027-01-01", 1),
        ("2028-02-28", "2028-03-01", 2),
        ("2026-02-28", "2026-03-01", 1),
        ("2026-10-31", "2026-11-02", 2),
        ("2026-03-07", "2026-03-09", 2),
        ("2026-01-01", "2027-01-01", 365),
        ("2028-01-01", "2029-01-01", 366),
    ])
    func `the days between two practice days are later minus earlier`(
        earlier: String,
        later: String,
        expected: Int,
    ) throws {
        #expect(try Fixture.day(later).days(since: Fixture.day(earlier)) == expected)
    }

    @Test(arguments: [-800, -366, -1, 0, 1, 59, 365, 366, 1_461, 36_525])
    func `adding then measuring gives back the same count`(days: Int) throws {
        let start = try Fixture.day("2026-10-14")
        #expect(start.adding(days: days).days(since: start) == days)
    }

    @Test(arguments: [
        ("2026-10-14", 2_026, 10, 14),
        ("2028-02-29", 2_028, 2, 29),
        ("2027-01-01", 2_027, 1, 1),
        ("2026-12-31", 2_026, 12, 31),
        ("0001-01-01", 1, 1, 1),
        ("9999-12-31", 9_999, 12, 31),
    ])
    func `a valid date keeps its parts`(iso: String, year: Int, month: Int, day: Int) throws {
        let practiceDay = try Fixture.day(iso)
        #expect(practiceDay.year == year)
        #expect(practiceDay.month == month)
        #expect(practiceDay.day == day)
        #expect(practiceDay.description == iso)
    }

    @Test(arguments: [
        "2026-02-29", // not a leap year
        "2100-02-29", // a century that is not a leap year
        "2026-02-30",
        "2026-04-31",
        "2026-13-01",
        "2026-00-10",
        "2026-10-00",
        "2026-10-32",
        "0000-01-01", // before year 1
        "10000-01-01", // past year 9999
    ])
    func `a date the calendar does not have is rejected`(iso: String) throws {
        let parts = try Fixture.components(iso)
        #expect(throws: PracticeDayError.notACalendarDate) {
            try PracticeDay(year: parts.year, month: parts.month, day: parts.day)
        }
    }

    @Test
    func `arithmetic stays exact before year 1, where the eras count backwards`() throws {
        let first = try Fixture.day("0001-01-01")

        let dayBefore = first.adding(days: -1)
        #expect((dayBefore.year, dayBefore.month, dayBefore.day) == (0, 12, 31))
        #expect(dayBefore.description == "0000-12-31")

        // Year 0 is a leap year in the proleptic Gregorian calendar: 366 days long.
        let yearZero = first.adding(days: -366)
        #expect((yearZero.year, yearZero.month, yearZero.day) == (0, 1, 1))
        #expect(first.days(since: yearZero) == 366)
    }

    @Test
    func `practice days order by date`() throws {
        let days = try ["2027-01-01", "2026-10-14", "2026-12-31", "2026-10-13"].map(Fixture.day)
        let expected = try ["2026-10-13", "2026-10-14", "2026-12-31", "2027-01-01"]
            .map(Fixture.day)
        #expect(days.sorted() == expected)
        #expect(try Fixture.day("2026-10-13") < Fixture.day("2026-10-14"))
        let sameDay = try Fixture.day("2026-10-13").adding(days: 1)
        #expect(try !(Fixture.day("2026-10-14") < sameDay))
    }

    @Test
    func `the same date is the same practice day however it was made`() throws {
        let fromParts = try Fixture.day("2026-10-14")
        let fromArithmetic = try Fixture.day("2026-10-01").adding(days: 13)
        #expect(fromParts == fromArithmetic)
        #expect(Set([fromParts, fromArithmetic, fromParts.adding(days: 1)]).count == 2)
    }
}
