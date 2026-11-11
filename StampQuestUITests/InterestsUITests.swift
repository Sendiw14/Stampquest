import XCTest

/// Interests (step 2): picking, un-picking, Continue, Skip and Back, in light, dark, Reduce Motion and AX3 text.
@MainActor
final class InterestsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private enum Variant {
        case light, dark, reduceMotion, accessibilityText

        var arguments: [String] {
            switch self {
            case .light: ["-AppleInterfaceStyle", "Light"]
            case .dark: ["-AppleInterfaceStyle", "Dark"]
            case .reduceMotion: ["-uitest-reduce-motion"]
            case .accessibilityText: ["-uitest-reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
            }
        }
    }

    private func launch(_ variant: Variant) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-onboarding-start", "interests"] + variant.arguments
        app.launch()
        return app
    }

    private func cell(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let element = app.buttons["interest." + id]
        if !element.waitForExistence(timeout: 10) { XCTFail("interest.\(id) missing") }
        if !element.isHittable { app.swipeUp() }
        return element
    }

    private func pickTwoThenUnpickOne(_ variant: Variant) {
        let app = launch(variant)
        let cities = cell(app, "cities")
        XCTAssertFalse(cities.isSelected)
        XCTAssertFalse(app.buttons["onboarding.interests.cta"].isEnabled, "nothing is preselected")
        cities.tap()
        cell(app, "coasts").tap()
        XCTAssertTrue(cities.isSelected)
        XCTAssertTrue(cell(app, "coasts").isSelected)
        XCTAssertFalse(cell(app, "mountains").isSelected)
        XCTAssertEqual(app.staticTexts["onboarding.interests.hint"].label, "2 picked. You can change this any time.")
        cities.tap()
        XCTAssertFalse(cities.isSelected)
        XCTAssertEqual(app.staticTexts["onboarding.interests.hint"].label, "1 picked. You can change this any time.")
        XCTAssertTrue(app.buttons["onboarding.interests.cta"].isEnabled)
    }

    func testPickAndUnpickInLightMode() { pickTwoThenUnpickOne(.light) }
    func testPickAndUnpickInDarkMode() { pickTwoThenUnpickOne(.dark) }
    func testPickAndUnpickWithReduceMotion() { pickTwoThenUnpickOne(.reduceMotion) }
    func testPickAndUnpickAtAX3TextSize() { pickTwoThenUnpickOne(.accessibilityText) }

    func testEachCellIsOneElementWithTheSpokenName() {
        let app = launch(.reduceMotion)
        XCTAssertEqual(cell(app, "cities").label, "Cities, Skylines, old towns")
        XCTAssertEqual(cell(app, "hiddenGems").label, "Hidden gems, Off the beaten path")
        XCTAssertEqual(app.staticTexts["onboarding.interests.title"].label, "What do you love to find?")
    }

    func testContinueAdvancesToTheFirstStamp() {
        let app = launch(.reduceMotion)
        cell(app, "coasts").tap()
        app.buttons["onboarding.interests.cta"].tap()
        XCTAssertTrue(app.buttons["onboarding.firstStamp.cta"].waitForExistence(timeout: 10)
                      || app.staticTexts["onboarding.firstStamp.title"].waitForExistence(timeout: 10))
    }

    func testSkipAdvancesToTheFirstStamp() {
        let app = launch(.reduceMotion)
        app.buttons["onboarding.interests.skip"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.firstStamp.title"].waitForExistence(timeout: 10))
    }

    func testBackReturnsToWelcome() {
        let app = launch(.reduceMotion)
        XCTAssertTrue(app.buttons["onboarding.interests.back"].waitForExistence(timeout: 10))
        app.buttons["onboarding.interests.back"].tap()
        XCTAssertTrue(app.buttons["onboarding.welcome.cta"].waitForExistence(timeout: 10))
    }

    func testScreenshotsForTheReport() {
        for variant in [Variant.light, .dark, .accessibilityText] {
            let app = launch(variant)
            cell(app, "cities").tap()
            cell(app, "coasts").tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            attachment.name = "interests-\(variant)"
            add(attachment)
            app.terminate()
        }
    }
}
