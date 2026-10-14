import XCTest

/// The launch guarantee: the app starts on a simulator, opens on the drill, and the core
/// interaction — reveal the answer, grade it, see the next card — reaches the screen. A
/// failed save (E2) presents its alert from the root and leaves the answer on screen.
///
/// XCTest by necessity — Apple has not ported UI automation to Swift Testing.
/// All other tests use Swift Testing in Packages/FlashComposeKit.
final class LaunchTests: XCTestCase {
    private enum Timeout {
        static let launch: TimeInterval = 20
        static let elementAppears: TimeInterval = 5
    }

    /// An in-memory store and scratch preferences (App/FlashComposeApp.swift), so every run
    /// starts with every card new and the default scope. English, whatever the simulator's
    /// language, because the test finds the alert by its words.
    private static let launchArguments = [
        "-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
    ]

    /// Waits until `element` no longer exists, and reports whether it went.
    @MainActor
    private func waitForDisappearance(of element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element,
        )
        return XCTWaiter().wait(for: [gone], timeout: Timeout.elementAppears) == .completed
    }

    /// The header's one accessibility element, which reads every count as Core's sentence.
    @MainActor
    private func header(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["drillHeader"]
    }

    /// Example 1: D1 with a new card, then D2 with the answer and three grades, then — after
    /// ○ — D1 with the next card, one fewer new card, and the graded card waiting in Again.
    @MainActor
    func testLaunchedAppRevealsAndGradesACard() {
        // A failed assertion should end the test immediately instead of cascading
        // through the remaining waits against a dead app or a wrong screen.
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = Self.launchArguments
        app.launch()

        XCTContext.runActivity(named: "Launch on D1") { _ in launchesOnTheQuestion(in: app) }
        XCTContext.runActivity(named: "Show the answer (D2)") { _ in showTheAnswer(in: app) }
        XCTContext.runActivity(named: "Grade it Got it, then the next D1") { _ in
            gradeAndSeeTheNextCard(in: app)
        }
    }

    /// E2: a grade that cannot be saved presents the alert over the drill, and dismissing
    /// it leaves the same card's answer, with the same counts, ready to grade again.
    ///
    /// A launch of its own, because `-failRecords` (Debug-only, `App/FlashComposeApp.swift`)
    /// fails every grade for the whole launch. It reveals by tapping the card rather than
    /// the button, the other way to reveal.
    @MainActor
    func testAFailedSaveKeepsTheAnswerOnScreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = Self.launchArguments + ["-failRecords"]
        app.launch()

        XCTContext.runActivity(named: "Launch on D1") { _ in launchesOnTheQuestion(in: app) }
        XCTContext.runActivity(named: "Reveal by tapping the card") { _ in
            let prompt = app.staticTexts["drillPrompt"]
            prompt.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(
                app.staticTexts["modelAnswer"].waitForExistence(timeout: Timeout.elementAppears),
                "a tap on the card should reveal the answer, as the button does",
            )
        }
        XCTContext.runActivity(named: "Fail the grade, dismiss the alert") { _ in
            failAGradeAndDismissTheAlert(in: app)
        }
    }

    @MainActor
    private func launchesOnTheQuestion(in app: XCUIApplication) {
        let reveal = app.buttons["showAnswerButton"]
        XCTAssertTrue(
            reveal.waitForExistence(timeout: Timeout.launch),
            "the app should open on the drill's question face",
        )
        XCTAssertTrue(app.staticTexts["drillPrompt"].exists, "D1 should show the prompt")
        XCTAssertFalse(app.staticTexts["modelAnswer"].exists, "D1 should not show the answer")
        let counts = header(in: app)
        XCTAssertTrue(counts.exists, "D1 should show the header counts")
        XCTAssertTrue(
            counts.label.hasSuffix("Again 0. This card is new"),
            "a first launch deals a new card with nothing waiting: \(counts.label)",
        )
    }

    @MainActor
    private func showTheAnswer(in app: XCUIApplication) {
        app.buttons["showAnswerButton"].tap()
        XCTAssertTrue(
            app.staticTexts["modelAnswer"].waitForExistence(timeout: Timeout.elementAppears),
            "Show answer should reveal the model answer",
        )
        for grade in ["again", "hard", "good"] {
            XCTAssertTrue(
                app.buttons["grade-\(grade)"].exists,
                "D2 should offer the \(grade) grade",
            )
        }
        XCTAssertTrue(
            app.buttons["grade-good"].label.hasPrefix("Got it, next in "),
            "a new card's ○ should name the grade and its interval: \(app.buttons["grade-good"].label)",
        )
        XCTAssertFalse(app.buttons["showAnswerButton"].exists, "D2 replaces the reveal button")
    }

    @MainActor
    private func gradeAndSeeTheNextCard(in app: XCUIApplication) {
        let before = header(in: app).label
        app.buttons["grade-good"].tap()
        XCTAssertTrue(
            app.buttons["showAnswerButton"].waitForExistence(timeout: Timeout.elementAppears),
            "a grade should deal the next card's question face",
        )
        XCTAssertTrue(
            waitForDisappearance(of: app.staticTexts["modelAnswer"]),
            "the next card should start on its question",
        )
        let after = header(in: app).label
        XCTAssertNotEqual(after, before, "the counts should follow the grade")
        XCTAssertTrue(
            after.contains("Again 1."),
            "a new card's first Got it should leave it waiting in Again: \(after)",
        )
    }

    @MainActor
    private func failAGradeAndDismissTheAlert(in app: XCUIApplication) {
        let answer = app.staticTexts["modelAnswer"]
        let shownAnswer = answer.label
        let counts = header(in: app).label
        app.buttons["grade-good"].tap()

        let alert = app.alerts["Couldn't save your answer"]
        XCTAssertTrue(
            alert.waitForExistence(timeout: Timeout.elementAppears),
            "a grade that cannot be saved should present E2",
        )
        XCTAssertTrue(
            alert.staticTexts["Tap a grade again"].exists,
            "the alert should say to grade again",
        )
        alert.buttons["OK"].tap()
        XCTAssertTrue(waitForDisappearance(of: alert), "OK should dismiss the alert")
        XCTAssertTrue(answer.exists, "D2 should stay on screen")
        XCTAssertEqual(answer.label, shownAnswer, "the same card should stay")
        XCTAssertEqual(header(in: app).label, counts, "the counts should not change")
        XCTAssertTrue(app.buttons["grade-good"].isHittable, "the grades should take a tap again")
    }
}
