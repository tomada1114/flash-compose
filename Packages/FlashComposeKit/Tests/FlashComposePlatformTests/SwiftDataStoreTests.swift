import FlashComposeCore
@testable import FlashComposePlatform
import Foundation
import Testing

/// Every suite that opens a SwiftData container, nested in one `.serialized` parent, plus
/// what holds for the store whichever adapter uses it: two in-memory stores share nothing.
///
/// SwiftData runs on the host with an in-memory store, so these run under plain
/// `just test` and in CI — no simulator, no device, no permission grant.
///
/// `.serialized`: each test opens its own `ModelContainer`. A parallel run once crashed
/// the test process (signal 11) on a CI runner, and concurrent container creation is
/// the prime suspect — the one thing only these suites do. One container at a time
/// costs milliseconds; a flaky crash costs every pull request a rerun. Every other test
/// that opens a container is a suite nested in this one (`PersistenceStoreTests`,
/// `SwiftDataProgressStoreTests`, `SwiftDataProgressStoreReadBackTests`), so the trait
/// covers it too.
@Suite("SwiftData", .serialized)
struct SwiftDataStoreTests {
    @Test
    func `two in-memory stores share nothing`() async throws {
        let first = try SwiftDataProgressStore(
            modelContainer: PersistenceStore.makeContainer(storage: .inMemory),
        )
        let second = try SwiftDataProgressStore(
            modelContainer: PersistenceStore.makeContainer(storage: .inMemory),
        )
        let progress = try SwiftDataProgressStoreReadBackTests.progress()
        try await first.record(
            answer: SwiftDataProgressStoreReadBackTests.answer(),
            progress: progress,
        )
        #expect(try await first.loadProgress() == [progress])
        #expect(try await second.loadProgress().isEmpty)
    }
}
