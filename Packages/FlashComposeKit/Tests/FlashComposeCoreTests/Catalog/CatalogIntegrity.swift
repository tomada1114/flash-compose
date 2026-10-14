import FlashComposeCore
import Foundation

/// One card breaking one of the catalog's integrity rules (`docs/architecture.md` › Card
/// catalog), named by its id only: a failure message never repeats a card's text.
struct CatalogViolation: Equatable, CustomStringConvertible {
    /// The rule a card breaks. A level outside 1–10 and an id outside the format never
    /// reach this check: `Level` and `CardID` refuse them while the catalog decodes.
    enum Rule: Equatable {
        case duplicateID
        case emptyEnglish
        case emptyJapanese
        case emptyPoint
        case noAlternative
        case retiredID
        case undefinedLevel
        case unknownGrammarTag
        case unknownSubtopic
        case unknownTopic
    }

    let card: CardID
    let rule: Rule

    var description: String {
        "\(card.rawValue): \(rule)"
    }
}

/// The integrity rules every shipped card is held to, as a function over a decoded
/// catalog so a test can hand it a catalog that breaks one rule and see it reported —
/// the proof the check over the real files is not vacuous.
///
/// It is test code on purpose: the runtime loader trusts the files this check passed, so
/// the app never pays for it at launch.
enum CatalogIntegrity {
    /// What a card's references are checked against.
    private struct Definitions {
        let subtopicsByTopic: [TopicID: Set<SubtopicID>]
        let levels: Set<Level>
        let grammarTags: Set<GrammarTagID>

        private static func isBlank(_ text: String) -> Bool {
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private static func textRulesBroken(by card: Card) -> [CatalogViolation.Rule] {
            var rules: [CatalogViolation.Rule] = []
            if isBlank(card.japanese) {
                rules.append(.emptyJapanese)
            }
            if isBlank(card.english) {
                rules.append(.emptyEnglish)
            }
            if isBlank(card.point) {
                rules.append(.emptyPoint)
            }
            if card.alternatives.isEmpty {
                rules.append(.noAlternative)
            }
            return rules
        }

        func rulesBroken(by card: Card) -> [CatalogViolation.Rule] {
            var rules: [CatalogViolation.Rule] = []
            if let subtopics = subtopicsByTopic[card.topic] {
                if !subtopics.contains(card.subtopic) {
                    rules.append(.unknownSubtopic)
                }
            } else {
                rules.append(.unknownTopic)
            }
            if !levels.contains(card.level) {
                rules.append(.undefinedLevel)
            }
            if card.grammar.contains(where: { !grammarTags.contains($0) }) {
                rules.append(.unknownGrammarTag)
            }
            return rules + Self.textRulesBroken(by: card)
        }
    }

    static func violations(in catalog: CardCatalog) -> [CatalogViolation] {
        let pairs = catalog.topics.map { topic in (topic.id, Set(topic.subtopics.map(\.id))) }
        let subtopics = Dictionary(pairs) { first, _ in first }
        let definitions = Definitions(
            subtopicsByTopic: subtopics,
            levels: Set(catalog.levels.map(\.level)),
            grammarTags: Set(catalog.grammarTags.map(\.id)),
        )
        let retired = Set(catalog.retiredIDs.map(\.id))
        var seen: Set<CardID> = []
        var violations: [CatalogViolation] = []
        for card in catalog.cards {
            var rules = definitions.rulesBroken(by: card)
            if !seen.insert(card.id).inserted {
                rules.insert(.duplicateID, at: 0)
            }
            if retired.contains(card.id) {
                rules.insert(.retiredID, at: 0)
            }
            violations += rules.map { CatalogViolation(card: card.id, rule: $0) }
        }
        return violations
    }
}
