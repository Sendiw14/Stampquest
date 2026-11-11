import XCTest

/// First stamp (step 3): collecting, the save error and "Try again", Skip and Back, in light, dark, Reduce Motion and AX3.
@MainActor
final class FirstStampUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private enum Variant {
        case light, dark, reduceMotion, accessibilityText

        var arguments: [String] {
            switch self {
            case .light: ["-AppleInterfaceStyle", "Light", "-uitest-reduce-motion"]
            case .dark: ["-AppleInterfaceStyle", "Dark", "-uitest-reduce-motion"]
            case .reduceMotion: ["-uitest-reduce-motion"]
            case .accessibilityText: ["-uitest-reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
            }
        }
    }

    private func launch(_ variant: Variant = .reduceMotion, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-onboarding-start", "firstStamp"] + variant.arguments + extra
        app.launch()
        return app
    }

    private func starter(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let element = app.buttons["starter." + id]
        if !element.waitForExistence(timeout: 10) { XCTFail("starter.\(id) missing") }
        return element
    }

    private func collectParis(_ variant: Variant) {
        let app = launch(variant)
        let title = app.staticTexts["onboarding.firstStamp.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Choose your first stamp")
        let cta = app.buttons["onboarding.firstStamp.cta"]
        XCTAssertFalse(cta.isEnabled)
        starter(app, "paris").tap()
        XCTAssertTrue(cta.waitForEnabled(timeout: 10))
        XCTAssertEqual(title.label, "That’s your first stamp.")
        XCTAssertTrue(app.staticTexts["onboarding.firstStamp.status"].label.hasPrefix("Collected today."))
        XCTAssertEqual(app.otherElements["onboarding.firstStamp.slot1"].label, "Slot 1, Paris stamp, collected today")
        XCTAssertFalse(starter(app, "kyoto").isEnabled)
        XCTAssertEqual(starter(app, "kyoto").label, "Kyoto, Japan, dimmed")
    }

    func testCollectingParisInLightMode() { collectParis(.light) }
    func testCollectingParisInDarkMode() { collectParis(.dark) }
    func testCollectingParisWithReduceMotion() { collectParis(.reduceMotion) }
    func testCollectingParisAtAX3TextSize() { collectParis(.accessibilityText) }

    func testEachStarterIsOneElementWithTheSpokenName() {
        let app = launch()
        XCTAssertEqual(starter(app, "paris").label, "Paris, France")
        XCTAssertEqual(starter(app, "santorini").label, "Santorini, Greece")
    }

    func testASaveFailureShowsTheErrorAndTryAgainRecovers() {
        let app = launch(extra: ["-simulateCollectFailure"])
        starter(app, "paris").tap()
        let tryAgain = app.buttons["onboarding.firstStamp.tryAgain"]
        XCTAssertTrue(tryAgain.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["onboarding.firstStamp.error"].label, "Couldn’t save your stamp.")
        XCTAssertFalse(app.buttons["onboarding.firstStamp.cta"].isEnabled, "Continue stays disabled")
        XCTAssertTrue(app.buttons["onboarding.firstStamp.skip"].isEnabled, "Skip still works")
        tryAgain.tap()
        XCTAssertTrue(app.buttons["onboarding.firstStamp.cta"].waitForEnabled(timeout: 10))
        XCTAssertEqual(app.staticTexts["onboarding.firstStamp.title"].label, "That’s your first stamp.")
    }

    func testSkipWorksFromChoosing() {
        let app = launch()
        app.buttons["onboarding.firstStamp.skip"].tap()
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10))
    }

    func testSkipWorksFromCollected() {
        let app = launch()
        starter(app, "kyoto").tap()
        XCTAssertTrue(app.buttons["onboarding.firstStamp.cta"].waitForEnabled(timeout: 10))
        app.buttons["onboarding.firstStamp.skip"].tap()
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10))
    }

    func testContinueAdvancesAfterCollecting() {
        let app = launch()
        starter(app, "santorini").tap()
        XCTAssertTrue(app.buttons["onboarding.firstStamp.cta"].waitForEnabled(timeout: 10))
        app.buttons["onboarding.firstStamp.cta"].tap()
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10))
    }

    func testBackReturnsToInterests() {
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.firstStamp.back"].waitForExistence(timeout: 10))
        app.buttons["onboarding.firstStamp.back"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.interests.title"].waitForExistence(timeout: 10))
    }

    func testScreenshotsForTheReport() {
        for variant in [Variant.light, .dark, .accessibilityText] {
            let app = launch(variant)
            XCTAssertTrue(starter(app, "paris").waitForExistence(timeout: 10))
            attach(app, "first-stamp-choosing-\(variant)")
            starter(app, "paris").tap()
            XCTAssertTrue(app.buttons["onboarding.firstStamp.cta"].waitForEnabled(timeout: 10))
            attach(app, "first-stamp-collected-\(variant)")
            app.terminate()
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        attachment.name = name
        add(attachment)
    }
}

private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
