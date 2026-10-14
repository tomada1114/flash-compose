import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

/// REQ-010: a scope change recounts 新規 and keeps the card on screen; the done face's
/// side is in `DrillDoneTests`.
@MainActor
@Suite("Drill scope change")
struct DrillScopeChangeTests {
    typealias Fixture = DrillFixture

    @Test
    func `the card on screen stays and only 新規 is recounted`() async throws {
        let work = try (0 ..< 3)
            .map { try QueueFixture.card($0, topic: ScopeFixture.work, level: 2) }
        let reviews = try Fixture.cards(2, from: 10)
        var setup = DrillSetup(cards: work + reviews)
        setup.progress = try Fixture.dueToday(reviews)
        let drill = try await setup.started()
        await drill.answer(.again)
        let card = drill.model.card
        let before = drill.model.counts
        #expect(before.new == 3)
        drill.scope.toggle(ScopeFixture.work)
        drill.model.scopeDidChange()
        #expect(drill.model.card == card)
        #expect(drill.model.phase == .ready(.question))
        #expect(drill.model.counts.new == 0)
        #expect(drill.model.counts.review == before.review)
        #expect(drill.model.counts.reAsk == before.reAsk)
    }

    @Test
    func `the next new card comes from the new scope`() async throws {
        let daily = try Fixture.cards(3, from: 0)
        let work = try (10 ..< 13).map { index in
            try QueueFixture.card(index, topic: ScopeFixture.work, level: 2)
        }
        let drill = try await DrillSetup(cards: daily + work).started()
        let onScreen = try #require(drill.model.card)
        let off = onScreen.card.topic == ScopeFixture.daily ? ScopeFixture.work : ScopeFixture.daily
        drill.scope.toggle(off)
        drill.model.scopeDidChange()
        for _ in 0 ..< 2 {
            await drill.answer(.good)
            #expect(drill.model.card?.card.topic == onScreen.card.topic)
        }
    }

    @Test
    func `a scope change before the start-up does nothing`() throws {
        let drill = try DrillSetup(cards: Fixture.cards(2, from: 0)).build()
        drill.model.scopeDidChange()
        #expect(drill.model.phase == .starting)
        #expect(drill.model.card == nil)
    }
}
