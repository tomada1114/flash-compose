import os

/// This app's unified-log entry point: one subsystem, one `Logger` per concern.
///
/// `FlashComposeCore` is allowed to `import os`: it is Apple's logging facility, not a UI or
/// OS-integration framework, and it works unchanged on every platform Core serves, so a
/// logging port would buy nothing and cost every call site an injection
/// (`docs/architecture.md` › Logging). `FlashComposeUI`, `FlashComposePlatform`, and `App/` log
/// through
/// these same loggers, which they already see by importing `FlashComposeCore`.
///
/// Never `print`, `debugPrint`, or `NSLog` under `Sources/` or `App/`: an app launched
/// from the Home Screen has nowhere to send stdout, so those lines vanish exactly when
/// they would matter. `.swiftlint.yml`'s `no_print_in_sources` rejects them. Anything
/// user-derived that reaches a log message is interpolated `.private` — a to-do's title
/// is the user's data; its identifier and a count are not.
public enum AppLog {
    /// The subsystem every logger below is created with: this app's bundle identifier,
    /// and the value `just logs` filters the stream on.
    ///
    /// A literal rather than `Bundle.main.bundleIdentifier`, which answers for the test
    /// runner under `swift test` and for the preview agent in an Xcode preview. It must
    /// equal `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`.
    public static let subsystem = "io.github.tomada1114.FlashCompose"

    /// The to-do list concern: ``TodoListViewModel`` and what it asks of the repository.
    ///
    /// One category per concern, named for the concern rather than for a type, so
    /// `log stream --predicate 'category == "todos"'` narrows the stream to one story.
    /// A new concern adds a `Logger` here instead of building one inline.
    public static let todos = Logger(subsystem: subsystem, category: "todos")

    /// The drill concern: ``DrillViewModel`` failing to start or to save a grade. Only the
    /// failure's Core case is logged, never a card's text or id.
    public static let drill = Logger(subsystem: subsystem, category: "drill")

    /// The persistence concern: opening the store and the adapters that read and write it.
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// The preferences concern: the ``PreferencesStoring`` adapter finding a stored value
    /// of the wrong type. A key's name and a type's name are `.public`; the stored value
    /// itself is never logged.
    public static let preferences = Logger(subsystem: subsystem, category: "preferences")

    /// The navigation concern: ``NavigationModel`` rejecting a deep link. A link's scheme
    /// and host are `.public`; its path and query are never logged, since a URL can carry
    /// user data.
    public static let navigation = Logger(subsystem: subsystem, category: "navigation")
}
