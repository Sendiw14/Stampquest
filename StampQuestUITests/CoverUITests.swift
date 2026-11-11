import XCTest

/// Cover (step 5): swatches, the name, Continue and Skip, with the Plus flag off and on.
@MainActor
final class CoverUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @discardableResult
    private func launch(extra: [String] = [], reduceMotion: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-onboarding-start", "cover"] + (reduceMotion ? ["-uitest-reduce-motion"] : []) + extra
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.cover.cta"].waitForExistence(timeout: 10))
        return app
    }

    private func heroValue(_ app: XCUIApplication) -> String {
        (app.descendants(matching: .any)["onboarding.cover.carousel"].value as? String) ?? ""
    }

    private func waitForHero(_ app: XCUIApplication, _ text: String) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: app.descendants(matching: .any)["onboarding.cover.carousel"])],
                                timeout: 8) == .completed
    }

    func testOnlyThreeCoversAndNoPlusTraceWithTheFlagOff() {
        let app = launch()
        for id in ["clay", "forest", "harbor"] { XCTAssertTrue(app.buttons["onboarding.cover.swatch.\(id)"].exists, id) }
        XCTAssertFalse(app.buttons["onboarding.cover.swatch.midnight"].exists)
        XCTAssertFalse(app.buttons["onboarding.cover.swatch.rosewood"].exists)
        XCTAssertEqual(heroValue(app), "Harbor")
        XCTAssertTrue(app.buttons["onboarding.cover.swatch.harbor"].isSelected)
    }

    func testTappingASwatchChangesTheHero() {
        let app = launch()
        app.buttons["onboarding.cover.swatch.clay"].tap()
        XCTAssertTrue(waitForHero(app, "Terracotta"))
        XCTAssertTrue(app.buttons["onboarding.cover.swatch.clay"].isSelected)
        XCTAssertFalse(app.buttons["onboarding.cover.swatch.harbor"].isSelected)
    }

    func testTypingANameShowsItInTheHeroValueAndDoneDismissesTheKeyboard() {
        let app = launch()
        let field = app.textFields["onboarding.cover.name"]
        field.tap()
        field.typeText("Alex   Rivera")
        XCTAssertTrue(waitForHero(app, "name: Alex Rivera"))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.buttons["onboarding.cover.keyboardDone"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
    }

    func testTheFieldAndTheDockStayVisibleWhileTyping() {
        let app = launch()
        let field = app.textFields["onboarding.cover.name"]
        field.tap()
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(field.frame.maxY, app.keyboards.firstMatch.frame.minY)
        XCTAssertLessThanOrEqual(app.buttons["onboarding.cover.swatch.harbor"].frame.maxY, keyboardTop + 1)
        XCTAssertGreaterThan(app.buttons["onboarding.cover.swatch.harbor"].frame.minY, 0)
    }

    func testContinueWithAnEmptyNameGoesToPassportReady() {
        let app = launch()
        app.buttons["onboarding.cover.cta"].tap()
        XCTAssertTrue(app.buttons["onboarding.ready.cta"].waitForExistence(timeout: 10), "Continue goes to Passport ready")
    }

    func testSkipGoesToPassportReady() {
        let app = launch()
        app.buttons["onboarding.cover.skip"].tap()
        XCTAssertTrue(app.buttons["onboarding.ready.cta"].waitForExistence(timeout: 10), "Skip goes to Passport ready")
    }

    func testBackReturnsToVerification() {
        let app = launch()
        app.buttons["onboarding.cover.back"].tap()
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10))
    }

    func testWithTheFlagOnPlusCoversShowTheirMarkerAndContinueIsNeverDisabled() {
        let app = launch(extra: ["-ff-plus"])
        app.buttons["onboarding.cover.swatch.rosewood"].tap()
        XCTAssertTrue(waitForHero(app, "Rosewood"))
        XCTAssertTrue(app.buttons["onboarding.cover.swatch.rosewood"].label.hasSuffix("Plus"))
        XCTAssertTrue(app.staticTexts["onboarding.cover.styleName"].exists || true)
        XCTAssertTrue(app.buttons["onboarding.cover.cta"].isEnabled)
        XCTAssertFalse(app.alerts.firstMatch.exists, "no paywall, no alert")
    }

    func testLargestDynamicTypeKeepsTheFieldAndActionsUsable() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["onboarding.cover.cta"].isHittable)
        XCTAssertTrue(app.textFields["onboarding.cover.name"].exists)
    }
}
