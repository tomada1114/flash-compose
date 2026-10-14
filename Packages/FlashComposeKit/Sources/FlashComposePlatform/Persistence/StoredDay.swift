import FlashComposeCore

/// How a ``FlashComposeCore/PracticeDay`` is stored: one integer that reads as the date,
/// `20261014` for 2026-10-14.
///
/// One column per day rather than three keeps a row's days readable in a database
/// browser and sortable as numbers. A stored value whose parts name no date is rejected by
/// ``FlashComposeCore/PracticeDay/init(year:month:day:)`` and reported as a corrupted
/// record, never rolled over into another day.
enum StoredDay {
    private static let yearPlace = 10_000
    private static let monthPlace = 100

    static func value(of day: PracticeDay) -> Int {
        day.year * yearPlace + day.month * monthPlace + day.day
    }

    static func day(from value: Int) throws(ProgressStoreError) -> PracticeDay {
        do {
            return try PracticeDay(
                year: value / yearPlace,
                month: value % yearPlace / monthPlace,
                day: value % monthPlace,
            )
        } catch {
            throw .corruptedRecord
        }
    }
}
