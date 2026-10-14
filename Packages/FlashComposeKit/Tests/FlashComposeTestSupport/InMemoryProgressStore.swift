import FlashComposeCore

/// The one fake of ``FlashComposeCore/ProgressStore``, shared by every test target.
///
/// A fake, not a mock: a real conforming implementation that keeps progress in a
/// dictionary keyed by card id and the answer log in an array, whose failures and calls
/// are data the test sets and reads. `ProgressStoreContract` holds it to the same
/// promises as the SwiftData adapter, so a drill test written against it is a test
/// against the port, not against a convenient invention.
///
/// An actor, like the adapter, so it is `Sendable` without a lock and a view model under
/// test crosses the same suspension points it will cross in the app.
package actor InMemoryProgressStore: ProgressStore {
    /// A port method, as recorded in ``calls`` and targeted by ``fail(_:with:)``.
    package enum Operation: Equatable, Sendable {
        case loadProgress
        case record
    }

    /// Every call made so far, in order — including the ones that failed.
    package private(set) var calls: [Operation] = []

    /// Every answer recorded, in the order it was recorded — the log the port never reads
    /// back, read here without recording a call.
    package private(set) var answers: [Answer] = []

    private var progress: [CardID: CardProgress]
    private var failures: [Operation: ProgressStoreError] = [:]
    private var beforeRecord: (@Sendable () async -> Void)?

    /// The progress held right now, ordered by card id — read without recording a call.
    package var snapshot: [CardProgress] {
        progress.values.sorted { $0.cardID.rawValue < $1.cardID.rawValue }
    }

    /// The probe `ProgressStoreContract` needs: this fake's log, and a failing record.
    package nonisolated var contractProbe: ProgressStoreContract.Probe {
        ProgressStoreContract.Probe(
            answers: { await self.answers },
            failRecords: { failing in
                if failing {
                    await self.fail(.record, with: .storageFailure)
                } else {
                    await self.succeed(.record)
                }
            },
        )
    }

    /// Starts empty: a first launch.
    package init() {
        self.init(progress: [])
    }

    /// Starts holding `progress` and an empty log; a later entry for a card id already
    /// given replaces the earlier one, as a record would.
    package init(progress: [CardProgress]) {
        self.progress = Dictionary(progress.map { ($0.cardID, $0) }) { _, later in later }
    }

    /// Makes every later call to `operation` throw `error`, storing nothing, until
    /// ``succeed(_:)``.
    package func fail(_ operation: Operation, with error: ProgressStoreError) {
        failures[operation] = error
    }

    /// Undoes ``fail(_:with:)`` for `operation`.
    package func succeed(_ operation: Operation) {
        failures[operation] = nil
    }

    /// Runs `hook` inside every later ``record(answer:progress:)``, before anything is
    /// stored or a failure thrown — the seam a test uses to act while a save is in
    /// flight, as a second tap would.
    package func onRecord(_ hook: @escaping @Sendable () async -> Void) {
        beforeRecord = hook
    }

    package func loadProgress() throws(ProgressStoreError) -> [CardProgress] {
        try note(.loadProgress)
        return snapshot
    }

    package func record(answer: Answer, progress: CardProgress) async throws(ProgressStoreError) {
        await beforeRecord?()
        try note(.record)
        answers.append(answer)
        self.progress[progress.cardID] = progress
    }

    private func note(_ operation: Operation) throws(ProgressStoreError) {
        calls.append(operation)
        if let error = failures[operation] {
            throw error
        }
    }
}
