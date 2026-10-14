import Foundation

/// When the next practice day starts: the next 04:00 on the wall clock of a zone.
enum PracticeDayBoundary {
    /// How long to wait when the calendar finds no next 04:00, which it always does for a
    /// real zone: an hour, after which the watch asks again.
    private static let fallbackWait: TimeInterval = 3_600

    /// The first instant after `instant` at which the wall clock in `timeZone` reads
    /// 04:00:00 — the moment ``PracticeDay/init(instant:timeZone:)`` moves to a new day.
    /// On a day whose 04:00 a daylight-saving change skips, the first instant after it.
    static func next(after instant: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let boundary = DateComponents(hour: PracticeDay.boundaryHour, minute: 0, second: 0)
        return calendar.nextDate(after: instant, matching: boundary, matchingPolicy: .nextTime)
            ?? instant.addingTimeInterval(fallbackWait)
    }
}

/// What the drill reads from the world rather than decides — the time zone, the locale
/// it words dates and counts in, a clock to wait and measure on, the random draw of a new
/// card, the catalog, and the tunables — gathered so `App/` takes every default and a
/// test pins each one (`designing-core-logic`).
///
/// The current instant is not here: ``AppModel`` hands one `now` to every view model that
/// stamps a value, so a test pins it once.
public struct DrillEnvironment {
    /// The time zone current at a given moment, read at each answer and each day check:
    /// the practice day follows the phone's zone at the moment of each answer
    /// (`docs/product/requirements.md` §4), so a trip mid-session moves it.
    public var timeZone: @Sendable () -> TimeZone
    /// The locale counts are grouped and days are worded in.
    public var locale: Locale
    /// The clock the 04:00 watch sleeps on and the seconds-to-reveal are measured with:
    /// a monotonic one, so a wall-clock change neither wakes the watch early nor makes a
    /// reveal take negative time.
    public var clock: any Clock<Duration>
    /// The generator a new card is drawn with.
    public var generator: any RandomNumberGenerator
    /// Decodes the whole catalog, or fails; a test hands in a small or a failing one.
    public var loadCatalog: @Sendable () async throws(CatalogError) -> CardCatalog
    /// The scheduler's and the queue's tunables.
    public var tuning: Tuning

    /// The app's environment by default: the current zone and locale, a continuous clock,
    /// the system generator, the bundled catalog, and the shipped tunables.
    public init(
        timeZone: @escaping @Sendable () -> TimeZone = { TimeZone.current },
        locale: Locale = .current,
        clock: any Clock<Duration> = ContinuousClock(),
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        loadCatalog: @escaping @Sendable () async throws(CatalogError) -> CardCatalog = {
            try await CatalogLoader.load()
        },
        tuning: Tuning = .default,
    ) {
        self.timeZone = timeZone
        self.locale = locale
        self.clock = clock
        self.generator = generator
        self.loadCatalog = loadCatalog
        self.tuning = tuning
    }
}

extension Clock where Duration == Swift.Duration {
    /// The time since this call, measured on this clock: what the seconds-to-reveal read.
    /// A member rather than a generic function, so a clock held as `any Clock<Duration>`
    /// opens to call it.
    func stopwatch() -> @Sendable () -> Duration {
        let start = now
        return { start.duration(to: now) }
    }
}
