import FlashComposeCore
@testable import FlashComposePlatform
import FlashComposeTestSupport
import Foundation
import SwiftData
import Testing

/// Fixed values for ``SwiftDataTodoRepositoryTests/SwiftDataProgressStoreTests``.
private enum Fixture {
    static let gradedAtSeconds: TimeInterval = 813_621_600
    static let gradedAt = Date(timeIntervalSinceReferenceDate: gradedAtSeconds)
    static let minute: TimeInterval = 60
    static let secondsToReveal = 4.2
    static let stability = 2.3065
    static let difficulty = 2.11810397
    static let movedStability = 7.25
    static let movedReps = 2
    static let firstDay = 20_261_014
    static let dueDay = 20_261_017

    static func card(_ raw: String = "c_2t5h9y9g") throws -> CardID {
        try CardID(raw)
    }

    static func day(_ stored: Int) throws -> PracticeDay {
        try StoredDay.day(from: stored)
    }

    static func state(reps: Int = 1, stability: Double = stability) throws -> FSRSState {
        try FSRSState(
            stability: stability,
            difficulty: difficulty,
            reps: reps,
            lapses: 0,
            lastDay: day(firstDay),
            dueDay: day(dueDay),
        )
    }

    /// A first-of-day grade of `card` moving it from `before` to `after`, `minutes`
    /// after ``gradedAt``.
    static func answer(
        _ card: CardID,
        to after: FSRSState,
        from before: FSRSState? = nil,
        minutes: Double = 0,
    ) throws -> Answer {
        try Answer(
            cardID: card,
            gradedAt: gradedAt.addingTimeInterval(minutes * minute),
            practiceDay: day(firstDay),
            grade: .good,
            kind: .firstOfDay,
            before: before,
            after: after,
            secondsToReveal: secondsToReveal,
        )
    }

    static func scratchDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FlashComposeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

extension SwiftDataTodoRepositoryTests {
    /// The adapter half of the `ProgressStore` contract suite, plus what only the adapter
    /// can get wrong: the rollback of a failed save, reading a stored row back, and
    /// keeping progress across a reopen of the store file.
    ///
    /// Nested in `SwiftDataTodoRepositoryTests` so its `.serialized` trait covers these
    /// too: they open containers, and concurrent container creation is what that trait
    /// keeps out.
    @Suite("SwiftDataProgressStore")
    struct SwiftDataProgressStoreTests {
        /// The contract's reach into the adapter: its test-only log reader and fault switch.
        static func probe(of store: SwiftDataProgressStore) -> ProgressStoreContract.Probe {
            ProgressStoreContract.Probe(
                answers: { try await store.loggedAnswers() },
                failRecords: { failing in await store.failSaves(failing) },
            )
        }

        @Test
        func `the SwiftData adapter keeps the contract`() async throws {
            let store = try SwiftDataProgressStore(
                modelContainer: PersistenceStore.makeContainer(storage: .inMemory),
            )
            await ProgressStoreContract.check(store, probe: Self.probe(of: store))
        }

        @Test
        func `a failed save is rolled back and never written by the next one`() async throws {
            let container = try PersistenceStore.makeContainer(storage: .inMemory)
            let store = SwiftDataProgressStore(modelContainer: container)
            let card = try Fixture.card()
            let first = try Fixture.state()
            let firstAnswer = try Fixture.answer(card, to: first)
            try await store.record(answer: firstAnswer, progress: CardProgress(
                cardID: card,
                state: first,
            ))

            await store.failSaves(true)
            let moved = try Fixture.state(
                reps: Fixture.movedReps,
                stability: Fixture.movedStability,
            )
            await #expect(throws: ProgressStoreError.storageFailure) {
                try await store.record(
                    answer: Fixture.answer(card, to: moved, from: first, minutes: 1),
                    progress: CardProgress(cardID: card, state: moved),
                )
            }
            await store.failSaves(false)
            let other = try Fixture.card("c_3w4x5y6z")
            let otherAnswer = try Fixture.answer(other, to: first, minutes: 2)
            try await store.record(answer: otherAnswer, progress: CardProgress(
                cardID: other,
                state: first,
            ))

            // Read through a second actor over the same container, so what is checked is
            // what was saved, not what one context still holds.
            let reader = SwiftDataProgressStore(modelContainer: container)
            let loaded = try await reader.loadProgress()
                .sorted { $0.cardID.rawValue < $1.cardID.rawValue }
            #expect(loaded == [
                CardProgress(cardID: card, state: first),
                CardProgress(cardID: other, state: first),
            ])
            #expect(try await reader.loggedAnswers() == [firstAnswer, otherAnswer])
        }

        @Test
        func `progress survives closing and reopening the store file`() async throws {
            let directory = try Fixture.scratchDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appending(path: "progress.store")
            let card = try Fixture.card()
            let state = try Fixture.state()
            let answer = try Fixture.answer(card, to: state)

            try await SwiftDataProgressStore(
                modelContainer: PersistenceStore.makeContainer(storage: .file(url)),
            ).record(answer: answer, progress: CardProgress(cardID: card, state: state))

            let reopened = try SwiftDataProgressStore(
                modelContainer: PersistenceStore.makeContainer(storage: .file(url)),
            )
            #expect(try await reopened.loadProgress() == [CardProgress(cardID: card, state: state)])
            #expect(try await reopened.loggedAnswers() == [answer])
        }

        @Test
        func `the progress store and the to-do repository share one container`() async throws {
            let container = try PersistenceStore.makeContainer(storage: .inMemory)
            let progress = SwiftDataProgressStore(modelContainer: container)
            let todos = SwiftDataTodoRepository(modelContainer: container)
            let card = try Fixture.card()
            let state = try Fixture.state()

            try await progress.record(
                answer: Fixture.answer(card, to: state),
                progress: CardProgress(cardID: card, state: state),
            )
            try await todos.save(TodoItem(id: UUID(), title: "Beside", createdAt: Fixture.gradedAt))

            #expect(try await progress.loadProgress() == [CardProgress(cardID: card, state: state)])
            #expect(try await todos.fetchAll().count == 1)
        }
    }
}
