import FlashComposeCore
import Foundation
import SwiftData

/// The SwiftData-backed adapter for ``FlashComposeCore/ProgressStore``.
///
/// It translates between Core's values and the stored `CardProgressRecord` and
/// `AnswerRecord`, maps every framework error into
/// ``FlashComposeCore/ProgressStoreError``, and makes no decision about a grade of its
/// own. `ProgressStoreContract` checks the translation in `FlashComposePlatformTests`
/// against an in-memory store, under plain `just test`, in CI.
///
/// `@ModelActor` gives it its own serial executor and a `ModelContext` bound to it, so no
/// `@Model` object leaves this actor. Its `init(modelContainer:)` takes the app's one
/// container from ``PersistenceStore/makeContainer(storage:)``; it never opens one of its
/// own.
@ModelActor
public actor SwiftDataProgressStore: ProgressStore {
    /// The failure ``failSaves(_:)`` injects.
    private struct InjectedSaveFailure: Error {}

    /// Set only by a test through ``failSaves(_:)``.
    private var savesFail = false

    /// Logs the framework error — the only place its detail survives — and answers
    /// Core's error. SwiftData's messages can quote stored values, so the detail is
    /// `.private`; the operation name is not user data.
    private static func storageFailure(
        _ error: any Error,
        during operation: StaticString,
    ) -> ProgressStoreError {
        AppLog.persistence.error(
            "\(operation, privacy: .public) failed: \(String(describing: error), privacy: .private)",
        )
        return .storageFailure
    }

    /// Leaves out a row that no longer reads back, keeping it stored, and logs how many it
    /// left out: only the count, since a damaged row's card id is arbitrary stored text.
    /// The card's next ``record(answer:progress:)`` overwrites the row, found by its card
    /// id; a row whose card id itself is damaged stays, left out of every load.
    public func loadProgress() throws(ProgressStoreError) -> [CardProgress] {
        let records: [CardProgressRecord]
        do {
            records = try modelContext.fetch(FetchDescriptor<CardProgressRecord>())
        } catch {
            throw Self.storageFailure(error, during: "loadProgress")
        }
        let progress = records.compactMap { try? $0.progress() }
        let skipped = records.count - progress.count
        if skipped > 0 {
            AppLog.persistence.error(
                "loadProgress left out \(skipped, privacy: .public) progress rows it cannot read back",
            )
        }
        return progress
    }

    /// Stages the card's new progress — an update of its row, or a new row — and the
    /// answer, then saves both at once. A failed save rolls the context back, so neither
    /// half stays pending for the next save to write.
    public func record(answer: Answer, progress: CardProgress) throws(ProgressStoreError) {
        do {
            if let existing = try progressRecord(cardID: progress.cardID.rawValue) {
                existing.update(from: progress)
            } else {
                modelContext.insert(CardProgressRecord(progress))
            }
            modelContext.insert(AnswerRecord(answer))
            if savesFail {
                throw InjectedSaveFailure()
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw Self.storageFailure(error, during: "record")
        }
    }

    /// Every stored answer, oldest `gradedAt` first. The app never reads the log back
    /// (``FlashComposeCore/ProgressStore``); this is for the tests that check it is kept.
    func loggedAnswers() throws(ProgressStoreError) -> [Answer] {
        let records: [AnswerRecord]
        do {
            records = try modelContext.fetch(FetchDescriptor<AnswerRecord>(
                sortBy: [SortDescriptor(\.gradedAt)],
            ))
        } catch {
            throw Self.storageFailure(error, during: "loggedAnswers")
        }
        return try records.map { record throws(ProgressStoreError) in try record.answer() }
    }

    /// Makes every later ``record(answer:progress:)`` fail after it has staged its change
    /// and before it saves (`true`), or succeed again (`false`): the only way a test can
    /// reach the rollback, since an in-memory save does not fail on its own. Internal
    /// rather than `#if DEBUG`, like ``loggedAnswers()``: `swift test -c release` builds
    /// the Platform tests that call both.
    func failSaves(_ failing: Bool) {
        savesFail = failing
    }

    private func progressRecord(cardID: String) throws -> CardProgressRecord? {
        var descriptor = FetchDescriptor<CardProgressRecord>(
            predicate: #Predicate { $0.cardID == cardID },
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
