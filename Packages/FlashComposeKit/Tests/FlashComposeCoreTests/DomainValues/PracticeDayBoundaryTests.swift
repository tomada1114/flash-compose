import FlashComposeCore
import Foundation
import Testing

/// Which practice day an instant belongs to: its wall-clock date in the zone passed in,
/// or the date before while that clock still reads earlier than 04:00.
@Suite("PracticeDay from an instant")
struct PracticeDayBoundaryTests {
    typealias Fixture = DomainValuesFixture

    /// One instant (with its offset spelled out), the zone it is read in, and the
    /// practice day worked out by hand.
    struct Case: Sendable, CustomTestStringConvertible {
        let instant: String
        let zone: String
        let expected: String

        var testDescription: String {
            "\(instant) in \(zone) -> \(expected)"
        }
    }

    static let tokyo: [Case] = [
        // Example 1: 01:30 belongs to the day before.
        Case(instant: "2026-10-14T01:30:00+09:00", zone: "Asia/Tokyo", expected: "2026-10-13"),
        Case(instant: "2026-10-14T00:00:00+09:00", zone: "Asia/Tokyo", expected: "2026-10-13"),
        // Example 2: the boundary itself.
        Case(instant: "2026-10-14T03:59:59+09:00", zone: "Asia/Tokyo", expected: "2026-10-13"),
        Case(instant: "2026-10-14T04:00:00+09:00", zone: "Asia/Tokyo", expected: "2026-10-14"),
        Case(instant: "2026-10-14T23:59:59+09:00", zone: "Asia/Tokyo", expected: "2026-10-14"),
        Case(instant: "2026-10-15T03:59:59+09:00", zone: "Asia/Tokyo", expected: "2026-10-14"),
        // Stepping back over a month, a year, and a leap day.
        Case(instant: "2027-01-01T02:00:00+09:00", zone: "Asia/Tokyo", expected: "2026-12-31"),
        Case(instant: "2026-03-01T03:00:00+09:00", zone: "Asia/Tokyo", expected: "2026-02-28"),
        Case(instant: "2028-03-01T03:00:00+09:00", zone: "Asia/Tokyo", expected: "2028-02-29"),
        Case(instant: "2026-11-01T00:30:00+09:00", zone: "Asia/Tokyo", expected: "2026-10-31"),
    ]

    static let losAngeles: [Case] = [
        // Example 2's second half.
        Case(
            instant: "2026-10-13T20:00:00-07:00",
            zone: "America/Los_Angeles",
            expected: "2026-10-13",
        ),
        // Fall back, 2026-11-01: 02:00 PDT becomes 01:00 PST, so the local day is 25 hours
        // long and 01:30 happens twice — both times before the boundary.
        Case(
            instant: "2026-11-01T00:30:00-07:00",
            zone: "America/Los_Angeles",
            expected: "2026-10-31",
        ),
        Case(
            instant: "2026-11-01T01:30:00-07:00",
            zone: "America/Los_Angeles",
            expected: "2026-10-31",
        ),
        Case(
            instant: "2026-11-01T01:30:00-08:00",
            zone: "America/Los_Angeles",
            expected: "2026-10-31",
        ),
        Case(
            instant: "2026-11-01T03:59:59-08:00",
            zone: "America/Los_Angeles",
            expected: "2026-10-31",
        ),
        Case(
            instant: "2026-11-01T04:00:00-08:00",
            zone: "America/Los_Angeles",
            expected: "2026-11-01",
        ),
        Case(
            instant: "2026-11-01T12:00:00-08:00",
            zone: "America/Los_Angeles",
            expected: "2026-11-01",
        ),
        Case(
            instant: "2026-11-02T03:59:59-08:00",
            zone: "America/Los_Angeles",
            expected: "2026-11-01",
        ),
        // Spring forward, 2026-03-08: 02:00 PST becomes 03:00 PDT, so the local day is 23
        // hours long; 04:00 PDT is still the start of the new practice day, although only
        // three hours of the night have passed since midnight.
        Case(
            instant: "2026-03-08T01:59:59-08:00",
            zone: "America/Los_Angeles",
            expected: "2026-03-07",
        ),
        Case(
            instant: "2026-03-08T03:00:00-07:00",
            zone: "America/Los_Angeles",
            expected: "2026-03-07",
        ),
        Case(
            instant: "2026-03-08T03:59:59-07:00",
            zone: "America/Los_Angeles",
            expected: "2026-03-07",
        ),
        Case(
            instant: "2026-03-08T04:00:00-07:00",
            zone: "America/Los_Angeles",
            expected: "2026-03-08",
        ),
    ]

    static let elsewhere: [Case] = [
        // A half-hour offset.
        Case(instant: "2026-10-14T03:59:59+05:30", zone: "Asia/Kolkata", expected: "2026-10-13"),
        Case(instant: "2026-10-14T04:00:00+05:30", zone: "Asia/Kolkata", expected: "2026-10-14"),
        Case(instant: "2026-10-14T03:59:59Z", zone: "UTC", expected: "2026-10-13"),
        Case(instant: "2026-10-14T04:00:00Z", zone: "UTC", expected: "2026-10-14"),
    ]

    @Test(arguments: tokyo + losAngeles + elsewhere)
    func `an instant belongs to its local date, or the one before until 04:00`(
        example: Case,
    ) throws {
        let day = try PracticeDay(
            instant: Fixture.instant(example.instant),
            timeZone: Fixture.zone(example.zone),
        )
        #expect(try day == (Fixture.day(example.expected)))
    }

    @Test
    func `the last millisecond before 04:00 is the previous day, 04:00 sharp the new one`() throws {
        let zone = try Fixture.zone("Asia/Tokyo")
        let boundary = try Fixture.instant("2026-10-14T04:00:00+09:00")
        let justBefore = boundary.addingTimeInterval(-0.001)

        #expect(
            try PracticeDay(instant: justBefore, timeZone: zone) == (Fixture.day("2026-10-13")),
        )
        #expect(try PracticeDay(instant: boundary, timeZone: zone) == (Fixture.day("2026-10-14")))
    }

    @Test
    func `the same instant takes its day from the zone passed in`() throws {
        // 05:00 in Tokyo, 13:00 the previous day in Los Angeles, 20:00 UTC.
        let instant = try Fixture.instant("2026-10-13T20:00:00Z")

        let inTokyo = try PracticeDay(instant: instant, timeZone: Fixture.zone("Asia/Tokyo"))
        let inLosAngeles = try PracticeDay(
            instant: instant,
            timeZone: Fixture.zone("America/Los_Angeles"),
        )
        let inUTC = try PracticeDay(instant: instant, timeZone: Fixture.zone("UTC"))

        #expect(try inTokyo == (Fixture.day("2026-10-14")))
        #expect(try inLosAngeles == (Fixture.day("2026-10-13")))
        #expect(try inUTC == (Fixture.day("2026-10-13")))
    }

    @Test
    func `the day starts at 04:00`() {
        #expect(PracticeDay.boundaryHour == 4)
    }
}
