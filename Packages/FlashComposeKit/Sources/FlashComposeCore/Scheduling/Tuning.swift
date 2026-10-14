/// Every number in Core someone might want to tweak, in one place (`designing-core-logic`).
///
/// A type that reads a tunable takes a `Tuning` (or the part of it it needs) in its
/// initializer, defaulting to ``default``, so a test can pass a smaller limit to reach a
/// boundary quickly and a later tweak is one edit here. A domain invariant — what a type
/// means rather than how it is tuned — is a constant on its own type instead.
public struct Tuning: Sendable, Equatable {
    /// The values the app ships with.
    public static let `default` = Self(fsrs: .default, reAsk: .default)

    /// The FSRS-6 scheduler's parameters (`docs/architecture.md` › Scheduling).
    public let fsrs: FSRSTuning
    /// When a graded card comes back within the session (`docs/product/requirements.md`
    /// §3.2).
    public let reAsk: ReAskTuning

    /// Gathers the tunables; the app uses ``default``.
    public init(fsrs: FSRSTuning, reAsk: ReAskTuning) {
        self.fsrs = fsrs
        self.reAsk = reAsk
    }
}
