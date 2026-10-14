import Foundation

/// The one formatter for a practice day the done screen names (D3): its weekday and date,
/// or tomorrow, in the locale it is handed (`docs/design/ux-guidelines.md` › Formatting).
///
/// Every word comes from Foundation's formatters in that locale, not from the String
/// Catalog: Japanese names tomorrow's weekday (`明日（水）`) where English names none
/// (`Tomorrow`), which no pair of catalog strings taking the same arguments can say.
/// Japanese also puts the weekday in full-width parentheses after the date, where
/// Foundation's own Japanese pattern uses ASCII ones, so that one composition is written
/// here.
public struct DayWording: Sendable {
    /// The parentheses Japanese writes the weekday in, as `docs/design/ux-guidelines.md`
    /// spells them.
    private enum FullWidth {
        static let openingParenthesis = "\u{FF08}"
        static let closingParenthesis = "\u{FF09}"
    }

    /// The hour a day's instant is formatted at: midday, far from any daylight-saving
    /// change, in UTC, so the date never shifts.
    private static let middayHour = 12

    private let locale: Locale

    /// A formatter writing in `locale`; the drill hands it the locale it was built with.
    public init(locale: Locale) {
        self.locale = locale
    }

    /// `day` as the next-review line names it, read on `today`: `明日（水）` / `Tomorrow` for
    /// the day after `today`, otherwise `10月15日（木）` / `Thu, Oct 15`.
    ///
    /// The weekday is the proleptic Gregorian calendar's, as the practice day's date is,
    /// whatever calendar the phone is set to.
    public func text(for day: PracticeDay, today: PracticeDay) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let parts = DateComponents(
            year: day.year,
            month: day.month,
            day: day.day,
            hour: Self.middayHour,
        )
        guard let instant = calendar.date(from: parts) else {
            return day.description
        }
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: .gmt)
        let isTomorrow = day.days(since: today) == 1
        guard locale.language.languageCode == .japanese else {
            return isTomorrow
                ? tomorrow(calendar: calendar)
                : instant.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
        }
        let lead = isTomorrow
            ? tomorrow(calendar: calendar)
            : instant.formatted(style.month(.abbreviated).day())
        let weekday = instant.formatted(style.weekday(.abbreviated))
        return lead + FullWidth.openingParenthesis + weekday + FullWidth.closingParenthesis
    }

    /// The locale's word for the day after today, capitalized as a line's first word.
    private func tomorrow(calendar: Calendar) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .beginningOfSentence
        return formatter.localizedString(from: DateComponents(day: 1))
    }
}
