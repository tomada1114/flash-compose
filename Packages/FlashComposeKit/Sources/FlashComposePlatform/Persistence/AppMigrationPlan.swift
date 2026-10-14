import SwiftData

/// The record types the adapters use: always the newest schema version's.
typealias CardProgressRecord = AppSchemaV1.CardProgressRecord
typealias AnswerRecord = AppSchemaV1.AnswerRecord

/// How an older store reaches the current schema — the whole app's, every entity in it.
/// Empty until a second version exists; then each version is listed in order and each
/// step between two gets a stage.
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
