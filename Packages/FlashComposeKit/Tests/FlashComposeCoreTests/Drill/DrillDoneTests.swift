import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

/// REQ-008 and REQ-010: the done face (D3) when nothing is left, with the next review day
/// and the never-seen cards outside the scope; widening the scope turns it into a
/// question.
@MainActor
@Suite("Drill done")
struct DrillDoneTests {
    typealias Fixture = DrillFixture

    /// Example 6's starting point: two seen cards in the travel-only scope, due on the
    /// 15th and the 20th, and 400 never-seen cards outside it.
    private static func travelOnly() throws -> DrillSetup {
        let travel = try (0 ..< 2).map { index in
            try QueueFixture.card(index, topic: ScopeFixture.travel, level: 1)
        }
        var setup = try DrillSetup(cards: travel + Fixture.cards(400, from: 10))
        setup.progress = try [
            Fixture.progress(travel[0], last: "2026-10-10", due: "2026-10-15"),
            Fixture.progress(travel[1], last: "2026-10-10", due: "2026-10-20"),
        ]
        setup.preferences.set("daily,social,tech,work", for: PreferenceKeys.scopeTopicsOff)
        return setup
    }

    @Test
    func `doneFaceShowsTheNextReviewAndTheCardsOutsideTheScope`() async throws {
        let drill = try await Self.travelOnly().started()
        #expect(drill.model.phase == .ready(.done))
        #expect(drill.model.card == nil)
        #expect(drill.model.counts == HeaderCounts(new: 0, review: 0, reAsk: 0, currentPile: nil))
        #expect(drill.model.header.items.allSatisfy { !$0.isCurrent })
        #expect(try drill.model.nextReviewDay == Fixture.day("2026-10-15"))
        #expect(drill.model.nextReviewText?.english == "Next review: Thu, Oct 15")
        #expect(drill.model.outsideScopeText?.english == "Unseen outside the scope: 400")
        #expect(DrillStrings.doneTitle.english == "Done for today")
        #expect(DrillStrings.changeScope.english == "Change scope…")
    }

    /// Example 6's second half (`docs/product/ux-flows.md` F3).
    @Test
    func `doneBecomesQuestion`() async throws {
        let drill = try await Self.travelOnly().started()
        drill.scope.toggle(ScopeFixture.daily)
        drill.model.scopeDidChange()
        #expect(drill.model.phase == .ready(.question))
        #expect(drill.model.card?.pile == .new)
        #expect(drill.model.card?.card.topic == ScopeFixture.daily)
        #expect(drill.model.counts == HeaderCounts(
            new: 400,
            review: 0,
            reAsk: 0,
            currentPile: .new,
        ))
        #expect(drill.model.nextReviewText == nil)
        #expect(drill.model.outsideScopeText == nil)
    }

    @Test
    func `a scope change with nothing new in it leaves the done face`() async throws {
        let drill = try await Self.travelOnly().started()
        drill.scope.toggle(ScopeFixture.work)
        drill.model.scopeDidChange()
        #expect(drill.model.phase == .ready(.done))
        #expect(drill.model.outsideScopeText?.english == "Unseen outside the scope: 400")
    }

    /// F4: grading the last card in scope, and its re-asks, reaches the done face.
    @Test
    func `the last card in scope graded leads to the done face`() async throws {
        let travel = try QueueFixture.card(0, topic: ScopeFixture.travel, level: 1)
        let setup = try DrillSetup(cards: [travel] + Fixture.cards(3, from: 10))
        setup.preferences.set("daily,social,tech,work", for: PreferenceKeys.scopeTopicsOff)
        let drill = try await setup.started()
        #expect(drill.model.card?.card.id == travel.id)
        await drill.answer(.again)
        #expect(drill.model.card?.pile == .reAsk)
        await drill.answer(.good)
        #expect(drill.model.card?.pile == .reAsk)
        await drill.answer(.good)
        #expect(drill.model.face == .done)
        #expect(await drill.model.nextReviewDay == (drill.store.snapshot.first?.state.dueDay))
        #expect(drill.model.outsideScopeText?.english == "Unseen outside the scope: 3")
        #expect(drill.scope.counts == NeverSeenCounts(inScope: 0, outsideScope: 3))
    }

    @Test
    func `once every card has been seen the outside line is left out`() async throws {
        let travel = try QueueFixture.card(0, topic: ScopeFixture.travel, level: 1)
        var setup = DrillSetup(cards: [travel])
        setup.progress = try [Fixture.progress(travel, last: "2026-10-10", due: Fixture.tomorrow)]
        let drill = try await setup.started()
        #expect(drill.model.face == .done)
        #expect(drill.model.outsideScopeText == nil)
        #expect(drill.model.nextReviewText?.english == "Next review: Tomorrow")
    }

    @Test
    func `with no due day anywhere the next-review line is left out`() async throws {
        let setup = try DrillSetup(cards: Fixture.cards(3, from: 0))
        setup.preferences.set("daily", for: PreferenceKeys.scopeTopicsOff)
        let drill = try await setup.started()
        #expect(drill.model.face == .done)
        #expect(drill.model.nextReviewDay == nil)
        #expect(drill.model.nextReviewText == nil)
        #expect(drill.model.outsideScopeText?.english == "Unseen outside the scope: 3")
    }

    @Test
    func `a retired card's due day is not the next review`() async throws {
        let shipped = try QueueFixture.card(0)
        let retired = try QueueFixture.card(50)
        var setup = DrillSetup(cards: [shipped])
        setup.progress = try [
            Fixture.progress(shipped, last: "2026-10-10", due: "2026-10-20"),
            Fixture.progress(retired, last: "2026-10-10", due: Fixture.tomorrow),
        ]
        let drill = try await setup.started()
        #expect(try drill.model.nextReviewDay == Fixture.day("2026-10-20"))
    }

    @Test
    func `the done lines are left out while a card is on screen`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(2, from: 0)).started()
        #expect(drill.model.nextReviewDay == nil)
        #expect(drill.model.nextReviewText == nil)
        #expect(drill.model.outsideScopeText == nil)
    }
}
