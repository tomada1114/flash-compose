import FlashComposeCore
import Foundation
import Testing

/// REQ-006: the header's three counts and the pile underlined change as
/// `docs/product/ux-flows.md` §2 states, in the same update as the card.
@MainActor
@Suite("Drill counts")
struct DrillCountsTests {
    typealias Fixture = DrillFixture

    @Test
    func `a new card's first grade takes it out of 新規`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(4, from: 0)).started()
        await drill.answer(.again)
        #expect(drill.model.counts == HeaderCounts(new: 3, review: 0, reAsk: 1, currentPile: .new))
    }

    @Test(arguments: [Grade.again, .hard, .good])
    func `a due review's first grade takes it out of 復習`(grade: Grade) async throws {
        let reviews = try Fixture.cards(3, from: 0)
        var setup = try DrillSetup(cards: reviews + Fixture.cards(2, from: 10))
        setup.progress = try Fixture.dueToday(reviews)
        let drill = try await setup.started()
        #expect(drill.model.counts == HeaderCounts(
            new: 2,
            review: 3,
            reAsk: 0,
            currentPile: .review,
        ))
        await drill.answer(grade)
        let waiting = grade == .good ? 0 : 1
        #expect(
            drill.model.counts
                == HeaderCounts(new: 2, review: 2, reAsk: waiting, currentPile: .review),
        )
    }

    @Test
    func `a new card's first good sets a re-ask`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(3, from: 0)).started()
        await drill.answer(.good)
        #expect(drill.model.counts.reAsk == 1)
        #expect(drill.model.counts.new == 2)
    }

    @Test
    func `the header items read in travel order with the pile underlined`() async throws {
        let reviews = try Fixture.cards(2, from: 0)
        var setup = try DrillSetup(cards: reviews + Fixture.cards(3, from: 10))
        setup.progress = try Fixture.dueToday(reviews)
        let drill = try await setup.started()
        let items = drill.model.header.items
        #expect(items.map(\.pile) == [.new, .review, .reAsk])
        #expect(items.map(\.id) == [.new, .review, .reAsk])
        #expect(items.map(\.count) == ["3", "2", "0"])
        #expect(items.map(\.isCurrent) == [false, true, false])
        #expect(items.map(\.title.english) == ["New", "Review", "Again"])
    }

    @Test
    func `counts are grouped in the drill's locale`() {
        let counts = HeaderCounts(new: 1_820, review: 12, reAsk: 0, currentPile: .review)
        let header = DrillHeader(counts: counts, locale: Locale(identifier: "en_US"))
        #expect(header.items.first?.count == "1,820")
    }

    /// The spoken header, in the glossary's words (`docs/design/ux-guidelines.md` ›
    /// Accessibility targets).
    @Test
    func `the spoken header reads the counts and the card's pile in both languages`() throws {
        let counts = HeaderCounts(new: 1_820, review: 12, reAsk: 0, currentPile: .review)
        let label = DrillHeader(counts: counts, locale: Locale(identifier: "en_US"))
            .accessibilityLabel
        #expect(label.english == "New 1,820, Review 12, Again 0. This card is a review")
        #expect(
            try CatalogJapanese.render(label.key, ["1,820", "12", "0"])
                == "新規 1,820、復習 12、もう一度 0。このカードは復習",
        )
    }

    @Test(arguments: [
        (DrillPile?.some(.new), "New 1, Review 2, Again 3. This card is new"),
        (DrillPile?.some(.reAsk), "New 1, Review 2, Again 3. This card is an Again card"),
        (DrillPile?.none, "New 1, Review 2, Again 3"),
    ])
    func `the spoken header names each pile, and none on the done face`(
        pile: DrillPile?,
        english: String,
    ) {
        let counts = HeaderCounts(new: 1, review: 2, reAsk: 3, currentPile: pile)
        let header = DrillHeader(counts: counts, locale: Locale(identifier: "en_US"))
        #expect(header.accessibilityLabel.english == english)
        #expect(header.items.contains(where: \.isCurrent) == (pile != nil))
    }

    @Test
    func `the model's header follows its counts`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(2, from: 0)).started()
        #expect(drill.model.header.accessibilityLabel
            .english == "New 2, Review 0, Again 0. This card is new")
    }

    /// Progress under an id the catalog no longer has is never counted.
    @Test
    func `a progress row for a retired id is ignored`() async throws {
        let shipped = try Fixture.cards(2, from: 0)
        let retired = try QueueFixture.card(50)
        var setup = DrillSetup(cards: shipped)
        setup.progress = try Fixture.dueToday([retired])
        let drill = try await setup.started()
        #expect(drill.model.counts == HeaderCounts(new: 2, review: 0, reAsk: 0, currentPile: .new))
    }
}
