import FlashComposeCore
import FlashComposePlatform
import FlashComposeUI
import SwiftUI

/// One window's root: its own navigation over the app's shared models.
///
/// A scene, not the app, owns the `NavigationModel`: the app supports multiple scenes
/// (two windows on iPad), and a path shared between them would move every window in
/// lockstep, and a deep link would move them all instead of the window it arrived in.
private struct SceneRoot: View {
    let app: AppModel
    @State private var navigation = NavigationModel()

    var body: some View {
        // A `flash-compose://` link (project.yml registers the scheme) goes to Core, which
        // decides what it opens.
        RootView(app: app, navigation: navigation)
            .onOpenURL { navigation.open($0) }
    }
}

/// Application entry point — wiring only. All real code lives in Packages/FlashComposeKit.
///
/// This is also the composition root: the one place that knows both halves of a port.
/// It opens the SwiftData store and the `UserDefaults` preferences through their
/// `FlashComposePlatform` adapters and hands them, as ports, to Core's `AppModel`, which builds
/// every view model over them — the drill over the progress store, the scope over the
/// preferences — so nothing below `App/` depends on which store answers, and `App/`
/// decides nothing but which adapter each port gets (`docs/architecture.md` › Composition
/// root).
@main
struct FlashComposeApp: App {
    /// The launch argument `LaunchUITests` passes: an in-memory store and a scratch
    /// preferences suite, so every UI test run starts empty and at every setting's
    /// default, and leaves nothing behind that the app's own data would see.
    private static let uiTestingArgument = "-uiTesting"

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    #if DEBUG
        /// Debug-only fault injection: every grade fails to save
        /// (`RecordFailingProgressStore`), so E2 can be seen and UI-tested while the
        /// start-up still loads. Release builds neither read the argument nor contain the
        /// type.
        private static let failRecordsArgument = "-failRecords"
    #endif

    /// Owned here, in `@State`, so the model outlives any one scene's view tree and every
    /// window shows the same drill. Navigation is per window (`SceneRoot`).
    @State private var app = Self.makeAppModel()

    var body: some Scene {
        WindowGroup {
            SceneRoot(app: app)
        }
    }

    /// The app model over the progress store and the preferences, built once.
    private static func makeAppModel() -> AppModel {
        AppModel(
            preferences: makePreferences(),
            progressStore: makeProgressStore(),
        )
    }

    /// The progress store the app runs on, over the one container opened once: every
    /// SwiftData adapter is built over this container, never over one of its own. When the
    /// on-disk store cannot be opened, the app still launches — over a null object that
    /// reports every call as failed, so the drill shows E1 — rather than crashing, or
    /// quietly keeping grades in memory that would vanish on the next launch.
    private static func makeProgressStore() -> any ProgressStore {
        let storage: PersistenceStore.Storage = isUITesting ? .inMemory : .onDisk
        do {
            let container = try PersistenceStore.makeContainer(storage: storage)
            let store = SwiftDataProgressStore(modelContainer: container)
            #if DEBUG
                return faultInjected(store)
            #else
                return store
            #endif
        } catch {
            // `makeContainer` has logged the failure; the null object is the handling.
            return UnavailableProgressStore()
        }
    }

    #if DEBUG
        /// `store`, wrapped in its fault injection when its launch argument is present.
        private static func faultInjected(_ store: any ProgressStore) -> any ProgressStore {
            if ProcessInfo.processInfo.arguments.contains(failRecordsArgument) {
                return RecordFailingProgressStore(wrapping: store)
            }
            return store
        }
    #endif

    /// The preferences the app runs on: the standard defaults, or — under UI testing — a
    /// suite of its own, cleared at launch. `just uitest` reuses the simulator, so without
    /// the scratch suite one run's scope would still be narrowed in the next.
    private static func makePreferences() -> any PreferencesStoring {
        if isUITesting {
            return UserDefaultsPreferences.scratch(suiteName: "\(AppLog.subsystem).uiTesting")
        }
        return UserDefaultsPreferences()
    }
}
