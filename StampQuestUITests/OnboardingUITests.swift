import XCTest

/// Onboarding journeys: Welcome, Interests and First stamp are real screens; Verification, Cover and Passport ready are
/// still placeholders (their Continue/Skip really navigate). Most runs use the DEBUG `-uitest-reduce-motion` argument for speed.
@MainActor
final class OnboardingUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @discardableResult
    private func launch(reduceMotion: Bool = true, reset: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args: [String] = []
        if reset { args.append("-uitest-reset") }
        if reduceMotion { args.append("-uitest-reduce-motion") }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    private func tap(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "\(id) missing", file: file, line: line)
        button.tap()
    }

    private func toInterests(_ app: XCUIApplication) {
        tap(app, "onboarding.welcome.cta")
        XCTAssertTrue(app.staticTexts["onboarding.interests.title"].waitForExistence(timeout: 10))
    }

    // MARK: Welcome

    func testWelcomeCTAExistsAndGoesToInterests() {
        let app = launch()
        let cta = app.buttons["onboarding.welcome.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(cta.frame.height, 44)
        XCTAssertFalse(app.buttons["onboarding.welcome.skip"].exists, "Welcome has no Skip")
        XCTAssertFalse(app.buttons["onboarding.welcome.back"].exists, "Welcome has no Back")
        cta.tap()
        XCTAssertTrue(app.staticTexts["onboarding.interests.title"].waitForExistence(timeout: 10))
    }

    /// With motion on the CTA only takes taps once the intro has revealed it, so keep tapping until Interests appears.
    func testWelcomeWorksWithMotionOn() {
        let app = launch(reduceMotion: false)
        XCTAssertTrue(app.buttons["onboarding.welcome.cta"].waitForExistence(timeout: 10))
        let title = app.staticTexts["onboarding.interests.title"]
        for _ in 0..<12 where !title.exists {
            app.buttons["onboarding.welcome.cta"].tap()
            _ = title.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(title.waitForExistence(timeout: 10))
    }

    // MARK: Interests

    func testInterestsContinueIsDisabledUntilATileIsPickedAndTheHintUpdates() {
        let app = launch()
        toInterests(app)
        let cta = app.buttons["onboarding.interests.cta"]
        XCTAssertFalse(cta.isEnabled, "nothing is preselected")
        XCTAssertEqual(app.staticTexts["onboarding.interests.hint"].label, "Pick at least one to continue.")
        app.buttons["interest.coasts"].tap()
        XCTAssertTrue(cta.waitForEnabled())
        XCTAssertEqual(app.staticTexts["onboarding.interests.hint"].label, "1 picked. You can change this any time.")
        app.buttons["interest.cities"].tap()
        XCTAssertEqual(app.staticTexts["onboarding.interests.hint"].label, "2 picked. You can change this any time.")
        app.buttons["interest.coasts"].tap()
        app.buttons["interest.cities"].tap()
        XCTAssertFalse(cta.isEnabled, "deselecting everything disables Continue again")
    }

    func testInterestsSkipGoesToFirstStamp() {
        let app = launch()
        toInterests(app)
        tap(app, "onboarding.interests.skip")
        XCTAssertTrue(app.staticTexts["onboarding.firstStamp.title"].waitForExistence(timeout: 10))
    }

    func testInterestsRankTheTray() {
        let app = launch()
        toInterests(app)
        app.buttons["interest.coasts"].tap()
        tap(app, "onboarding.interests.cta")
        // Coasts puts Santorini first in the tray: its stamp sits left of Paris.
        let santorini = app.buttons["starter.santorini"], paris = app.buttons["starter.paris"]
        XCTAssertTrue(santorini.waitForExistence(timeout: 10))
        XCTAssertLessThan(santorini.frame.minX, paris.frame.minX)
    }

    // MARK: First stamp

    func testChoosingAStampSavesItEnablesContinueAndLocksTheChoice() {
        let app = launch()
        toInterests(app)
        tap(app, "onboarding.interests.skip")
        let cta = app.buttons["onboarding.firstStamp.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10))
        XCTAssertFalse(cta.isEnabled)
        XCTAssertEqual(app.staticTexts["onboarding.firstStamp.title"].label, "Choose your first stamp")
        app.buttons["starter.paris"].tap()
        XCTAssertTrue(cta.waitForEnabled(timeout: 10))
        XCTAssertEqual(app.staticTexts["onboarding.firstStamp.title"].label, "That’s your first stamp.")
        XCTAssertFalse(app.buttons["starter.kyoto"].isEnabled)
        XCTAssertFalse(app.buttons["starter.santorini"].isEnabled)
        XCTAssertTrue(app.staticTexts["onboarding.firstStamp.status"].label.hasPrefix("Collected today."))
    }

    func testFirstStampSkipLeavesAnEmptyPassport() {
        let app = launch()
        toInterests(app)
        tap(app, "onboarding.interests.skip")
        tap(app, "onboarding.firstStamp.skip")
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10))
    }

    func testBackFromVerificationShowsTheLandedStampWithoutReplay() {
        let app = launch()
        toInterests(app)
        tap(app, "onboarding.interests.skip")
        app.buttons["starter.kyoto"].tap()
        tap(app, "onboarding.firstStamp.cta")
        tap(app, "onboarding.verification.back")
        XCTAssertTrue(app.staticTexts["onboarding.firstStamp.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["onboarding.firstStamp.title"].label, "That’s your first stamp.")
        XCTAssertTrue(app.buttons["onboarding.firstStamp.cta"].isEnabled)
    }

    // MARK: Whole flow

    func testHappyPathReachesTheMainAppAndIsNotReplayed() {
        let app = launch(extra: ["-uitest-location", "undetermined-then-allow"])
        toInterests(app)
        app.buttons["interest.cities"].tap()
        tap(app, "onboarding.interests.cta")
        app.buttons["starter.paris"].tap()
        tap(app, "onboarding.firstStamp.cta")
        tap(app, "onboarding.verification.cta")
        tap(app, "onboarding.verification.explainer.continue")
        tap(app, "onboarding.cover.cta")
        tap(app, "onboarding.ready.cta")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        app.terminate()

        let again = launch(reset: false)
        XCTAssertTrue(again.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(again.buttons["onboarding.welcome.cta"].exists)
    }

    func testSkipPathReachesTheMainApp() {
        let app = launch()
        toInterests(app)
        tap(app, "onboarding.interests.skip")
        tap(app, "onboarding.firstStamp.skip")
        tap(app, "onboarding.verification.skip")
        tap(app, "onboarding.cover.skip")
        tap(app, "onboarding.ready.cta")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
    }

    func testRelaunchResumesAtTheFurthestScreenAndKeepsTheStamp() {
        let app = launch()
        toInterests(app)
        app.buttons["interest.coasts"].tap()
        tap(app, "onboarding.interests.cta")
        app.buttons["starter.santorini"].tap()
        tap(app, "onboarding.firstStamp.cta")
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10))
        app.terminate()

        let again = launch(reset: false)
        XCTAssertTrue(again.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10), "resumes where it stopped")
        tap(again, "onboarding.verification.back")
        XCTAssertEqual(again.staticTexts["onboarding.firstStamp.title"].label, "That’s your first stamp.", "the saved stamp is never re-collected")
    }

    // MARK: Accessibility sizes

    func testLargestDynamicTypeKeepsWelcomeInterestsAndFirstStampUsable() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        toInterests(app)
        app.buttons["interest.cities"].tap()
        XCTAssertTrue(app.buttons["onboarding.interests.cta"].waitForEnabled())
        tap(app, "onboarding.interests.cta")
        XCTAssertTrue(app.staticTexts["onboarding.firstStamp.title"].waitForExistence(timeout: 10))
        app.buttons["starter.paris"].tap()
        XCTAssertTrue(app.buttons["onboarding.firstStamp.cta"].waitForEnabled(timeout: 10))
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }

    func waitForLabel(_ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
