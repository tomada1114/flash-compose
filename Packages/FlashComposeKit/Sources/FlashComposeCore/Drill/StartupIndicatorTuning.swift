/// When the start-up shows its progress indicator, and for how long
/// (`docs/design/ux-guidelines.md` › States).
///
/// The system launch screen covers most of a cold launch, so a spinner that flashed for
/// a frame would be noise: it waits before showing, and once shown it stays long enough
/// to read as intended rather than as a flicker.
public struct StartupIndicatorTuning: Sendable, Equatable {
    /// The values the UX guidelines settle.
    private enum Default {
        static let delayMilliseconds = 300
        static let minimumDisplayMilliseconds = 500
    }

    /// The values the app ships with: shown after 300 ms, kept at least 500 ms.
    public static let `default` = Self(
        delay: .milliseconds(Default.delayMilliseconds),
        minimumDisplay: .milliseconds(Default.minimumDisplayMilliseconds),
    )

    /// How long after the first frame the start-up may run before the indicator shows:
    /// under it, the plain background is all a person sees, which reads as instant.
    public let delay: Duration
    /// The least time the indicator stays once shown, even if the drill is ready sooner,
    /// so it never blinks on and off.
    public let minimumDisplay: Duration

    /// Gathers the indicator's timing; the app uses ``default``.
    public init(delay: Duration, minimumDisplay: Duration) {
        self.delay = delay
        self.minimumDisplay = minimumDisplay
    }
}
