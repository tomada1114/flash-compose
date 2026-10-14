import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Synchronization

/// A catalog loader that fails a set number of times, then succeeds: E1, then a retry.
final class FlakyCatalog: Sendable {
    private let failuresLeft: Mutex<Int>
    private let catalog: CardCatalog

    init(_ catalog: CardCatalog, failures: Int) {
        self.catalog = catalog
        failuresLeft = Mutex(failures)
    }

    func load() throws(CatalogError) -> CardCatalog {
        let fails = failuresLeft.withLock { left -> Bool in
            left -= 1
            return left >= 0
        }
        if fails {
            throw .decodeFailed
        }
        return catalog
    }
}

/// One drill under test: the model, the scope it shares, and the fakes and time it runs
/// over.
@MainActor
struct Drill {
    let model: DrillViewModel
    let scope: ScopeViewModel
    let store: InMemoryProgressStore
    let preferences: InMemoryPreferences
    let time: TestTime

    /// The answers the store recorded, in order.
    var answers: [Answer] {
        get async {
            await store.answers
        }
    }

    /// Reveals the card on screen and grades it.
    func answer(_ grade: Grade) async {
        model.reveal()
        await model.grade(grade)
    }
}

/// What a drill is built over; every field has the default most tests want.
struct DrillSetup {
    var cards: [Card]
    var progress: [CardProgress] = []
    var start = DrillFixture.morning
    var zone = DrillFixture.tokyo
    var locale = Locale(identifier: "en_US")
    var catalog: (@Sendable () async throws(CatalogError) -> CardCatalog)?
    var preferences = InMemoryPreferences()

    /// The drill, not yet started.
    @MainActor
    func build() throws -> Drill {
        let time = try TestTime(DomainValuesFixture.instant(start), zone: zone)
        let store = InMemoryProgressStore(progress: progress)
        let scope = ScopeViewModel(preferences: preferences, locale: locale)
        let shipped = DrillFixture.catalog(cards)
        let model = DrillViewModel(
            store: store,
            scope: scope,
            now: { time.date },
            environment: DrillEnvironment(
                timeZone: { time.zone },
                locale: locale,
                clock: time.clock,
                generator: SeededGenerator(seed: QueueDriver.seed),
                loadCatalog: catalog ?? { shipped },
                tuning: .default,
            ),
        )
        return Drill(model: model, scope: scope, store: store, preferences: preferences, time: time)
    }

    /// The drill, started.
    @MainActor
    func started() async throws -> Drill {
        let drill = try build()
        await drill.model.start()
        return drill
    }
}

/// Shared values for the drill suites.
enum DrillFixture {
    typealias Day = DomainValuesFixture

    static let tokyo = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
    /// 2026-10-13 09:00 in Tokyo: practice day 2026-10-13 (Example 1).
    static let morning = "2026-10-13T09:00:00+09:00"
    static let today = "2026-10-13"
    static let tomorrow = "2026-10-14"

    /// A catalog of `cards` with the shipped topics' names and the ten levels.
    static func catalog(_ cards: [Card]) -> CardCatalog {
        CardCatalog(
            cards: cards,
            topics: ScopeFixture.topics.map { topic in
                TopicDefinition(id: topic.id, name: topic.name, subtopics: [])
            },
            levels: ScopeFixture.levels.map { level in
                LevelDefinition(level: level.level, toeic: level.toeicLabel, cefr: "", summary: "")
            },
            grammarTags: [],
            retiredIDs: [],
        )
    }

    /// `count` cards in the daily topic at level 1, numbered from `first`.
    static func cards(_ count: Int, from first: Int) throws -> [Card] {
        try QueueFixture.cards(first ..< first + count)
    }

    /// Progress for `card`, last moved on `last` and due on `due`.
    static func progress(_ card: Card, last: String, due: String) throws -> CardProgress {
        try QueueFixture.progress(card, last: last, due: due)
    }

    /// Progress for each card, last moved a week ago and due today.
    static func dueToday(_ cards: [Card]) throws -> [CardProgress] {
        try cards.map { try progress($0, last: "2026-10-06", due: today) }
    }

    /// The practice day a `"YYYY-MM-DD"` string names.
    static func day(_ iso: String) throws -> PracticeDay {
        try Day.day(iso)
    }
}
