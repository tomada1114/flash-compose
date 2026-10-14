import FlashComposeCore
import Synchronization

/// A ``PreferencesStoring`` that counts every read and write, so a test can show that
/// building a model reads nothing and that a refused toggle writes nothing.
final class CountingPreferences: PreferencesStoring {
    /// Everything the spy holds, behind one lock.
    private struct State {
        var reads = 0
        var writes = 0
        var values: [String: String] = [:]
    }

    private let state = Mutex(State())

    var reads: Int {
        state.withLock { $0.reads }
    }

    var writes: Int {
        state.withLock { $0.writes }
    }

    func value<Value: PreferenceValue>(for key: PreferenceKey<Value>) -> Value {
        state.withLock { current in
            current.reads += 1
            return current.values[key.name] as? Value ?? key.defaultValue
        }
    }

    func set<Value: PreferenceValue>(_ value: Value, for key: PreferenceKey<Value>) {
        state.withLock { current in
            current.writes += 1
            current.values[key.name] = value as? String
        }
    }
}
