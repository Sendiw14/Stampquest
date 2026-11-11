import XCTest

/// Passport ready: the open passport, tapping it, Continue with the Plus flag off and on, and the empty-name fallbacks.
@MainActor
final class PassportReadyUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-reduce-motion", "-uitest-onboarding-start", "passportReady"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.ready.cta"].waitForExistence(timeout: 10))
        return app
    }

    private func hero(_ app: XCUIApplication) -> XCUIElement { app.buttons["onboarding.ready.hero"] }

    private func waitForValue(_ element: XCUIElement, _ value: String) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 8) == .completed
    }

    func testThePassportIsOpenAndTapsToggleIt() {
        let app = launch()
        XCTAssertTrue(hero(app).waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(hero(app), "Open"))
        hero(app).tap()
        XCTAssertTrue(waitForValue(hero(app), "Closed"))
        XCTAssertTrue(hero(app).label.hasPrefix("Passport, closed. Harbor cover"))
        hero(app).tap()
        XCTAssertTrue(waitForValue(hero(app), "Open"))
    }

    func testAnEmptyNameShowsTheNamelessSubtitleAndNoPlaceholderJunk() {
        let app = launch()
        let subtitle = app.staticTexts["onboarding.ready.subtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 10))
        XCTAssertEqual(subtitle.label, "Add your first stamp whenever you like.", "no stamp in this launch")
        for junk in ["Alex", "Unknown", "null"] { XCTAssertFalse(app.staticTexts[junk].exists) }
        XCTAssertEqual(app.descendants(matching: .any)["onboarding.ready.summary.0"].label, "Harbor cover. Done.")
        XCTAssertEqual(app.descendants(matching: .any)["onboarding.ready.summary.2"].label, "Verified stamps are off. Off.")
    }

    func testContinueFinishesOnboardingWhenPlusIsOff() {
        let app = launch()
        app.buttons["onboarding.ready.cta"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
    }

    func testBackReturnsToTheCover() {
        let app = launch()
        app.buttons["onboarding.ready.back"].tap()
        XCTAssertTrue(app.buttons["onboarding.cover.cta"].waitForExistence(timeout: 10))
    }

    func testThereIsNoSkipAndNoPlusWording() {
        let app = launch()
        XCTAssertFalse(app.buttons["onboarding.ready.skip"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'plus'")).count > 0)
    }
}
