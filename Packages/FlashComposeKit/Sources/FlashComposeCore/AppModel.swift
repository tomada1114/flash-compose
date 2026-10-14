import Foundation
import Observation

/// The app's model: the view models every scene shares, and one factory per route whose
/// screen needs a view model of its own.
///
/// `App/` builds it once, from the adapters it chose, and hands it the **ports** through
/// this initializer; the root view reads the shared models from it and asks it for a
/// pushed screen's model. That keeps the wiring — which model is built over which port,
/// and what a route's screen shares with the list — in Core, where `AppModelTests` and
/// the coverage floor see it, rather than in `App/` or in a destination `switch` in
/// `FlashComposeUI`, which may not import the adapters (`docs/architecture.md` › Composition
/// root).
///
/// Not a service locator: there is no registry, no lookup by type, and no global. Every
/// dependency is a named stored property set from this initializer, and a route's model
/// is built by a named `make…ViewModel(…)` method.
///
/// It is app-level, never per scene: what it holds is what every window shows. Which
/// screens a window has pushed is that window's own ``NavigationModel``.
@MainActor
@Observable
public final class AppModel {
    /// The to-do list every scene shows, built once over the ports, so two windows show
    /// the same items and a pushed detail screen shows what the list shows.
    public let todoList: TodoListViewModel

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

    /// Builds the shared view models over `repository`, `preferences`, and
    /// `progressStore`. Nothing is read until a view model's own `load()` or `start()`:
    /// construction stays free of side effects.
    ///
    /// `now` and `makeID` reach every view model that stamps a new value, so a test pins
    /// both here once; `drillEnvironment` holds the rest of what the drill reads from the
    /// world — the time zone, the locale the scope and the drill format in, the clock,
    /// the random generator, and the catalog. `preferences` and `progressStore` have no
    /// default, for the reason ``TodoListViewModel/init(repository:preferences:now:makeID:)``
    /// gives.
    public init(
        repository: any TodoRepository,
        preferences: any PreferencesStoring,
        progressStore: any ProgressStore,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        drillEnvironment: DrillEnvironment = DrillEnvironment(),
    ) {
        todoList = TodoListViewModel(
            repository: repository,
            preferences: preferences,
            now: now,
            makeID: makeID,
        )
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

    /// The view model of the screen ``AppRoute/todoDetail(_:)`` pushes for `id`.
    ///
    /// A new model on every call — the pushed screen owns the one it is given — over the
    /// shared ``todoList``, so the detail screen shows the item as the list holds it now,
    /// and a toggle there is the list's toggle.
    public func makeTodoDetailViewModel(id: TodoItem.ID) -> TodoDetailViewModel {
        TodoDetailViewModel(list: todoList, id: id)
    }
}
