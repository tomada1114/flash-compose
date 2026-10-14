#if DEBUG
    import FlashComposeCore
    import Synchronization

    /// Preview-only preferences, so a `#Preview` never writes to the real `UserDefaults`.
    ///
    /// `FlashComposeTestSupport`'s fake is test code no shipped module may import, and the
    /// `UserDefaults` adapter lives in `FlashComposePlatform`, which `FlashComposeUI` must not see
    /// —
    /// hence this small copy, compiled into Debug builds only. A final class whose only
    /// stored property is a `Mutex`, so it is checked `Sendable`.
    final class PreviewPreferences: PreferencesStoring {
        private let storage: Mutex<[String: any Sendable]>

        /// Starts empty: every key answers its default.
        init() {
            storage = Mutex([:])
        }

        func value<Value: PreferenceValue>(for key: PreferenceKey<Value>) -> Value {
            storage.withLock { $0[key.name] } as? Value ?? key.defaultValue
        }

        func set<Value: PreferenceValue>(_ value: Value, for key: PreferenceKey<Value>) {
            storage.withLock { $0[key.name] = value }
        }
    }
#endif
