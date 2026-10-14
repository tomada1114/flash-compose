/// Every preference key the app stores, in one place.
///
/// These names are contract: a stored key outlives the build that wrote it. Renaming one
/// resets every user's value to its default, because the new name reads as unset. A
/// rename is therefore a migration in Core that reads the old key and writes the new one,
/// with a test that starts from the old key (`docs/architecture.md` › What is contract
/// and what is private). `PreferenceKeysTests` pins each name and default.
public enum PreferenceKeys {
    /// The topic ids turned off in the scope, sorted and joined by `,`
    /// (``ScopeSelection/encodedTopicsOff``). Empty, everything on, until the learner
    /// turns one off.
    public static let scopeTopicsOff = PreferenceKey<String>(
        name: "scope.topicsOff",
        defaultValue: "",
    )

    /// The levels turned off in the scope, sorted numerically and joined by `,`
    /// (``ScopeSelection/encodedLevelsOff``). Empty, everything on, until the learner
    /// turns one off.
    public static let scopeLevelsOff = PreferenceKey<String>(
        name: "scope.levelsOff",
        defaultValue: "",
    )
}
