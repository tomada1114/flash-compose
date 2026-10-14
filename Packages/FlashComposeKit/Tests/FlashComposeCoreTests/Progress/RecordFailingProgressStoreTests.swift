#if DEBUG
    import FlashComposeCore
    import FlashComposeTestSupport
    import Foundation
    import Testing

    /// The Debug-only fault injection behind `-failRecords`: every grade fails to save
    /// (E2), and the start-up still loads, so the drill reaches D2 first.
    @Suite("RecordFailingProgressStore")
    struct RecordFailingProgressStoreTests {
        private static func graded() throws -> (answer: Answer, progress: CardProgress) {
            let card = try CardID("c_2t5h9y9g")
            let day = try PracticeDay(year: 2_026, month: 10, day: 14)
            let state = FSRSState(
                stability: 2.3065,
                difficulty: 2.11810397,
                reps: 1,
                lapses: 0,
                lastDay: day,
                dueDay: day.adding(days: 3),
            )
            let answer = Answer(
                cardID: card,
                gradedAt: Date(timeIntervalSinceReferenceDate: 0),
                practiceDay: day,
                grade: .good,
                kind: .firstOfDay,
                before: nil,
                after: state,
                secondsToReveal: 4.2,
            )
            return (answer, CardProgress(cardID: card, state: state))
        }

        @Test
        func `loading passes through to the wrapped store`() async throws {
            let stored = try Self.graded().progress
            let store = RecordFailingProgressStore(
                wrapping: InMemoryProgressStore(progress: [stored]),
            )

            #expect(try await store.loadProgress() == [stored])
        }

        @Test
        func `a failing load still fails`() async {
            let inner = InMemoryProgressStore()
            await inner.fail(.loadProgress, with: .storageFailure)
            let store = RecordFailingProgressStore(wrapping: inner)

            await #expect(throws: ProgressStoreError.storageFailure) {
                try await store.loadProgress()
            }
        }

        @Test
        func `every record fails as a storage failure and stores nothing`() async throws {
            let inner = InMemoryProgressStore()
            let store = RecordFailingProgressStore(wrapping: inner)
            let graded = try Self.graded()

            #expect(throws: ProgressStoreError.storageFailure) {
                try store.record(answer: graded.answer, progress: graded.progress)
            }
            #expect(await inner.answers.isEmpty)
            #expect(await inner.snapshot.isEmpty)
            #expect(await inner.calls.isEmpty)
        }
    }
#endif
