import FlashComposeCore
import Foundation
import Testing

/// Holds the real bundled catalog to the integrity rules (`docs/architecture.md` › Card
/// catalog). This suite is the gate a card edit passes: a failure names card ids, never
/// card text.
@Suite("Catalog integrity")
struct CatalogIntegrityTests {
    typealias Fixture = CatalogFixture

    /// Applies `change` to `cards/daily/hobbies.json` in a copy of the real catalog and
    /// expects the load to fail as a decode failure.
    static func expectDecodeFailure(_ change: (inout [[String: Any]]) -> Void) async throws {
        let directory = try Fixture.copyOfBundledCatalog()
        defer { Fixture.remove(directory.deletingLastPathComponent()) }
        try Fixture.editArray(at: "cards/daily/hobbies.json", in: directory, change)

        await #expect(throws: CatalogError.decodeFailed) {
            try await CatalogLoader.load(from: directory)
        }
    }

    @Test
    func `every shipped card keeps the integrity rules`() async throws {
        let catalog = try await Fixture.bundled.value
        let violations = CatalogIntegrity.violations(in: catalog)
        #expect(violations.isEmpty, "\(violations.map(\.description))")
    }

    @Test
    func `the catalog holds the counts copied from instant-composition`() async throws {
        let catalog = try await Fixture.bundled.value

        #expect(catalog.cards.count == 1_952)
        #expect(catalog.topics.count == 5)
        #expect(catalog.topics.flatMap(\.subtopics).count == 37)
        #expect(catalog.levels.count == 10)
        #expect(catalog.grammarTags.count == 39)
        #expect(catalog.retiredIDs.count == 77)
        #expect(catalog.retiredIDs.count { $0.replacedBy != nil } == 51)
    }

    @Test
    func `definitions are each listed once`() async throws {
        let catalog = try await Fixture.bundled.value
        let subtopics = catalog.topics.flatMap { topic in
            topic.subtopics.map { subtopic in "\(topic.id.rawValue)/\(subtopic.id.rawValue)" }
        }

        #expect(Set(catalog.topics.map(\.id)).count == catalog.topics.count)
        #expect(Set(subtopics).count == subtopics.count)
        #expect(Set(catalog.grammarTags.map(\.id)).count == catalog.grammarTags.count)
        #expect(Set(catalog.retiredIDs.map(\.id)).count == catalog.retiredIDs.count)
    }

    @Test
    func `the example tombstone keeps its replacement, and no vocabulary id is kept`() async throws {
        let catalog = try await Fixture.bundled.value
        let example = try RetiredCardID(id: CardID("c_4h2v2r6v"), replacedBy: CardID("c_9j5e2g3p"))

        #expect(catalog.retiredIDs.contains(example))
        #expect(!catalog.retiredIDs.contains { $0.id.rawValue.hasPrefix("v_") })
        #expect(!catalog.retiredIDs.contains { $0.replacedBy?.rawValue.hasPrefix("v_") == true })
    }

    // MARK: - The check is not vacuous

    @Test
    func `a duplicated id is reported by id`() async throws {
        let catalog = try await Fixture.bundled.value
        let card = try #require(try catalog.card(id: CardID(Fixture.fishingCardID)))

        let mutated = Fixture.catalog(catalog, cards: catalog.cards + [card])

        let expected = [CatalogViolation(card: card.id, rule: .duplicateID)]
        #expect(CatalogIntegrity.violations(in: mutated) == expected)
    }

    @Test
    func `a retired id still on a card is reported by id`() async throws {
        let catalog = try await Fixture.bundled.value
        let id = try CardID(Fixture.fishingCardID)

        let mutated = Fixture.catalog(
            catalog,
            retiredIDs: catalog.retiredIDs + [RetiredCardID(id: id, replacedBy: nil)],
        )

        let expected = [CatalogViolation(card: id, rule: .retiredID)]
        #expect(CatalogIntegrity.violations(in: mutated) == expected)
    }

    @Test(arguments: [
        (CardMutation.english(""), CatalogViolation.Rule.emptyEnglish),
        (.english("  \n"), .emptyEnglish),
        (.japanese(""), .emptyJapanese),
        (.point(""), .emptyPoint),
        (.alternatives([]), .noAlternative),
        (.grammar(["no-such-tag"]), .unknownGrammarTag),
        (.grammar(["time-and-if-clauses", "no-such-tag"]), .unknownGrammarTag),
        (.topic("no-such-topic"), .unknownTopic),
        (.subtopic("no-such-subtopic"), .unknownSubtopic),
        (.subtopic("meetings"), .unknownSubtopic),
    ])
    func `a card breaking one rule is reported by id`(
        mutation: CardMutation,
        rule: CatalogViolation.Rule,
    ) async throws {
        let catalog = try await Fixture.bundled.value
        let id = try CardID(Fixture.fishingCardID)
        let mutated = Fixture.catalog(catalog, cards: catalog.cards.map { card in
            card.id == id ? mutation.applied(to: card) : card
        })

        let expected = [CatalogViolation(card: id, rule: rule)]
        #expect(CatalogIntegrity.violations(in: mutated) == expected)
    }

    @Test
    func `a level the levels file does not define is reported by id`() async throws {
        let catalog = try await Fixture.bundled.value
        let id = try CardID(Fixture.fishingCardID)

        let mutated = CardCatalog(
            cards: catalog.cards,
            topics: catalog.topics,
            levels: catalog.levels.filter { $0.level.rawValue != 5 },
            grammarTags: catalog.grammarTags,
            retiredIDs: catalog.retiredIDs,
        )

        let expected = CatalogViolation(card: id, rule: .undefinedLevel)
        #expect(CatalogIntegrity.violations(in: mutated).contains(expected))
    }

    @Test
    func `a violation's description names the card id and rule, never its text`() throws {
        let id = try CardID(Fixture.fishingCardID)
        let violation = CatalogViolation(card: id, rule: .emptyEnglish)
        #expect(violation.description == "c_2h3m7c9v: emptyEnglish")
    }

    // MARK: - Mutated files, end to end

    @Test
    func `a card file with a duplicated card fails the check over the loaded files`() async throws {
        let directory = try Fixture.copyOfBundledCatalog()
        defer { Fixture.remove(directory.deletingLastPathComponent()) }
        try Fixture.editArray(at: "cards/daily/hobbies.json", in: directory) { cards in
            if let card = cards.first {
                cards.append(card)
            }
        }

        let catalog = try await CatalogLoader.load(from: directory)

        let id = try CardID(Fixture.fishingCardID)
        let expected = [CatalogViolation(card: id, rule: .duplicateID)]
        #expect(CatalogIntegrity.violations(in: catalog) == expected)
    }

    @Test
    func `a retired-ids file naming a live card fails the check over loaded files`() async throws {
        let directory = try Fixture.copyOfBundledCatalog()
        defer { Fixture.remove(directory.deletingLastPathComponent()) }
        try Fixture.editArray(at: "retired-ids.json", in: directory) { retired in
            retired.append(["id": Fixture.fishingCardID])
        }

        let catalog = try await CatalogLoader.load(from: directory)

        let id = try CardID(Fixture.fishingCardID)
        let expected = [CatalogViolation(card: id, rule: .retiredID)]
        #expect(CatalogIntegrity.violations(in: catalog) == expected)
    }

    @Test(arguments: [11, 0])
    func `a real card file with a level outside 1 to 10 fails to load`(level: Int) async throws {
        try await Self.expectDecodeFailure { cards in cards[0]["level"] = level }
    }

    @Test(arguments: ["c_2h3m7c9", "c_2h3m7c9v\n", "c_2H3M7C9V"])
    func `a real card file with an id outside the format fails to load`(id: String) async throws {
        try await Self.expectDecodeFailure { cards in cards[0]["id"] = id }
    }
}
