import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

/// A value a hook running on the store's actor hands back to the test.
actor SeenFlag {
    private(set) var value = false

    func set(_ newValue: Bool) {
        value = newValue
    }
}

/// REQ-003–REQ-005: a grade is saved in one record call before the next card appears; it
/// moves the schedule only on the card's first answer of the day; a failed save changes
/// nothing.
@MainActor
@Suite("Drill grade")
struct DrillGradeTests {
    typealias Fixture = DrillFixture

    /// Example 1: a new card graded × on a fresh install.
    @Test
    func `firstGradeOfNewCardMovesScheduleAndQueuesReAsk`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(10, from: 0)).started()
        let first = try #require(drill.model.card)
        #expect(drill.model.counts == HeaderCounts(new: 10, review: 0, reAsk: 0, currentPile: .new))
        drill.time.advance(by: .seconds(3))
        await drill.answer(.again)
        let answers = await drill.answers
        try #require(answers.count == 1)
        let answer = answers[0]
        #expect(answer.cardID == first.card.id)
        #expect(answer.grade == .again)
        #expect(answer.kind == .firstOfDay)
        #expect(try answer.practiceDay == Fixture.day(Fixture.today))
        #expect(try answer.gradedAt == DomainValuesFixture.instant("2026-10-13T09:00:03+09:00"))
        #expect(answer.before == nil)
        #expect(try answer.after.dueDay == Fixture.day(Fixture.tomorrow))
        #expect(try answer.after.lastDay == Fixture.day(Fixture.today))
        #expect(answer.after.reps == 1)
        #expect(answer.after.lapses == 0)
        #expect(answer.secondsToReveal == 3)
        let stored = CardProgress(cardID: first.card.id, state: answer.after)
        #expect(await drill.store.snapshot == [stored])
        #expect(drill.model.counts.new == 9)
        #expect(drill.model.counts.reAsk == 1)
        var dealt: [DrillCard] = []
        for _ in 0 ..< 4 {
            try dealt.append(#require(drill.model.card))
            await drill.answer(.hard)
        }
        #expect(!dealt.contains { $0.card.id == first.card.id })
        #expect(drill.model.card?.card.id == first.card.id)
        #expect(drill.model.card?.pile == .reAsk)
    }

    /// Example 2: a re-ask graded ○ moves nothing and lets the card go. The card is a
    /// review here: a card dealt new this session gets one more re-ask from its first ○,
    /// even on a re-ask (#16's queue), as the next test shows.
    @Test
    func `reAskNeverMovesSchedule`() async throws {
        let review = try QueueFixture.card(0)
        var setup = try DrillSetup(cards: [review] + Fixture.cards(10, from: 1))
        setup.progress = try Fixture.dueToday([review])
        let drill = try await setup.started()
        #expect(drill.model.card?.pile == .review)
        await drill.answer(.again)
        for _ in 0 ..< 4 {
            await drill.answer(.good)
        }
        #expect(drill.model.card?.card.id == review.id)
        #expect(drill.model.counts.currentPile == .reAsk)
        #expect(drill.model.card?.gradeOptions.allSatisfy { $0.intervalDays == nil } == true)
        let before = drill.model.counts
        let stored = await drill.store.snapshot
        await drill.answer(.good)
        let answer = try #require(await drill.answers.last)
        #expect(answer.cardID == review.id)
        #expect(answer.kind == .reAsk)
        #expect(answer.before == answer.after)
        #expect(await drill.store.snapshot == stored)
        #expect(drill.model.counts.new == before.new)
        #expect(drill.model.counts.review == before.review)
        #expect(drill.model.counts.reAsk == before.reAsk - 1)
    }

    /// A new card's first ○ calls for one more re-ask, even when it comes on a re-ask
    /// (#16's queue): もう一度 holds, and the schedule still does not move.
    @Test
    func `a new card's first good on its re-ask brings it back once more`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(10, from: 0)).started()
        let first = try #require(drill.model.card)
        await drill.answer(.again)
        for _ in 0 ..< 4 {
            await drill.answer(.again)
        }
        #expect(drill.model.card?.card.id == first.card.id)
        let waiting = drill.model.counts.reAsk
        let stored = await drill.store.snapshot
        await drill.answer(.good)
        #expect(await drill.answers.last?.kind == .reAsk)
        #expect(await drill.store.snapshot == stored)
        #expect(drill.model.counts.reAsk == waiting)
    }

    @Test
    func `doubleTapIgnored`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(5, from: 0)).started()
        let model = drill.model
        await drill.store.onRecord {
            await model.grade(.again)
            await model.grade(.good)
            await model.reveal()
        }
        drill.model.reveal()
        #expect(drill.model.isGrading == false)
        await drill.model.grade(.hard)
        let answers = await drill.answers
        #expect(answers.map(\.grade) == [.hard])
        #expect(drill.model.phase == .ready(.question))
        #expect(drill.model.isGrading == false)
        #expect(drill.model.counts.reAsk == 1)
    }

    @Test
    func `the model is grading while the save is in flight`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(2, from: 0)).started()
        let model = drill.model
        let seen = SeenFlag()
        await drill.store.onRecord {
            await seen.set(model.isGrading)
        }
        await drill.answer(.good)
        #expect(await seen.value == true)
    }

    /// Example 3: the save fails on the answer face of a due review.
    @Test
    func `failedSaveChangesNothing`() async throws {
        let reviews = try Fixture.cards(12, from: 0)
        var setup = try DrillSetup(cards: reviews + Fixture.cards(3, from: 20))
        setup.progress = try Fixture.dueToday(reviews)
        let drill = try await setup.started()
        #expect(drill.model.counts.review == 12)
        drill.model.reveal()
        let card = drill.model.card
        let counts = drill.model.counts
        await drill.store.fail(.record, with: .storageFailure)
        await drill.model.grade(.hard)
        #expect(drill.model.failure == .saveFailed)
        #expect(drill.model.failure?.title.english == "Couldn't save your answer")
        #expect(drill.model.failure?.message.english == "Tap a grade again")
        #expect(drill.model.card == card)
        #expect(drill.model.phase == .ready(.answer))
        #expect(drill.model.counts == counts)
        #expect(await drill.answers.isEmpty)
        #expect(await drill.store.snapshot == setup.progress
            .sorted { $0.cardID.rawValue < $1.cardID.rawValue })
        drill.model.dismissFailure()
        #expect(drill.model.failure == nil)
        await drill.store.succeed(.record)
        await drill.model.grade(.hard)
        #expect(await drill.answers.map(\.grade) == [.hard])
        #expect(await drill.answers.first?.cardID == card?.card.id)
        #expect(drill.model.counts.review == 11)
        #expect(drill.model.counts.reAsk == 1)
        #expect(drill.model.phase == .ready(.question))
    }

    /// The view's task cancelled while a save fails: nothing changes and no alert shows.
    @Test
    func `a cancelled grade whose save fails shows no failure`() async throws {
        let drill = try await DrillSetup(cards: Fixture.cards(2, from: 0)).started()
        await drill.store.fail(.record, with: .storageFailure)
        drill.model.reveal()
        let model = drill.model
        let task = Task { await model.grade(.good) }
        task.cancel()
        await task.value
        #expect(drill.model.failure == nil)
        #expect(drill.model.phase == .ready(.answer))
    }

    /// A card whose progress already moved on this practice day — not a re-ask, but its
    /// first answer of the day is in — moves nothing more.
    @Test
    func `a card already moved today does not move again`() async throws {
        let card = try QueueFixture.card(0)
        var setup = DrillSetup(cards: [card])
        setup.progress = try [Fixture.progress(card, last: Fixture.today, due: Fixture.today)]
        let drill = try await setup.started()
        #expect(drill.model.card?.pile == .review)
        await drill.answer(.good)
        let answer = try #require(await drill.answers.first)
        #expect(answer.kind == .reAsk)
        #expect(answer.before == answer.after)
        #expect(await drill.store.snapshot == setup.progress)
    }

    /// A due review's first answer moves it from its stored state.
    @Test
    func `a due review moves from its stored state`() async throws {
        let card = try QueueFixture.card(0)
        var setup = DrillSetup(cards: [card])
        setup.progress = try Fixture.dueToday([card])
        let drill = try await setup.started()
        await drill.answer(.good)
        let answer = try #require(await drill.answers.first)
        #expect(answer.kind == .firstOfDay)
        #expect(answer.before == setup.progress.first?.state)
        #expect(answer.after.reps == 2)
        #expect(try answer.after.lastDay == Fixture.day(Fixture.today))
        #expect(await drill.store.snapshot.first?.state == answer.after)
    }
}
