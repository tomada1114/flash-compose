import Foundation
import Synchronization

/// A `Clock` over a ``TestTime``: its instants are offsets from the test's start.
struct TestClock: Clock {
    /// An offset from the start of the test.
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

    let time: TestTime

    var now: Instant {
        Instant(offset: time.elapsed)
    }

    var minimumResolution: Duration {
        .zero
    }

    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        await Task.yield()
        try time.sleep(until: deadline.offset)
    }
}

/// The test's time: the wall clock the drill's `now` reads, the monotonic clock it sleeps
/// and measures on, and the time zone current at each moment — moved together, by hand.
///
/// No test waits: a sleep on ``clock`` records what it was asked for, moves both clocks to
/// its deadline, and returns at once; once the sleeps a test allowed are used up, the next
/// one throws `CancellationError`, as a cancelled `.task` would, so a watch loop ends.
final class TestTime: Sendable {
    /// Everything the time holds, behind one lock.
    private struct State {
        var date: Date
        var elapsed = Duration.zero
        var zone: TimeZone
        var sleeps: [Duration] = []
        var sleepsLeft = 1
    }

    private let state: Mutex<State>

    /// The wall-clock instant now.
    var date: Date {
        state.withLock { $0.date }
    }

    /// The monotonic clock's reading now, from zero at the start.
    var elapsed: Duration {
        state.withLock { $0.elapsed }
    }

    /// The time zone current now.
    var zone: TimeZone {
        state.withLock { $0.zone }
    }

    /// Every sleep the clock was asked for, in order.
    var sleeps: [Duration] {
        state.withLock { $0.sleeps }
    }

    /// The clock the drill sleeps and measures on.
    var clock: TestClock {
        TestClock(time: self)
    }

    /// Starts at `date` in `zone`; one sleep is allowed before the clock throws.
    init(_ date: Date, zone: TimeZone) {
        state = Mutex(State(date: date, zone: zone))
    }

    /// Moves both clocks on by `duration`.
    func advance(by duration: Duration) {
        state.withLock { current in
            current.date = current.date.addingTimeInterval(duration / .seconds(1))
            current.elapsed += duration
        }
    }

    /// Moves to another zone, as a trip would.
    func move(to zone: TimeZone) {
        state.withLock { $0.zone = zone }
    }

    /// Lets `count` more sleeps return before the clock throws.
    func allowSleeps(_ count: Int) {
        state.withLock { $0.sleepsLeft = count }
    }

    /// A sleep until `deadline` on the monotonic clock: recorded, then both clocks move to
    /// it — or `CancellationError` once no sleep is left.
    func sleep(until deadline: Duration) throws {
        let allowed = state.withLock { current -> Bool in
            guard current.sleepsLeft > 0 else {
                return false
            }
            current.sleepsLeft -= 1
            current.sleeps.append(deadline - current.elapsed)
            return true
        }
        guard allowed else {
            throw CancellationError()
        }
        advance(by: deadline - elapsed)
    }
}
