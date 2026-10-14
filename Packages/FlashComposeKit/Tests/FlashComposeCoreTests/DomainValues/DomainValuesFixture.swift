import FlashComposeCore
import Foundation

/// Shared builders for the domain-value suites.
///
/// Dates and instants are written as ISO-8601 strings — `"2026-10-14"`,
/// `"2026-10-14T01:30:00+09:00"` — so every expected value is a literal worked out by
/// hand, with its UTC offset spelled out, rather than one the code under test computed.
enum DomainValuesFixture {
    /// Why a fixture string could not be read; a typo in a test, never a product failure.
    enum FixtureError: Error {
        case notADate(String)
        case unknownZone(String)
    }

    /// The year, month, and day a `"YYYY-MM-DD"` string spells, unvalidated.
    struct DateParts {
        let year: Int
        let month: Int
        let day: Int
    }

    /// The arbitrary but distinct numbers ``state(last:due:)`` uses.
    static let stability = 3.25
    static let difficulty = 5.5
    static let reps = 2
    static let lapses = 1

    /// The parts of a `"YYYY-MM-DD"` string, unvalidated, so a test can hand an
    /// impossible date to ``PracticeDay/init(year:month:day:)``.
    static func components(_ iso: String) throws -> DateParts {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
            .compactMap { Int($0) }
        let middle = parts.dropFirst().dropLast()
        guard let year = parts.first, let month = middle.first, let day = parts.last,
              middle.count == 1
        else {
            throw FixtureError.notADate(iso)
        }
        return DateParts(year: year, month: month, day: day)
    }

    /// The practice day a `"YYYY-MM-DD"` string names.
    static func day(_ iso: String) throws -> PracticeDay {
        let parts = try components(iso)
        return try PracticeDay(year: parts.year, month: parts.month, day: parts.day)
    }

    /// The instant an ISO-8601 timestamp with an explicit UTC offset names.
    static func instant(_ iso: String) throws -> Date {
        try Date(iso, strategy: .iso8601)
    }

    /// The IANA zone `identifier` names.
    static func zone(_ identifier: String) throws -> TimeZone {
        guard let zone = TimeZone(identifier: identifier) else {
            throw FixtureError.unknownZone(identifier)
        }
        return zone
    }

    /// A card id from a string the test knows is well formed.
    static func cardID(_ raw: String) throws -> CardID {
        try CardID(raw)
    }

    /// An FSRS state whose numbers are arbitrary but distinct, so a field swapped for
    /// another would show.
    static func state(last: String, due: String) throws -> FSRSState {
        try FSRSState(
            stability: stability,
            difficulty: difficulty,
            reps: reps,
            lapses: lapses,
            lastDay: day(last),
            dueDay: day(due),
        )
    }

    /// Compiles only when `T` is `Sendable`: the proof REQ-008 asks for is that this call
    /// type-checks, so it needs no runtime assertion.
    static func requireSendable(_: (some Sendable).Type) -> Bool {
        true
    }
}
