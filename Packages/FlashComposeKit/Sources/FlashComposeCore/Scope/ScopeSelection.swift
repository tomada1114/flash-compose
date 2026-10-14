/// Which topics and levels new cards come from: the topics turned off and the levels
/// turned off (`docs/product/requirements.md` §3.4, `docs/architecture.md` › Scope).
///
/// It records what is **off**, so an empty selection is everything on — the default —
/// and a topic a later catalog adds starts on. It steers new cards only: due reviews
/// come from every topic and level whatever it holds.
///
/// An off-id the current catalog no longer has is kept, so a round trip through storage
/// reads back identically, but it is ignored: it matches no card, and "at least one stays
/// on" is judged over the catalog's ids only.
public struct ScopeSelection: Hashable, Sendable {
    /// The topics new cards do not come from.
    public private(set) var topicsOff: Set<TopicID>
    /// The levels new cards do not come from.
    public private(set) var levelsOff: Set<Level>

    /// ``topicsOff`` as ``PreferenceKeys/scopeTopicsOff`` stores it: the ids sorted
    /// ascending, joined by `,`; `""` when nothing is off.
    public var encodedTopicsOff: String {
        topicsOff.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// ``levelsOff`` as ``PreferenceKeys/scopeLevelsOff`` stores it: the numbers sorted
    /// numerically ascending (`"3,10"`, not `"10,3"`), joined by `,`; `""` when nothing is
    /// off.
    public var encodedLevelsOff: String {
        levelsOff.sorted().map { String($0.rawValue) }.joined(separator: ",")
    }

    /// Creates a selection with `topicsOff` and `levelsOff` turned off; with no arguments,
    /// everything is on.
    public init(topicsOff: Set<TopicID> = [], levelsOff: Set<Level> = []) {
        self.topicsOff = topicsOff
        self.levelsOff = levelsOff
    }

    /// Reads a selection from the two stored strings. A token that does not parse — an
    /// empty one, a number outside ``Level/range``, text where a level belongs — is
    /// dropped, and nothing of the stored text is logged.
    public init(encodedTopicsOff: String, encodedLevelsOff: String) {
        let topics = encodedTopicsOff.split(separator: ",").map { TopicID(String($0)) }
        let levels = encodedLevelsOff.split(separator: ",").compactMap { token -> Level? in
            guard let number = Int(token) else {
                return nil
            }
            return try? Level(number)
        }
        self.init(topicsOff: Set(topics), levelsOff: Set(levels))
    }

    /// The selection `preferences` holds; everything on when nothing is stored.
    public static func stored(in preferences: any PreferencesStoring) -> Self {
        Self(
            encodedTopicsOff: preferences.value(for: PreferenceKeys.scopeTopicsOff),
            encodedLevelsOff: preferences.value(for: PreferenceKeys.scopeLevelsOff),
        )
    }

    /// Whether `card` is one new cards may come from: its topic is on and its level is on.
    public func includes(_ card: Card) -> Bool {
        !topicsOff.contains(card.topic) && !levelsOff.contains(card.level)
    }

    /// Whether `topic` is on.
    public func isOn(_ topic: TopicID) -> Bool {
        !topicsOff.contains(topic)
    }

    /// Whether `level` is on.
    public func isOn(_ level: Level) -> Bool {
        !levelsOff.contains(level)
    }

    /// Whether `topic` can be toggled: always when it is off, and when it is on only if
    /// another of `catalogTopics` stays on, so the last topic on cannot be turned off.
    public func canToggle(_ topic: TopicID, among catalogTopics: [TopicID]) -> Bool {
        !isOn(topic) || catalogTopics.contains { $0 != topic && isOn($0) }
    }

    /// Whether `level` can be toggled, by the rule the topic overload gives:
    /// the last level on cannot be turned off.
    public func canToggle(_ level: Level, among catalogLevels: [Level]) -> Bool {
        !isOn(level) || catalogLevels.contains { $0 != level && isOn($0) }
    }

    /// Turns `topic` off when it is on and on when it is off, unless that would leave no
    /// topic of `catalogTopics` on. Returns whether the selection changed.
    @discardableResult
    public mutating func toggle(_ topic: TopicID, among catalogTopics: [TopicID]) -> Bool {
        guard canToggle(topic, among: catalogTopics) else {
            return false
        }
        if topicsOff.remove(topic) == nil {
            topicsOff.insert(topic)
        }
        return true
    }

    /// Turns `level` off when it is on and on when it is off, unless that would leave no
    /// level of `catalogLevels` on. Returns whether the selection changed.
    @discardableResult
    public mutating func toggle(_ level: Level, among catalogLevels: [Level]) -> Bool {
        guard canToggle(level, among: catalogLevels) else {
            return false
        }
        if levelsOff.remove(level) == nil {
            levelsOff.insert(level)
        }
        return true
    }

    /// This selection with a corrupt half repaired against the current catalog: when it
    /// turns off every topic of `catalogTopics`, topics read as all on, and likewise for
    /// levels. A selection the app wrote can never be in that state; a hand edit or a
    /// catalog that dropped the topics left on can.
    public func repaired(topics catalogTopics: [TopicID], levels catalogLevels: [Level]) -> Self {
        var repaired = self
        if !catalogTopics.isEmpty, !catalogTopics.contains(where: isOn) {
            repaired.topicsOff = []
        }
        if !catalogLevels.isEmpty, !catalogLevels.contains(where: isOn) {
            repaired.levelsOff = []
        }
        return repaired
    }

    /// Writes this selection to `preferences` under its two keys.
    public func store(in preferences: any PreferencesStoring) {
        preferences.set(encodedTopicsOff, for: PreferenceKeys.scopeTopicsOff)
        preferences.set(encodedLevelsOff, for: PreferenceKeys.scopeLevelsOff)
    }
}
