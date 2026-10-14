import FlashComposeCore
import Foundation
import Synchronization
import Testing

/// A clock whose sleeps wait until the test moves it on, so a test can look at the
/// indicator between its two waits.
private final class ManualClock: Clock {
    struct Instant: InstantProtocol {
        let offset: Duration

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }

        func advanced(by duration: Duration) -> Self {
            Self(offset: offset + duration)
        }

        func duration(to other: Self) -> Duration {
            other.offset - offset
        }
    }

    private struct Sleeper {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct State {
        var now = Duration.zero
        var sleepers: [Sleeper] = []
        var requested: [Duration] = []
    }

    private let state = Mutex(State())

    var now: Instant {
        Instant(offset: state.withLock { $0.now })
    }

    var minimumResolution: Duration {
        .zero
    }

    /// Every sleep asked for, as a duration from the moment it was asked.
    var requested: [Duration] {
        state.withLock { $0.requested }
    }

    func sleep(until deadline: Instant, tolerance _: Duration?) async {
        await withCheckedContinuation { continuation in
            state.withLock { current in
                current.requested.append(deadline.offset - current.now)
                current.sleepers.append(Sleeper(
                    deadline: deadline.offset,
                    continuation: continuation,
                ))
            }
        }
    }

    /// Moves the clock on by `duration`, waking every sleep whose deadline has come.
    func advance(by duration: Duration) {
        let due = state.withLock { current -> [Sleeper] in
            current.now += duration
            let reached = current.now
            let due = current.sleepers.filter { $0.deadline <= reached }
            current.sleepers.removeAll { $0.deadline <= reached }
            return due
        }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }

    /// Returns once some task is sleeping on the clock.
    func waitForSleeper() async {
        while state.withLock({ $0.sleepers.isEmpty }) {
            await Task.yield()
        }
    }
}

/// The start-up's progress indicator (`docs/design/ux-guidelines.md` › States): nothing
/// for the first 300 ms, then a spinner kept at least 500 ms once shown.
@MainActor
@Suite("Start-up indicator")
struct StartupIndicatorTests {
    private static let tuning = StartupIndicatorTuning.default

    private static func indicator(
        over drill: Drill,
        clock: ManualClock,
    ) -> StartupIndicator {
        StartupIndicator(drill: drill.model, clock: clock, tuning: tuning)
    }

    @Test
    func `the shipped timing waits 300 ms and holds 500 ms`() {
        #expect(Self.tuning.delay == .milliseconds(300))
        #expect(Self.tuning.minimumDisplay == .milliseconds(500))
        #expect(Tuning.default.startupIndicator == Self.tuning)
    }

    @Test
    func `a start-up that finishes within the delay never shows the indicator`() async throws {
        let drill = try DrillSetup(cards: DrillFixture.cards(2, from: 0)).build()
        let clock = ManualClock()
        let indicator = Self.indicator(over: drill, clock: clock)
        let watch = Task { await indicator.watch() }

        await clock.waitForSleeper()
        #expect(!indicator.isVisible)
        await drill.model.start()
        clock.advance(by: Self.tuning.delay)
        await watch.value

        #expect(!indicator.isVisible)
        #expect(clock.requested == [Self.tuning.delay])
    }

    @Test
    func `a slow start-up shows the indicator and holds it after the drill is ready`(
    ) async throws {
        let drill = try DrillSetup(cards: DrillFixture.cards(2, from: 0)).build()
        let clock = ManualClock()
        let indicator = Self.indicator(over: drill, clock: clock)
        let watch = Task { await indicator.watch() }

        await clock.waitForSleeper()
        clock.advance(by: Self.tuning.delay)
        await clock.waitForSleeper()
        #expect(indicator.isVisible)

        await drill.model.start()
        #expect(drill.model.phase == .ready(.question))
        #expect(indicator.isVisible, "the indicator stays for its minimum time")

        clock.advance(by: Self.tuning.minimumDisplay)
        await watch.value
        #expect(!indicator.isVisible)
        #expect(clock.requested == [Self.tuning.delay, Self.tuning.minimumDisplay])
    }

    @Test
    func `a start-up still running after the minimum keeps the indicator until it ends`(
    ) async throws {
        let drill = try DrillSetup(cards: DrillFixture.cards(2, from: 0)).build()
        let clock = ManualClock()
        let indicator = Self.indicator(over: drill, clock: clock)
        let watch = Task { await indicator.watch() }

        await clock.waitForSleeper()
        clock.advance(by: Self.tuning.delay)
        await clock.waitForSleeper()
        clock.advance(by: Self.tuning.minimumDisplay)
        await watch.value
        #expect(indicator.isVisible)

        await drill.model.start()
        #expect(!indicator.isVisible)
    }

    @Test
    func `a failed start-up hides the indicator for E1`() async throws {
        var setup = try DrillSetup(cards: DrillFixture.cards(2, from: 0))
        setup.catalog = { () throws(CatalogError) -> CardCatalog in throw .decodeFailed }
        let drill = try setup.build()
        let clock = ManualClock()
        let indicator = Self.indicator(over: drill, clock: clock)
        let watch = Task { await indicator.watch() }

        await clock.waitForSleeper()
        clock.advance(by: Self.tuning.delay)
        await clock.waitForSleeper()
        clock.advance(by: Self.tuning.minimumDisplay)
        await watch.value
        await drill.model.start()

        #expect(drill.model.phase == .failed)
        #expect(!indicator.isVisible)
    }

    @Test
    func `watching again after the indicator has shown waits for nothing`() async throws {
        let drill = try DrillSetup(cards: DrillFixture.cards(2, from: 0)).build()
        let clock = ManualClock()
        let indicator = Self.indicator(over: drill, clock: clock)
        let first = Task { await indicator.watch() }
        await clock.waitForSleeper()
        clock.advance(by: Self.tuning.delay)
        await clock.waitForSleeper()
        clock.advance(by: Self.tuning.minimumDisplay)
        await first.value

        await indicator.watch()

        #expect(clock.requested.count == 2)
        #expect(indicator.isVisible)
    }
}
