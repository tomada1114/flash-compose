import FlashComposeCore
import FlashComposeTestSupport
import Foundation
import Testing

/// A store with one deliberate flaw, for the contract's oracle: each flaw breaks one
/// promise the port makes, and the contract must report it.
actor FlawedProgressStore: ProgressStore {
    enum Flaw: Sendable, CaseIterable {
        /// Adds a progress row per record instead of replacing the card's row.
        case appendsProgressRows
        /// Keeps a failed record's change and throws anyway: no rollback.
        case keepsFailedRecord
        /// Keeps only the newest answer, as if the log were a field.
        case keepsOnlyLatestAnswer
        /// Ignores the probe's fault switch and always saves.
        case neverFails
        /// Fails the whole load while it holds a row it cannot read back.
        case failsLoadOnUnreadableRow
    }

    private let flaw: Flaw
    private var rows: [CardProgress] = []
    private var unreadable: Set<CardID> = []
    private var log: [Answer] = []
    private var failing = false

    nonisolated var probe: ProgressStoreContract.Probe {
        ProgressStoreContract.Probe(
            answers: { await self.log },
            failRecords: { failing in await self.setFailing(failing) },
            storeUnreadableRow: { progress in await self.storeUnreadableRow(progress.cardID) },
        )
    }

    init(_ flaw: Flaw) {
        self.flaw = flaw
    }

    func setFailing(_ failing: Bool) {
        self.failing = failing
    }

    func storeUnreadableRow(_ cardID: CardID) {
        rows.removeAll { $0.cardID == cardID }
        unreadable.insert(cardID)
    }

    func loadProgress() throws(ProgressStoreError) -> [CardProgress] {
        if flaw == .failsLoadOnUnreadableRow, !unreadable.isEmpty {
            throw .corruptedRecord
        }
        return rows
    }

    func record(answer: Answer, progress: CardProgress) throws(ProgressStoreError) {
        let fails = failing && flaw != .neverFails
        if fails, flaw != .keepsFailedRecord {
            throw .storageFailure
        }
        log = flaw == .keepsOnlyLatestAnswer ? [answer] : log + [answer]
        unreadable.remove(progress.cardID)
        if flaw != .appendsProgressRows {
            rows.removeAll { $0.cardID == progress.cardID }
        }
        rows.append(progress)
        if fails {
            throw .storageFailure
        }
    }
}

/// The fake half of the `ProgressStore` contract suite: the same
/// ``ProgressStoreContract`` that `FlashComposePlatformTests` runs against the SwiftData
/// adapter runs here against ``InMemoryProgressStore``, so the fake cannot drift from the
/// port's promises.
@Suite("ProgressStore contract, against the fake")
struct ProgressStoreContractTests {
    @Test
    func `the fake keeps the contract`() async {
        let store = InMemoryProgressStore()
        await ProgressStoreContract.check(store, probe: store.contractProbe)
    }

    // The contract's own oracle: an implementation that breaks a promise must be
    // reported, or `check(_:probe:)` would pass anything, the real adapter included.

    @Test(arguments: [
        (
            FlawedProgressStore.Flaw.appendsProgressRows,
            "loadProgress returned more than one progress row for a card",
        ),
        (.keepsFailedRecord, "a failed record left its progress in the store"),
        (.keepsFailedRecord, "a failed record left its answer in the log"),
        (
            .keepsOnlyLatestAnswer,
            "the answer log did not keep the first answer and append the second",
        ),
        (.neverFails, "record did not throw while saves were failing"),
        (.failsLoadOnUnreadableRow, "loadProgress threw corruptedRecord over a row it cannot"),
    ])
    func `a store with a flaw is reported`(flaw: FlawedProgressStore.Flaw, report: String) async {
        let store = FlawedProgressStore(flaw)
        let violations = await ProgressStoreContract.violations(of: store, probe: store.probe)
        #expect(violations.contains { $0.contains(report) }, "\(violations)")
    }

    @Test
    func `a store that cannot be reached is reported`() async {
        let probe = ProgressStoreContract.Probe(
            answers: { [] },
            failRecords: { _ in
                // Nothing to break: every call already fails.
            },
            storeUnreadableRow: { _ in
                // Nothing to damage: there is no store.
            },
        )
        let violations = await ProgressStoreContract.violations(
            of: UnavailableProgressStore(),
            probe: probe,
        )
        #expect(violations.count == 1)
        #expect(violations.first?.contains("unavailable") == true)
    }

    // The fake's own seams, which a drill test leans on.

    @Test
    func `the fake starts from the progress it is given, one row per card`() async throws {
        let card = try CardID("c_2t5h9y9g")
        let day = try PracticeDay(year: 2_026, month: 10, day: 14)
        let older = CardProgress(cardID: card, state: FSRSState(
            stability: 1,
            difficulty: 5,
            reps: 1,
            lapses: 0,
            lastDay: day,
            dueDay: day,
        ))
        let newer = CardProgress(cardID: card, state: FSRSState(
            stability: 2,
            difficulty: 4,
            reps: 2,
            lapses: 1,
            lastDay: day,
            dueDay: day.adding(days: 1),
        ))
        let store = InMemoryProgressStore(progress: [older, newer])

        #expect(try await store.loadProgress() == [newer])
        #expect(await store.answers.isEmpty)
        #expect(await store.calls == [.loadProgress])
    }

    @Test
    func `an unreadable row stays in the fake until a record for its card replaces it`(
    ) async throws {
        let card = try CardID("c_2t5h9y9g")
        let day = try PracticeDay(year: 2_026, month: 10, day: 14)
        let progress = CardProgress(cardID: card, state: FSRSState(
            stability: 1,
            difficulty: 5,
            reps: 1,
            lapses: 0,
            lastDay: day,
            dueDay: day,
        ))
        let store = InMemoryProgressStore(progress: [progress])
        await store.storeUnreadableRow(for: card)

        #expect(try await store.loadProgress().isEmpty)
        #expect(await store.unreadableRows == [card])
        let answer = Answer(
            cardID: card,
            gradedAt: Date(timeIntervalSinceReferenceDate: 0),
            practiceDay: day,
            grade: .good,
            kind: .firstOfDay,
            before: nil,
            after: progress.state,
            secondsToReveal: 1,
        )
        try await store.record(answer: answer, progress: progress)
        #expect(await store.unreadableRows.isEmpty)
        #expect(try await store.loadProgress() == [progress])
    }

    @Test
    func `a failing load throws the error it was given until it succeeds again`() async throws {
        let store = InMemoryProgressStore()
        await store.fail(.loadProgress, with: .storageFailure)

        await #expect(throws: ProgressStoreError.storageFailure) {
            try await store.loadProgress()
        }
        await store.succeed(.loadProgress)
        #expect(try await store.loadProgress().isEmpty)
        #expect(await store.calls == [.loadProgress, .loadProgress])
    }
}
