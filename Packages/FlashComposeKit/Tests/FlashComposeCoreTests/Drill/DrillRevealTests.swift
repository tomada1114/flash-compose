import FlashComposeCore
import Foundation
import Testing

/// REQ-002: the reveal shows the answer face once and measures how long the question was
/// on screen, on the injected clock.
@MainActor
@Suite("Drill reveal")
struct DrillRevealTests {
    typealias Fixture = DrillFixture

    @Test
    func `the reveal shows the answer and the grade keeps the seconds to it`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(3, from: 0)).started()
        drill.time.advance(by: .milliseconds(2_500))
        drill.model.reveal()
        #expect(drill.model.phase == .ready(.answer))
        await drill.model.grade(.good)
        #expect(await drill.answers.map(\.secondsToReveal) == [2.5])
    }

    @Test
    func `a second reveal does not measure again`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(3, from: 0)).started()
        drill.time.advance(by: .milliseconds(2_500))
        drill.model.reveal()
        drill.time.advance(by: .seconds(3))
        drill.model.reveal()
        #expect(drill.model.phase == .ready(.answer))
        await drill.model.grade(.good)
        #expect(await drill.answers.map(\.secondsToReveal) == [2.5])
    }

    @Test
    func `each card's seconds are measured from when it was dealt`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(3, from: 0)).started()
        drill.time.advance(by: .seconds(4))
        await drill.answer(.good)
        drill.time.advance(by: .seconds(1))
        await drill.answer(.good)
        #expect(await drill.answers.map(\.secondsToReveal) == [4, 1])
    }

    @Test
    func `the reveal does nothing before the start-up`() throws {
        let drill = try DrillSetup(cards: Fixture.cards(1, from: 0)).build()
        drill.model.reveal()
        #expect(drill.model.phase == .starting)
    }

    /// No grade is possible from D1 (`docs/product/ux-flows.md` D1).
    @Test
    func `a grade on the question face does nothing`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(2, from: 0)).started()
        let card = drill.model.card
        await drill.model.grade(.good)
        #expect(drill.model.phase == .ready(.question))
        #expect(drill.model.card == card)
        #expect(await drill.answers.isEmpty)
    }

    @Test
    func `the reveal button and the alternatives read as the copy says`() {
        #expect(DrillStrings.showAnswer.english == "Show answer")
        #expect(DrillStrings.alternatives.english == "Alternatives")
    }
}
