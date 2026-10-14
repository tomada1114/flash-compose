import FlashComposeCore
import Foundation
import Testing

/// The promises ``FlashComposeCore/ProgressStore`` makes, checked against any implementation.
///
/// Written once, over the protocol, because a fake stands in for the adapter only while
/// both keep the port's promises. `FlashComposeCoreTests` runs ``check(_:probe:)`` against
/// ``InMemoryProgressStore``; `FlashComposePlatformTests` runs it against
/// `SwiftDataProgressStore` with an in-memory store. Both run under `just test` and in CI.
/// Every clause is one the port's `///` states; a new clause is stated there first.
///
/// The port has no way to read the answer log back — nothing in the app does — no way to
/// make a save fail, and no way to store a row it cannot read back, so each implementation
/// hands the contract a ``Probe`` for those three test-only reaches.
package enum ProgressStoreContract {
    /// What the contract needs from an implementation beyond the port.
    package struct Probe: Sendable {
        /// Every answer the store holds, in any order: the contract sorts them by
        /// ``FlashComposeCore/Answer/gradedAt``.
        let answers: @Sendable () async throws -> [Answer]
        /// `true` makes every later ``FlashComposeCore/ProgressStore/record(answer:progress:)``
        /// fail at the point it would persist, after it has staged its change; `false`
        /// makes records succeed again.
        let failRecords: @Sendable (_ failing: Bool) async -> Void
        /// Stores a row for `progress.cardID` that the store cannot read back — as a
        /// stored practice day that names no date would be — in place of any row the card
        /// has, the way damage on disk would reach it.
        let storeUnreadableRow: @Sendable (_ progress: CardProgress) async throws -> Void

        /// Pairs the log reader with the fault switch and the damage seam.
        package init(
            answers: @escaping @Sendable () async throws -> [Answer],
            failRecords: @escaping @Sendable (_ failing: Bool) async -> Void,
            storeUnreadableRow: @escaping @Sendable (_ progress: CardProgress) async throws
                -> Void,
        ) {
            self.answers = answers
            self.failRecords = failRecords
            self.storeUnreadableRow = storeUnreadableRow
        }
    }

    /// A description of every broken promise, empty when `store` keeps them all. `store`
    /// must start empty, with records succeeding.
    ///
    /// Separate from ``check(_:probe:)`` so a test can hand it an implementation that
    /// breaks a promise and see the contract notice — the proof it is not vacuous.
    package static func violations(
        of store: some ProgressStore,
        probe: Probe,
    ) async -> [String] {
        var broken: [String] = []
        do {
            let run = try Run(store: store, probe: probe)
            try await run.checkEmpty(into: &broken)
            try await run.checkFirstRecord(into: &broken)
            try await run.checkSecondRecord(into: &broken)
            try await run.checkSecondCardAndReAsk(into: &broken)
            try await run.checkFailedRecord(into: &broken)
            try await run.checkUnreadableRow(into: &broken)
        } catch {
            broken.append("an operation the contract expects to succeed threw \(error)")
        }
        return broken
    }

    /// Records an issue for every promise `store` breaks. `store` must start empty.
    package static func check(_ store: some ProgressStore, probe: Probe) async {
        let broken = await violations(of: store, probe: probe)
        #expect(
            broken.isEmpty,
            "\(type(of: store)) breaks the ProgressStore contract: \(broken)",
        )
    }
}

extension ProgressStoreContract {
    /// One pass of the clauses over one store, in order: each step starts from the state
    /// the one before left.
    private struct Run {
        let store: any ProgressStore
        let probe: Probe
        let fixture: ProgressStoreContractFixture

        init(store: any ProgressStore, probe: Probe) throws {
            self.store = store
            self.probe = probe
            fixture = try ProgressStoreContractFixture()
        }

        /// Progress sorted by card id, so a duplicate row shows as an extra element
        /// rather than vanishing into a set.
        func load() async throws(ProgressStoreError) -> [CardProgress] {
            try await store.loadProgress().sorted { $0.cardID.rawValue < $1.cardID.rawValue }
        }

        func log() async throws -> [Answer] {
            try await probe.answers().sorted { $0.gradedAt < $1.gradedAt }
        }

        func checkEmpty(into broken: inout [String]) async throws {
            if try await !load().isEmpty {
                broken.append("loadProgress on an empty store returned progress")
            }
            if try await !log().isEmpty {
                broken.append("the answer log of an empty store is not empty")
            }
        }

        /// Example 1: a new card's first grade, whose answer has no state before.
        func checkFirstRecord(into broken: inout [String]) async throws {
            try await store.record(answer: fixture.firstAnswer, progress: fixture.firstProgress)
            let loaded = try await load()
            if loaded != [fixture.firstProgress] {
                broken.append("loadProgress after the first record is not its progress: \(loaded)")
            }
            let answers = try await log()
            if answers != [fixture.firstAnswer] {
                broken.append("the answer log after the first record is not its answer: \(answers)")
            }
        }

        /// Example 2: the same card graded again on a later day replaces its row.
        func checkSecondRecord(into broken: inout [String]) async throws {
            try await store.record(answer: fixture.secondAnswer, progress: fixture.secondProgress)
            let loaded = try await load()
            let ids = loaded.map(\.cardID)
            if Set(ids).count != ids.count {
                broken.append("loadProgress returned more than one progress row for a card")
            }
            if loaded != [fixture.secondProgress] {
                broken.append("a second record did not replace the card's progress: \(loaded)")
            }
            let answers = try await log()
            if answers != [fixture.firstAnswer, fixture.secondAnswer] {
                broken.append(
                    "the answer log did not keep the first answer and append the second: \(answers)",
                )
            }
        }

        /// A second card gets a row of its own; a re-ask is appended like any answer.
        func checkSecondCardAndReAsk(into broken: inout [String]) async throws {
            try await store.record(answer: fixture.otherAnswer, progress: fixture.otherProgress)
            try await store.record(answer: fixture.reAskAnswer, progress: fixture.secondProgress)
            let loaded = try await load()
            if loaded != [fixture.secondProgress, fixture.otherProgress] {
                broken.append("loadProgress did not return one row per card: \(loaded)")
            }
            let answers = try await log()
            if answers != fixture.answersBeforeFailure {
                broken
                    .append("the answer log did not append a second card and a re-ask: \(answers)")
            }
        }

        /// Example 3: a failed record leaves neither half behind, and the next successful
        /// record does not write it after all.
        func checkFailedRecord(into broken: inout [String]) async throws {
            await probe.failRecords(true)
            let threw: Bool
            do {
                try await store.record(
                    answer: fixture.failedAnswer,
                    progress: fixture.failedProgress,
                )
                threw = false
            } catch {
                threw = true
            }
            await probe.failRecords(false)
            if !threw {
                broken.append("record did not throw while saves were failing")
            }
            if try await load() != [fixture.secondProgress, fixture.otherProgress] {
                broken.append("a failed record left its progress in the store")
            }
            if try await log() != fixture.answersBeforeFailure {
                broken.append("a failed record left its answer in the log")
            }

            try await store.record(answer: fixture.laterAnswer, progress: fixture.laterProgress)
            let loaded = try await load()
            let answers = try await log()
            let storedOwnChange = loaded == [fixture.secondProgress, fixture.laterProgress]
                && answers == fixture.answersBeforeFailure + [fixture.laterAnswer]
            if !storedOwnChange {
                broken.append(
                    "the record after a failed one did not store exactly its own change: "
                        + "\(loaded), \(answers)",
                )
            }
        }

        /// A row the store cannot read back is left out of the load, which still
        /// succeeds with every other card, and the card's next record replaces it.
        func checkUnreadableRow(into broken: inout [String]) async throws {
            try await probe.storeUnreadableRow(fixture.unreadableProgress)
            let loaded: [CardProgress]
            do {
                loaded = try await load()
            } catch {
                broken.append("loadProgress threw \(error) over a row it cannot read back")
                return
            }
            if loaded != [fixture.secondProgress, fixture.laterProgress] {
                broken.append(
                    "loadProgress did not leave out only the row it cannot read back: \(loaded)",
                )
            }

            try await store.record(answer: fixture.revivedAnswer, progress: fixture.revivedProgress)
            let revived = try await load()
            if revived != [fixture.secondProgress, fixture.laterProgress, fixture.revivedProgress] {
                broken.append(
                    "a record did not replace the card's unreadable row: \(revived)",
                )
            }
        }
    }
}
