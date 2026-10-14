import FlashComposeCore
import Foundation
import SwiftData

/// The first version of the app's stored schema: every `@Model` the app keeps, in one
/// store that ``PersistenceStore`` opens once.
///
/// Versioned from day one because the stored shape is contract (`docs/architecture.md`
/// › What is contract): an installed app's store outlives every build, so a change to a
/// `@Model` class that a shipped schema does not describe is a migration, not an edit.
/// This version holds the learner's progress and answer log, and is still edited in place
/// because no build carrying it has been installed outside the owner's Mac
/// (`docs/architecture.md` › Progress store). From the first such
/// install, the next change — a changed record or another entity — adds `AppSchemaV2`
/// beside this one and a stage to ``AppMigrationPlan``, and this enum is never edited
/// again. Only the Swift names of the schema and the plan are free to change: the store
/// records the model's entities, attributes, and version identifier, never these names.
enum AppSchemaV1: VersionedSchema {
    /// SwiftData's stored shape of a ``FlashComposeCore/CardProgress``: one row per card
    /// that has moved, keyed by its card id.
    ///
    /// `@Attribute(.unique)` on the card id keeps a second row for a card from ever being
    /// written, whatever the adapter does. CloudKit sync does not allow unique
    /// constraints, so an app that turns sync on replaces it with a fetch-before-insert in
    /// a new schema version. Practice days are stored as ``StoredDay`` integers, so the
    /// row holds no calendar or time zone.
    @Model
    final class CardProgressRecord {
        @Attribute(.unique)
        var cardID: String
        var stability: Double
        var difficulty: Double
        var reps: Int
        var lapses: Int
        var lastDay: Int
        var dueDay: Int

        init(_ progress: CardProgress) {
            cardID = progress.cardID.rawValue
            stability = progress.state.stability
            difficulty = progress.state.difficulty
            reps = progress.state.reps
            lapses = progress.state.lapses
            lastDay = StoredDay.value(of: progress.state.lastDay)
            dueDay = StoredDay.value(of: progress.state.dueDay)
        }

        /// Copies the card's new state. Its id never changes.
        func update(from progress: CardProgress) {
            stability = progress.state.stability
            difficulty = progress.state.difficulty
            reps = progress.state.reps
            lapses = progress.state.lapses
            lastDay = StoredDay.value(of: progress.state.lastDay)
            dueDay = StoredDay.value(of: progress.state.dueDay)
        }

        /// Core's value for this row, or ``FlashComposeCore/ProgressStoreError/corruptedRecord``
        /// when its card id or a day no longer reads back.
        func progress() throws(ProgressStoreError) -> CardProgress {
            let id: CardID
            do {
                id = try CardID(cardID)
            } catch {
                throw .corruptedRecord
            }
            return try CardProgress(cardID: id, state: FSRSState(
                stability: stability,
                difficulty: difficulty,
                reps: reps,
                lapses: lapses,
                lastDay: StoredDay.day(from: lastDay),
                dueDay: StoredDay.day(from: dueDay),
            ))
        }
    }

    /// SwiftData's stored shape of an ``FlashComposeCore/Answer``: one row per grade,
    /// appended and never changed.
    ///
    /// The states before and after are flat columns rather than a composite attribute, and
    /// the six `before` columns are all `nil` together for a card answered for the first
    /// time. The grade is its FSRS rating and the kind a ``StoredKind`` name, so the row
    /// reads the same whatever the Swift cases are called.
    @Model
    final class AnswerRecord {
        var cardID: String
        var gradedAt: Date
        var practiceDay: Int
        var grade: Int
        var kind: String
        var beforeStability: Double?
        var beforeDifficulty: Double?
        var beforeReps: Int?
        var beforeLapses: Int?
        var beforeLastDay: Int?
        var beforeDueDay: Int?
        var afterStability: Double
        var afterDifficulty: Double
        var afterReps: Int
        var afterLapses: Int
        var afterLastDay: Int
        var afterDueDay: Int
        var secondsToReveal: Double

        init(_ answer: Answer) {
            cardID = answer.cardID.rawValue
            gradedAt = answer.gradedAt
            practiceDay = StoredDay.value(of: answer.practiceDay)
            grade = answer.grade.rawValue
            kind = StoredKind.name(of: answer.kind)
            beforeStability = answer.before?.stability
            beforeDifficulty = answer.before?.difficulty
            beforeReps = answer.before?.reps
            beforeLapses = answer.before?.lapses
            beforeLastDay = answer.before.map { StoredDay.value(of: $0.lastDay) }
            beforeDueDay = answer.before.map { StoredDay.value(of: $0.dueDay) }
            afterStability = answer.after.stability
            afterDifficulty = answer.after.difficulty
            afterReps = answer.after.reps
            afterLapses = answer.after.lapses
            afterLastDay = StoredDay.value(of: answer.after.lastDay)
            afterDueDay = StoredDay.value(of: answer.after.dueDay)
            secondsToReveal = answer.secondsToReveal
        }

        /// Core's value for this row, or ``FlashComposeCore/ProgressStoreError/corruptedRecord``
        /// when a column no longer reads back. Nothing in the app reads the log; the tests
        /// do, through `SwiftDataProgressStore`.
        func answer() throws(ProgressStoreError) -> Answer {
            let id: CardID
            do {
                id = try CardID(cardID)
            } catch {
                throw .corruptedRecord
            }
            guard let rating = Grade(rawValue: grade) else {
                throw .corruptedRecord
            }
            return try Answer(
                cardID: id,
                gradedAt: gradedAt,
                practiceDay: StoredDay.day(from: practiceDay),
                grade: rating,
                kind: StoredKind.kind(named: kind),
                before: before(),
                after: FSRSState(
                    stability: afterStability,
                    difficulty: afterDifficulty,
                    reps: afterReps,
                    lapses: afterLapses,
                    lastDay: StoredDay.day(from: afterLastDay),
                    dueDay: StoredDay.day(from: afterDueDay),
                ),
                secondsToReveal: secondsToReveal,
            )
        }

        /// The state before, `nil` when all six columns are; a row with some of them set
        /// and some not is corrupted.
        private func before() throws(ProgressStoreError) -> FSRSState? {
            let isSet = [
                beforeStability != nil, beforeDifficulty != nil, beforeReps != nil,
                beforeLapses != nil, beforeLastDay != nil, beforeDueDay != nil,
            ]
            if !isSet.contains(true) {
                return nil
            }
            guard let beforeStability, let beforeDifficulty, let beforeReps, let beforeLapses,
                  let beforeLastDay, let beforeDueDay
            else {
                throw .corruptedRecord
            }
            return try FSRSState(
                stability: beforeStability,
                difficulty: beforeDifficulty,
                reps: beforeReps,
                lapses: beforeLapses,
                lastDay: StoredDay.day(from: beforeLastDay),
                dueDay: StoredDay.day(from: beforeDueDay),
            )
        }
    }

    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [CardProgressRecord.self, AnswerRecord.self]
    }
}
