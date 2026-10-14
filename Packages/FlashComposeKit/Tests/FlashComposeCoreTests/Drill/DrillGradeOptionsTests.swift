import FlashComposeCore
import Foundation
import Testing

/// REQ-007: the grade buttons carry the interval each grade would set, from the
/// scheduler's preview, except on a re-ask or a card already answered today; the card's
/// front names its kind, topic, and level.
@MainActor
@Suite("Drill grade options")
struct DrillGradeOptionsTests {
    typealias Fixture = DrillFixture

    @Test
    func `a new card's buttons show the preview's intervals in button order`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(2, from: 0)).started()
        let card = try #require(drill.model.card)
        let preview = try FSRSScheduler().preview(
            nil,
            on: Fixture.day(Fixture.today),
            card: card.card.id,
        )
        #expect(card.gradeOptions.map(\.grade) == [.again, .hard, .good])
        #expect(card.gradeOptions.map(\.id) == [.again, .hard, .good])
        #expect(card.gradeOptions.map(\.symbol) == ["×", "△", "○"])
        #expect(card.gradeOptions.map(\.title.english) == ["Forgot", "Hard", "Got it"])
        #expect(
            card.gradeOptions.map(\.intervalDays)
                == [
                    preview.again.intervalDays,
                    preview.hard.intervalDays,
                    preview.good.intervalDays,
                ],
        )
        #expect(card.gradeOptions.first?.intervalLabel?.english == "1 day")
        #expect(card.gradeOptions.first?.accessibilityLabel.english == "Forgot, next in 1 day")
    }

    @Test
    func `a review's buttons show the preview from its stored state`() async throws {
        let card = try QueueFixture.card(0)
        var setup = DrillSetup(cards: [card])
        setup.progress = try Fixture.dueToday([card])
        let drill = try await setup.started()
        let shown = try #require(drill.model.card)
        let preview = try FSRSScheduler()
            .preview(setup.progress.first?.state, on: Fixture.day(Fixture.today), card: card.id)
        #expect(shown.gradeOptions.map(\.intervalDays) == [
            preview.again.intervalDays, preview.hard.intervalDays, preview.good.intervalDays,
        ])
    }

    @Test
    func `noIntervalsOnReAsk`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(6, from: 0)).started()
        await drill.answer(.again)
        for _ in 0 ..< 4 {
            await drill.answer(.good)
        }
        let card = try #require(drill.model.card)
        #expect(card.pile == .reAsk)
        #expect(card.gradeOptions.allSatisfy { $0.intervalDays == nil && $0.intervalLabel == nil })
        #expect(card.gradeOptions.map(\.accessibilityLabel.english) == ["Forgot", "Hard", "Got it"])
    }

    @Test
    func `no intervals on a card already answered today`() async throws {
        let card = try QueueFixture.card(0)
        var setup = DrillSetup(cards: [card])
        setup.progress = try [Fixture.progress(card, last: Fixture.today, due: Fixture.today)]
        let drill = try await setup.started()
        #expect(drill.model.card?.gradeOptions.allSatisfy { $0.intervalDays == nil } == true)
    }

    @Test
    func `the front names the card's kind, topic, and level`() async throws {
        let card = try QueueFixture.card(0, topic: ScopeFixture.work, level: 5)
        var setup = DrillSetup(cards: [card])
        setup.progress = try Fixture.dueToday([card])
        let drill = try await setup.started()
        let shown = try #require(drill.model.card)
        #expect(shown.topicName == "仕事")
        #expect(shown.kind.english == "Review")
        #expect(shown.kindLine.english == "Review · 仕事 · L5")
        #expect(try CatalogJapanese.render(shown.kindLine.key, ["復習", "仕事", 5]) == "復習 · 仕事 · L5")
    }

    @Test
    func `a topic the catalog does not name shows its id`() async throws {
        let card = try QueueFixture.card(0, topic: TopicID("unnamed"), level: 1)
        let drill = try await DrillSetup(cards: [card]).started()
        #expect(drill.model.card?.topicName == "unnamed")
    }

    @Test
    func `the spoken grade carries the interval in Japanese`() throws {
        let option = GradeOption(grade: .again, intervalDays: 1)
        #expect(
            try CatalogJapanese.render(option.accessibilityLabel.key, ["忘れた", "1日"])
                == "忘れた、次回1日後",
        )
    }
}
