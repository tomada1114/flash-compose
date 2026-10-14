import FlashComposeCore
import SwiftUI

/// One window's navigation root: the stack every screen would be pushed onto, its root
/// screen — the drill (`DrillView`) — and the one place a failure is presented
/// (`failureAlert(_:dismiss:)`).
///
/// The app's only `NavigationStack(path:)` lives here, bound to ``NavigationModel/path``.
/// ``AppRoute`` has no case yet, so the stack never pushes and declares no
/// `navigationDestination(for:)`; the first pushed screen adds its route, that
/// destination here with one branch per route, and — when the screen needs a view model
/// of its own — an ``AppModel`` factory, so Core decides what the model is built over and
/// this view never needs an adapter (`docs/architecture.md` › Navigation).
///
/// It owns neither model: `App/` creates the app model once for the app and the
/// navigation model once per scene (both in `@State`), and hands them down. `@Bindable`
/// is only what lets the stack bind to ``NavigationModel/path``, so the back button and a
/// deep link move the same Core state.
public struct RootView: View {
    private let app: AppModel
    @Bindable private var navigation: NavigationModel

    public var body: some View {
        NavigationStack(path: $navigation.path) {
            DrillView(model: app.drill, startup: app.startupIndicator)
        }
        // Outside the stack, so a failure presents over whichever screen is on top: a grade
        // that could not be saved (E2) leaves the drill on the same card under the alert.
        .failureAlert(app.drill.failure) { app.drill.dismissFailure() }
    }

    /// Creates the root over `app` and `navigation`, which the caller owns.
    public init(app: AppModel, navigation: NavigationModel) {
        self.app = app
        self.navigation = navigation
    }
}

#if DEBUG
    #Preview("Drill") {
        RootView(
            app: AppModel(
                preferences: PreviewPreferences(),
                progressStore: PreviewProgressStore(),
            ),
            navigation: NavigationModel(),
        )
    }
#endif
