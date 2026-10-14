import FlashComposeCore
import Foundation
import Testing

/// The null object `App/` hands the drill when the store cannot be opened: every call
/// fails, so nothing pretends to have been loaded or saved (Example 4).
@Suite("UnavailableProgressStore")
struct UnavailableProgressStoreTests {
    @Test
    func `loading progress fails as unavailable`() {
        #expect(throws: ProgressStoreError.unavailable) {
            try UnavailableProgressStore().loadProgress()
        }
    }

    @Test
    func `recording a grade fails as unavailable`() throws {
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

        #expect(throws: ProgressStoreError.unavailable) {
            try UnavailableProgressStore().record(
                answer: answer,
                progress: CardProgress(cardID: card, state: state),
            )
        }
    }

    @Test
    func `the store's errors are values a caller can compare and send`() {
        #expect(ProgressStoreError.unavailable != .storageFailure)
        #expect(ProgressStoreError.storageFailure != .corruptedRecord)
    }
}
