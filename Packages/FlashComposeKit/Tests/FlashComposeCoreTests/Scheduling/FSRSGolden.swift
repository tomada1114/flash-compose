import FlashComposeCore
import Foundation
import Testing

/// `fsrs-golden.json`: what ts-fsrs 5.4.2 itself scheduled, run outside this repository
/// (the file's `header` and `script` hold its options, inputs, and generator).
///
/// Decoded with `JSONDecoder` straight into `Double`, which parses each shortest
/// round-trip decimal JavaScript wrote back to the same bits.
struct FSRSGolden: Decodable {
    /// Why the fixture could not be read; a broken resource, never a product failure.
    enum FixtureError: Error {
        case missingResource
        case unknownGrade(String)
    }

    struct Header: Decodable {
        let generator: String
    }

    struct RetrievabilityRow: Decodable, Sendable, CustomTestStringConvertible {
        let stability: Double
        let elapsedDays: Int
        let retrievability: Double

        var testDescription: String {
            "S \(stability) after \(elapsedDays) days"
        }
    }

    struct State: Decodable, Sendable {
        let stability: Double
        let difficulty: Double
        let reps: Int
        let lapses: Int
        let lastDay: String
        let dueDay: String

        func fsrsState() throws -> FSRSState {
            try FSRSState(
                stability: stability,
                difficulty: difficulty,
                reps: reps,
                lapses: lapses,
                lastDay: DomainValuesFixture.day(lastDay),
                dueDay: DomainValuesFixture.day(dueDay),
            )
        }
    }

    struct Outcome: Decodable, Sendable {
        let state: State
        let intervalDays: Int

        func gradeOutcome() throws -> GradeOutcome {
            try GradeOutcome(state: state.fsrsState(), intervalDays: intervalDays)
        }
    }

    struct Preview: Decodable, Sendable {
        let again: Outcome
        let hard: Outcome
        let good: Outcome

        func gradePreview() throws -> GradePreview {
            try GradePreview(
                again: again.gradeOutcome(),
                hard: hard.gradeOutcome(),
                good: good.gradeOutcome(),
            )
        }
    }

    struct Step: Decodable, Sendable {
        let day: String
        let grade: String
        let preview: Preview
    }

    struct History: Decodable, Sendable, CustomTestStringConvertible {
        let cardId: String
        let steps: [Step]

        var testDescription: String {
            cardId
        }
    }

    let header: Header
    let retrievability: [RetrievabilityRow]
    let histories: [History]

    /// The fixture as the test target's bundle holds it.
    static func load() throws -> Self {
        guard let url = Bundle.module.url(forResource: "fsrs-golden", withExtension: "json") else {
            throw FixtureError.missingResource
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
