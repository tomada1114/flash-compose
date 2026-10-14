import Foundation
import Observation

/// The app's model: the view models every scene shares, built once over the ports.
///
/// `App/` builds it once, from the adapters it chose, and hands it the **ports** through
/// this initializer; the root view reads the shared models from it. That keeps the
/// wiring — which model is built over which port, and which models share the scope — in
/// Core, where `AppModelTests` and the coverage floor see it, rather than in `App/` or in
/// `FlashComposeUI`, which may not import the adapters (`docs/architecture.md` ›
/// Composition root). A pushed screen that needs a view model of its own gets a named
/// `make…ViewModel(…)` factory here; none exists while ``AppRoute`` has no case.
///
/// Not a service locator: there is no registry, no lookup by type, and no global. Every
/// dependency is a named stored property set from this initializer.
///
/// It is app-level, never per scene: what it holds is what every window shows. Which
/// screens a window has pushed is that window's own ``NavigationModel``.
@MainActor
@Observable
public final class AppModel {
    /// The scope every scene shares, built over `preferences`: the sheet renders it, and
    /// the queue and the drill read its ``ScopeViewModel/selection``, so all three see one
    /// value.
    public let scope: ScopeViewModel

    /// The drill every scene shows, built over `progressStore` and the shared ``scope``,
    /// so its new cards come from the selection the sheet edits and the sheet's count
    /// follows its grades.
    public let drill: DrillViewModel

    /// Whether the drill's start-up shows a progress indicator, built over ``drill`` and
    /// waiting on the drill environment's clock.
    public let startupIndicator: StartupIndicator

    /// Builds the shared view models over `preferences` and `progressStore`. Nothing is
    /// read until the drill's `start()`: construction stays free of side effects.
    ///
    /// `now` reaches every view model that stamps a new value, so a test pins it here
    /// once; `drillEnvironment` holds the rest of what the drill reads from the world —
    /// the time zone, the locale the scope and the drill format in, the clock, the random
    /// generator, and the catalog. `preferences` and `progressStore` have no default: a
    /// composition root that forgot to wire one would otherwise compile and silently stop
    /// remembering the learner's scope or grades.
    public init(
        preferences: any PreferencesStoring,
        progressStore: any ProgressStore,
        now: @escaping @Sendable () -> Date = { Date() },
        drillEnvironment: DrillEnvironment = DrillEnvironment(),
    ) {
        scope = ScopeViewModel(preferences: preferences, locale: drillEnvironment.locale)
        drill = DrillViewModel(
            store: progressStore,
            scope: scope,
            now: now,
            environment: drillEnvironment,
        )
        startupIndicator = StartupIndicator(
            drill: drill,
            clock: drillEnvironment.clock,
            tuning: drillEnvironment.tuning.startupIndicator,
        )
    }
}
