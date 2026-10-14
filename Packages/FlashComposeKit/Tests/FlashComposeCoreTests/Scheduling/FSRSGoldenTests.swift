import FlashComposeCore
import Testing

/// The port against ts-fsrs 5.4.2 itself: every history step and retrievability row of
/// `fsrs-golden.json`, compared with `==` on the decoded `Double`s, never a tolerance.
@Suite("FSRS-6 against the golden vectors")
struct FSRSGoldenTests {
    /// The day every retrievability row's last answer is placed on; any day would do.
    static let answeredOn = "2026-10-01"

    let scheduler = FSRSScheduler()

    private static func grade(_ name: String) throws -> Grade {
        switch name {
        case "again":
            .again

        case "hard":
            .hard

        case "good":
            .good

        default:
            throw FSRSGolden.FixtureError.unknownGrade(name)
        }
    }

    @Test
    func `the vectors come from ts-fsrs 5.4.2`() throws {
        let golden = try FSRSGolden.load()
        #expect(golden.header.generator.contains("v5.4.2"))
    }

    @Test
    func `the fixture holds 41 histories and 56 retrievability rows`() throws {
        let golden = try FSRSGolden.load()
        #expect(golden.histories.count == 41)
        #expect(golden.retrievability.count == 56)
    }

    @Test(arguments: try FSRSGolden.load().histories)
    func `every step's preview of the three grades matches ts-fsrs`(
        history: FSRSGolden.History,
    ) throws {
        var state: FSRSState?
        for step in history.steps {
            let today = try DomainValuesFixture.day(step.day)
            let preview = scheduler.preview(state, on: today, seedKey: history.cardId)
            #expect(try preview == step.preview.gradePreview(), "\(history.cardId) on \(step.day)")
            state = try preview[Self.grade(step.grade)].state
        }
    }

    @Test(arguments: try FSRSGolden.load().retrievability)
    func `every retrievability row matches ts-fsrs's forgetting curve`(
        row: FSRSGolden.RetrievabilityRow,
    ) throws {
        let lastDay = try DomainValuesFixture.day(Self.answeredOn)
        let state = FSRSState(
            stability: row.stability,
            difficulty: DomainValuesFixture.difficulty,
            reps: DomainValuesFixture.reps,
            lapses: DomainValuesFixture.lapses,
            lastDay: lastDay,
            dueDay: lastDay,
        )
        let today = lastDay.adding(days: row.elapsedDays)
        #expect(scheduler.retrievability(of: state, on: today) == row.retrievability)
    }
}
