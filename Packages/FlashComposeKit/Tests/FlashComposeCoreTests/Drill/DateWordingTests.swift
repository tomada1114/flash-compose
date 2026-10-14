import FlashComposeCore
import Foundation
import Testing

/// The one formatter for a day on the done screen (D3), through the locale it is handed:
/// a weekday and a date, or tomorrow (`docs/design/ux-guidelines.md` › Formatting).
@Suite("DayWording")
struct DateWordingTests {
    typealias Day = DomainValuesFixture

    static let japaneseLocale = Locale(identifier: "ja_JP")
    static let englishLocale = Locale(identifier: "en_US")
    static let referenceDay = "2026-10-13"

    @Test
    func `a later day reads as its weekday and date`() throws {
        let day = try Day.day("2026-10-15")
        let today = try Day.day(Self.referenceDay)
        #expect(DayWording(locale: Self.japaneseLocale).text(for: day, today: today) == "10月15日（木）")
        #expect(DayWording(locale: Self.englishLocale)
            .text(for: day, today: today) == "Thu, Oct 15")
    }

    @Test
    func `the next day reads as tomorrow, with its weekday in Japanese`() throws {
        let day = try Day.day("2026-10-14")
        let today = try Day.day(Self.referenceDay)
        #expect(DayWording(locale: Self.japaneseLocale).text(for: day, today: today) == "明日（水）")
        #expect(DayWording(locale: Self.englishLocale).text(for: day, today: today) == "Tomorrow")
    }

    @Test
    func `a day across a month and a year reads as its own date`() throws {
        let day = try Day.day("2027-01-01")
        let today = try Day.day(Self.referenceDay)
        #expect(DayWording(locale: Self.japaneseLocale).text(for: day, today: today) == "1月1日（金）")
        #expect(DayWording(locale: Self.englishLocale).text(for: day, today: today) == "Fri, Jan 1")
    }

    @Test
    func `the next-review line wraps the day in both languages`() throws {
        let day = try Day.day("2026-10-15")
        let tomorrow = try Day.day("2026-10-14")
        let today = try Day.day(Self.referenceDay)
        let english = DayWording(locale: Self.englishLocale)
        #expect(
            DrillStrings.nextReview(english.text(for: day, today: today)).english
                == "Next review: Thu, Oct 15",
        )
        #expect(
            DrillStrings.nextReview(english.text(for: tomorrow, today: today)).english
                == "Next review: Tomorrow",
        )
        let japanese = DayWording(locale: Self.japaneseLocale)
        let key = DrillStrings.nextReview("").key
        #expect(
            try CatalogJapanese.render(key, [japanese.text(for: day, today: today)])
                == "次の復習：10月15日（木）",
        )
        #expect(
            try CatalogJapanese.render(key, [japanese.text(for: tomorrow, today: today)])
                == "次の復習：明日（水）",
        )
    }
}
