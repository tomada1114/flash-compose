import Foundation
import Observation

/// Whether the drill's start-up shows a progress indicator (`docs/design/ux-guidelines.md`
/// › States): the root's plain background first, a centred indicator only once the
/// start-up has run past ``StartupIndicatorTuning/delay``, and then for at least
/// ``StartupIndicatorTuning/minimumDisplay`` even if the drill is ready sooner.
///
/// Its own model rather than part of ``DrillViewModel``, because it is about what the
/// screen shows while nothing has loaded, not about the drill: it reads only the drill's
/// ``DrillViewModel/phase``. Built once by ``AppModel`` over the shared drill.
///
/// Action-shaped: the view calls ``watch()`` from `.task` on its first frame, beside the
/// drill's ``DrillViewModel/start()``, and shows the indicator while ``isVisible``.
@MainActor
@Observable
public final class StartupIndicator {
    /// Whether the indicator has appeared; it never appears again once it has.
    private var hasAppeared = false
    /// Whether the indicator is inside its minimum time on screen.
    private var isHolding = false

    private let drill: DrillViewModel
    private let clock: any Clock<Duration>
    private let tuning: StartupIndicatorTuning

    /// Whether the screen shows the indicator in place of the drill: once it has
    /// appeared, while the drill is still starting or the minimum time has not passed.
    public var isVisible: Bool {
        hasAppeared && (isHolding || drill.phase == .starting)
    }

    /// Builds the indicator over `drill`, waiting on `clock`; nothing waits until
    /// ``watch()``.
    public init(
        drill: DrillViewModel,
        clock: any Clock<Duration> = ContinuousClock(),
        tuning: StartupIndicatorTuning = Tuning.default.startupIndicator,
    ) {
        self.drill = drill
        self.clock = clock
        self.tuning = tuning
    }

    /// Waits the delay; if the drill is still starting, shows the indicator and holds it
    /// for the minimum time. Does nothing once the indicator has appeared, so a view
    /// appearing again never shows it a second time.
    public func watch() async {
        guard !hasAppeared else {
            return
        }
        do {
            try await clock.sleep(for: tuning.delay)
        } catch {
            // Cancelled: the view that started the watch has gone.
            return
        }
        guard drill.phase == .starting else {
            return
        }
        hasAppeared = true
        isHolding = true
        // Cancelled or not, the hold ends here, so a view that returns shows the drill.
        try? await clock.sleep(for: tuning.minimumDisplay)
        isHolding = false
    }
}
