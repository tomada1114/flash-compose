import FlashComposeCore
@testable import FlashComposePlatform
import Foundation
import SwiftData
import Testing

/// One way a stored progress row can stop reading back.
enum ProgressRowDamage: CaseIterable, Sendable {
    case cardIDOutOfFormat
    case dueDayOnFebruary29OfACommonYear
    case lastDayOfMonth13
    case lastDayZero

    private static let february29In2026 = 20_260_229
    private static let month13In2026 = 20_261_314

    func apply(to record: CardProgressRecord) {
        switch self {
        case .cardIDOutOfFormat:
            record.cardID = "C_2T5H9Y9G"

        case .dueDayOnFebruary29OfACommonYear:
            record.dueDay = Self.february29In2026

        case .lastDayOfMonth13:
            record.lastDay = Self.month13In2026

        case .lastDayZero:
            record.lastDay = 0
        }
    }
}

/// One way a stored answer row can stop reading back.
enum AnswerRowDamage: CaseIterable, Sendable {
    case beforeHalfSet
    case cardIDOutOfFormat
    case easyGrade
    case practiceDayOnOctober32
    case unknownKind

    /// FSRS's easy rating, which the drill never offers.
    private static let easyRating = 4
    private static let october32In2026 = 20_261_032

    func apply(to record: AnswerRecord) {
        switch self {
        case .beforeHalfSet:
            record.beforeStability = 1

        case .cardIDOutOfFormat:
            record.cardID = "not a card"

        case .easyGrade:
            record.grade = Self.easyRating

        case .practiceDayOnOctober32:
            record.practiceDay = Self.october32In2026

        case .unknownKind:
            record.kind = "skipped"
        }
    }
}

extension SwiftDataTodoRepositoryTests {
    /// What the adapter reads back from a row: the stored day encoding, the grade and
    /// kind names, and a row that no longer makes a Core value, which is reported as
    /// ``FlashComposeCore/ProgressStoreError/corruptedRecord`` rather than skipped or
    /// crashed on.
    ///
    /// Nested in `SwiftDataTodoRepositoryTests` for its `.serialized` trait, as every
    /// suite that opens a container is.
    @Suite("SwiftDataProgressStore read-back")
    struct SwiftDataProgressStoreReadBackTests {
        static func progress() throws -> CardProgress {
            try CardProgress(cardID: CardID("c_2t5h9y9g"), state: FSRSState(
                stability: 2.3065,
                difficulty: 2.11810397,
                reps: 1,
                lapses: 0,
                lastDay: PracticeDay(year: 2_026, month: 10, day: 14),
                dueDay: PracticeDay(year: 2_026, month: 10, day: 17),
            ))
        }

        static func answer() throws -> Answer {
            let progress = try progress()
            return try Answer(
                cardID: progress.cardID,
                gradedAt: Date(timeIntervalSinceReferenceDate: 0),
                practiceDay: PracticeDay(year: 2_026, month: 10, day: 14),
                grade: .good,
                kind: .firstOfDay,
                before: nil,
                after: progress.state,
                secondsToReveal: 4.2,
            )
        }

        @Test(arguments: [
            (2_026, 10, 14, 20_261_014),
            (1, 1, 1, 10_101),
            (9_999, 12, 31, 99_991_231),
            (2_028, 2, 29, 20_280_229),
        ])
        func `a practice day is stored as the integer that reads as its date`(
            year: Int,
            month: Int,
            day: Int,
            stored: Int,
        ) throws {
            let practiceDay = try PracticeDay(year: year, month: month, day: day)
            #expect(StoredDay.value(of: practiceDay) == stored)
            #expect(try StoredDay.day(from: stored) == practiceDay)
        }

        @Test(arguments: [0, -20_261_014, 20_261_000, 20_261_301, 20_260_229, 100_000_101])
        func `a stored day that names no date is a corrupted record`(stored: Int) {
            #expect(throws: ProgressStoreError.corruptedRecord) {
                try StoredDay.day(from: stored)
            }
        }

        @Test
        func `the answer kinds are stored under fixed names`() throws {
            #expect(StoredKind.name(of: .firstOfDay) == "firstOfDay")
            #expect(StoredKind.name(of: .reAsk) == "reAsk")
            #expect(try StoredKind.kind(named: "firstOfDay") == .firstOfDay)
            #expect(try StoredKind.kind(named: "reAsk") == .reAsk)
        }

        @Test(arguments: [Grade.again, .hard, .good])
        func `an answer's grade is stored as its FSRS rating`(grade: Grade) async throws {
            let container = try PersistenceStore.makeContainer(storage: .inMemory)
            let base = try Self.answer()
            let answer = Answer(
                cardID: base.cardID,
                gradedAt: base.gradedAt,
                practiceDay: base.practiceDay,
                grade: grade,
                kind: .reAsk,
                before: base.after,
                after: base.after,
                secondsToReveal: base.secondsToReveal,
            )
            let store = SwiftDataProgressStore(modelContainer: container)
            try await store.record(answer: answer, progress: Self.progress())

            let stored = try ModelContext(container).fetch(FetchDescriptor<AnswerRecord>())
            #expect(stored.map(\.grade) == [grade.rawValue])
            #expect(stored.map(\.kind) == ["reAsk"])
            #expect(try await store.loggedAnswers() == [answer])
        }

        @Test(arguments: ProgressRowDamage.allCases)
        func `a progress row that no longer reads back fails the load`(
            damage: ProgressRowDamage,
        ) async throws {
            let container = try PersistenceStore.makeContainer(storage: .inMemory)
            let context = ModelContext(container)
            let record = try CardProgressRecord(Self.progress())
            damage.apply(to: record)
            context.insert(record)
            try context.save()

            let store = SwiftDataProgressStore(modelContainer: container)
            await #expect(throws: ProgressStoreError.corruptedRecord) {
                try await store.loadProgress()
            }
        }

        @Test(arguments: AnswerRowDamage.allCases)
        func `an answer row that no longer reads back fails the log read`(
            damage: AnswerRowDamage,
        ) async throws {
            let container = try PersistenceStore.makeContainer(storage: .inMemory)
            let context = ModelContext(container)
            let record = try AnswerRecord(Self.answer())
            damage.apply(to: record)
            context.insert(record)
            try context.save()

            let store = SwiftDataProgressStore(modelContainer: container)
            await #expect(throws: ProgressStoreError.corruptedRecord) {
                try await store.loggedAnswers()
            }
        }
    }
}
