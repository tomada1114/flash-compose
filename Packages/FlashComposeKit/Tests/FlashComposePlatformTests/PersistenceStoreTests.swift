import CoreData
import FlashComposeCore
@testable import FlashComposePlatform
import Foundation
import SwiftData
import Testing

/// Fixed values and the pre-rename store writer for
/// ``SwiftDataStoreTests/PersistenceStoreTests``.
private enum Fixture {
    /// What the store file says about the model that wrote it: the per-entity version
    /// hashes Core Data compares to decide on a migration, and the schema's version
    /// identifiers.
    struct ModelVersion: Equatable {
        var hashes: [String: Data]
        var identifiers: [String]

        var entities: [String] {
            hashes.keys.sorted()
        }
    }

    static let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    static let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
    static let minute: TimeInterval = 60
    static let firstCreatedAt = Date(timeIntervalSinceReferenceDate: minute)
    static let secondCreatedAt = firstCreatedAt.addingTimeInterval(minute)

    static func scratchDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FlashComposeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes two records through a container built from the frozen pre-rename schema,
    /// then lets that container go, so the reopen is a second open of the file.
    static func writePreRenameStore(at url: URL) throws {
        let schema = Schema(versionedSchema: PreRenameSchemaV1.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PreRenameMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, url: url),
        )
        let context = ModelContext(container)
        context.insert(PreRenameSchemaV1.TodoRecord(
            id: firstID,
            title: "Open",
            isDone: false,
            createdAt: firstCreatedAt,
        ))
        context.insert(PreRenameSchemaV1.TodoRecord(
            id: secondID,
            title: "Done",
            isDone: true,
            createdAt: secondCreatedAt,
        ))
        try context.save()
    }

    static func modelVersion(of url: URL) throws -> ModelVersion {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            type: .sqlite,
            at: url,
        )
        return ModelVersion(
            hashes: metadata[NSStoreModelVersionHashesKey] as? [String: Data] ?? [:],
            identifiers: metadata[NSStoreModelVersionIdentifiersKey] as? [String] ?? [],
        )
    }
}

extension SwiftDataStoreTests {
    /// The app's one container: shared by every adapter, and able to reopen a store file
    /// an earlier build wrote.
    ///
    /// Nested in `SwiftDataStoreTests` so its `.serialized` trait covers these
    /// too — they open containers, and concurrent container creation is what that trait
    /// keeps out.
    @Suite("PersistenceStore")
    struct PersistenceStoreTests {
        @Test
        func `two adapters over one container see each other's writes`() async throws {
            let container = try PersistenceStore.makeContainer(storage: .inMemory)
            let writer = SwiftDataProgressStore(modelContainer: container)
            let reader = SwiftDataProgressStore(modelContainer: container)
            let progress = try SwiftDataProgressStoreReadBackTests.progress()

            try await writer.record(
                answer: SwiftDataProgressStoreReadBackTests.answer(),
                progress: progress,
            )
            #expect(try await reader.loadProgress() == [progress])
            #expect(try await reader.loggedAnswers().count == 1)
        }

        /// The template's `TodoRecord` is no longer in `AppSchemaV1`, so a store that held
        /// only it reopens without that table (the owner agreed to this in #21: no build ever
        /// shipped it). What the case still proves is that the store never
        /// recorded the Swift names of the schema and the plan: the file opens, keeps its
        /// version identifier, and serves the progress store.
        @Test
        func `a store written with the pre-rename schema still opens`() async throws {
            let directory = try Fixture.scratchDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appending(path: "pre-rename.store")

            try Fixture.writePreRenameStore(at: url)
            let written = try Fixture.modelVersion(of: url)

            let reopened = try PersistenceStore.makeContainer(storage: .file(url))
            let store = SwiftDataProgressStore(modelContainer: reopened)
            #expect(try await store.loadProgress().isEmpty)
            let progress = try SwiftDataProgressStoreReadBackTests.progress()
            try await store.record(
                answer: SwiftDataProgressStoreReadBackTests.answer(),
                progress: progress,
            )
            #expect(try await store.loadProgress() == [progress])

            let reopenedVersion = try Fixture.modelVersion(of: url)
            #expect(reopenedVersion.entities == ["AnswerRecord", "CardProgressRecord"])
            #expect(reopenedVersion.identifiers == written.identifiers)
            #expect(written.identifiers == ["1.0.0"])
            #expect(written.entities == ["TodoRecord"])
        }

        @Test
        func `a file that is not a store fails to open`() throws {
            let directory = try Fixture.scratchDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appending(path: "not-a.store")
            try Data("not a SQLite database".utf8).write(to: url)

            #expect(throws: (any Error).self) {
                try PersistenceStore.makeContainer(storage: .file(url))
            }
        }
    }
}
