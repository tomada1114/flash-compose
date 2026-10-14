import Foundation
import Observation

/// Which screens are pushed: the navigation path as Core state.
///
/// The root view binds its `NavigationStack(path:)` to ``path``, so a pushed link, a deep
/// link, and a test all move through the same value — deep links and state restoration
/// have something to hold on to, and a test drives navigation without a view. One model
/// per navigation stack: a tab-based app keeps one per tab. ``AppRoute`` has no case yet,
/// so the path stays empty and the drill, the root, is what every window shows.
///
/// Owned per scene, in `@State` on `App/`'s scene root, and handed to the root view: the
/// app supports multiple windows, and each navigates on its own. The shared view models
/// it routes between stay app-level, in ``AppModel`` — which is why this model never
/// moves there.
@MainActor
@Observable
public final class NavigationModel {
    /// The pushed routes, root first. Settable because `NavigationStack(path:)` writes it
    /// back when the user goes back; every other change goes through an action below.
    public var path: [AppRoute] = []

    /// Creates a model at the root, with nothing pushed.
    public init() {
        // Nothing to set up: `path` starts empty, and nothing is read until a route arrives.
    }

    /// Returns to the root screen.
    public func popToRoot() {
        path.removeAll()
    }

    /// Opens the screen a deep link names (``DeepLink/destination(for:)``), replacing
    /// whatever is pushed, so the link lands on its screen rather than on top of an
    /// unrelated stack: `flash-compose://` names the drill, the root, so it pops to it.
    ///
    /// A link the app does not understand leaves the path alone and is logged with its
    /// scheme and host only: its path and query can carry anything.
    ///
    /// - Returns: whether the link named a screen.
    @discardableResult
    public func open(_ url: URL) -> Bool {
        guard let destination = DeepLink.destination(for: url) else {
            let scheme = url.scheme ?? "none"
            let host = url.host() ?? "none"
            AppLog.navigation.error(
                "open: rejected scheme=\(scheme, privacy: .public) host=\(host, privacy: .public)",
            )
            return false
        }
        switch destination {
        case .drill:
            path.removeAll()
        }
        return true
    }
}
