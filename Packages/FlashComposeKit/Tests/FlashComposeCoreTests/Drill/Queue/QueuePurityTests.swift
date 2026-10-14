import Foundation
import Testing

/// The queue is pure logic: it imports nothing — so no UI, storage, clock, calendar, or
/// time zone type is in reach — and every random draw goes through the generator the
/// caller injects (`docs/architecture.md` › Principles, `designing-core-logic`).
@Suite("Queue purity")
struct QueuePurityTests {
    static let queueDirectory = ArchitectureBoundaryTests.coreSourcesDirectory
        .appendingPathComponent("Drill", isDirectory: true)
        .appendingPathComponent("Queue", isDirectory: true)

    /// Every Swift file under `Sources/FlashComposeCore/Drill/Queue`, with its lines.
    static func sources() throws -> [(name: String, lines: [Substring])] {
        let names = try FileManager.default.contentsOfDirectory(atPath: queueDirectory.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        return try names.map { name in
            let text = try String(
                contentsOf: queueDirectory.appendingPathComponent(name),
                encoding: .utf8,
            )
            return (name, text.split(separator: "\n", omittingEmptySubsequences: false))
        }
    }

    @Test
    func `the queue's sources exist where this suite looks`() throws {
        #expect(try Self.sources().map(\.name).contains("DrillSession.swift"))
    }

    @Test
    func `no queue source imports a module`() throws {
        let imports = try Regex(#"^\s*(@[\w()]+\s+)*import\s"#)
        for source in try Self.sources() {
            let offending = source.lines.filter { $0.contains(imports) }
            #expect(offending.isEmpty, "\(source.name) imports \(offending)")
        }
    }

    @Test
    func `no queue source names a clock, a date, a time zone, or the system RNG`() throws {
        let worldly = try Regex(
            #"\b(Date|TimeZone|Calendar|Clock|ContinuousClock|SuspendingClock|SystemRandomNumberGenerator)\b"#,
        ).wordBoundaryKind(.simple)
        for source in try Self.sources() {
            let offending = source.lines.filter { $0.contains(worldly) }
            #expect(offending.isEmpty, "\(source.name) names \(offending)")
        }
    }

    @Test
    func `every random draw in the queue uses the injected generator`() throws {
        let draw = try Regex(#"\b(random|randomElement|shuffled|shuffle)\("#)
        for source in try Self.sources() {
            let unseeded = source.lines.filter { $0.contains(draw) && !$0.contains("using:") }
            #expect(unseeded.isEmpty, "\(source.name) draws without a generator: \(unseeded)")
        }
    }
}
