import Foundation
import Observation

/// The scope sheet's (S1) view model: the topic and level rows, toggling them, and the
/// live count of never-seen cards the scope holds.
///
/// Built once by ``AppModel`` over the preferences port, reading nothing until
/// ``load(catalog:seenCardIDs:)``; ``selection`` is the one value the queue and the drill
/// read, so they and the sheet never disagree. A toggle saves at once — the sheet has no
/// cancel.
@MainActor
@Observable
public final class ScopeViewModel {
    /// The current selection; everything on until ``load(catalog:seenCardIDs:)``.
    public private(set) var selection = ScopeSelection()
    /// The catalog the rows and the count are built from.
    public private(set) var catalog = ScopeCatalog.empty
    /// The never-seen cards inside and outside ``selection``.
    public private(set) var counts = NeverSeenCounts(inScope: 0, outsideScope: 0)

    @ObservationIgnored private let preferences: any PreferencesStoring
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private var seenCardIDs: Set<CardID> = []

    /// The topic rows, in the catalog's order.
    public var topicRows: [ScopeRow<TopicID>] {
        catalog.topics.map { topic in
            ScopeRow(
                id: topic.id,
                title: topic.name,
                detail: nil,
                isOn: selection.isOn(topic.id),
                isDisabled: !selection.canToggle(topic.id, among: catalog.topicIDs),
            )
        }
    }

    /// The level rows, lowest first.
    public var levelRows: [ScopeRow<Level>] {
        catalog.levels.map { level in
            ScopeRow(
                id: level.level,
                title: "L\(level.level.rawValue)",
                detail: level.toeicLabel,
                isOn: selection.isOn(level.level),
                isDisabled: !selection.canToggle(level.level, among: catalog.levelValues),
            )
        }
    }

    /// The note under the topics section: ``ScopeStrings/pickAtLeastOne`` while exactly
    /// one topic is on, otherwise `nil`.
    public var topicsNote: LocalizedStringResource? {
        topicRows.count(where: \.isOn) == 1 ? ScopeStrings.pickAtLeastOne : nil
    }

    /// The note under the levels section, by the rule ``topicsNote`` gives.
    public var levelsNote: LocalizedStringResource? {
        levelRows.count(where: \.isOn) == 1 ? ScopeStrings.pickAtLeastOne : nil
    }

    /// The live count, or ``ScopeStrings/allShown`` while the scope holds no never-seen
    /// card.
    public var countText: LocalizedStringResource {
        guard counts.inScope > 0 else {
            return ScopeStrings.allShown
        }
        return ScopeStrings.unseenCount(counts.inScope.formatted(.number.locale(locale)))
    }

    /// Builds the model over `preferences`, reading nothing. `locale` formats the count's
    /// grouping; a test pins it.
    public init(preferences: any PreferencesStoring, locale: Locale = .current) {
        self.preferences = preferences
        self.locale = locale
    }

    /// Reads the stored selection against `catalog` and counts the cards `seenCardIDs`
    /// does not hold. Call it again when the progress changes, so the count follows.
    ///
    /// A stored selection that turns off every topic (or every level) of `catalog` reads
    /// as all on; that repair is not written back until the learner's next toggle.
    public func load(catalog: ScopeCatalog, seenCardIDs: Set<CardID>) {
        self.catalog = catalog
        self.seenCardIDs = seenCardIDs
        selection = ScopeSelection.stored(in: preferences)
            .repaired(topics: catalog.topicIDs, levels: catalog.levelValues)
        recount()
    }

    /// Turns `topic` on or off and saves at once; the last topic on is left as it is and
    /// nothing is written.
    public func toggle(_ topic: TopicID) {
        guard selection.toggle(topic, among: catalog.topicIDs) else {
            return
        }
        preferences.set(selection.encodedTopicsOff, for: PreferenceKeys.scopeTopicsOff)
        recount()
    }

    /// Turns `level` on or off and saves at once; the last level on is left as it is and
    /// nothing is written.
    public func toggle(_ level: Level) {
        guard selection.toggle(level, among: catalog.levelValues) else {
            return
        }
        preferences.set(selection.encodedLevelsOff, for: PreferenceKeys.scopeLevelsOff)
        recount()
    }

    private func recount() {
        counts = catalog.neverSeenCounts(in: selection, seenCardIDs: seenCardIDs)
    }
}
