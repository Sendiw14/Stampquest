import XCTest

/// The Plus paywall on a fake subscription client (`-uitest-subscriptions`): plan switching, close, success, unavailable, restore.
@MainActor
final class PlusUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ scenario: String = "ok", notifications: String = "authorized") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-reduce-motion", "-ff-plus", "-uitest-onboarding-start", "plus",
                               "-uitest-subscriptions", scenario, "-uitest-notifications", notifications]
        app.launch()
        return app
    }

    private func cta(_ app: XCUIApplication) -> XCUIElement { app.buttons["onboarding.plus.cta"] }

    func testSelectingMonthlyChangesTheCallToActionAndTheTimeline() {
        let app = launch()
        XCTAssertTrue(cta(app).waitForExistence(timeout: 30))
        let yearlyCTA = NSPredicate(format: "label == 'Start 7-day free trial'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: yearlyCTA, object: cta(app))], timeout: 30), .completed)
        XCTAssertTrue(app.otherElements["onboarding.plus.timeline"].label.contains("We remind you"))
        app.buttons["onboarding.plus.plan.monthly"].tap()
        let monthlyCTA = NSPredicate(format: "label == 'Subscribe for $4.99 per month'")
        let switched = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: monthlyCTA, object: cta(app))], timeout: 15)
        XCTAssertEqual(switched, .completed, "CTA label is '\(cta(app).label)', monthly plan selected: \(app.buttons["onboarding.plus.plan.monthly"].isSelected)")
        let timeline = app.otherElements["onboarding.plus.timeline"].label
        XCTAssertTrue(timeline.contains("Billed $4.99") && !timeline.contains("We remind you"))
    }

    func testSuccessShowsTheBannerThenFinishesOnboarding() {
        let app = launch()
        XCTAssertTrue(cta(app).waitForExistence(timeout: 30))
        let ready = NSPredicate(format: "label == 'Start 7-day free trial'")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: ready, object: cta(app))], timeout: 30)
        cta(app).tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.plus.banner"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["onboarding.plus.banner"].label, "Trial started. Welcome to Plus.")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 30))
    }

    func testUnavailableShowsTheMessageAndTryAgain() {
        let app = launch("unavailable")
        XCTAssertTrue(app.buttons["onboarding.plus.retry"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Can’t load plans right now."].exists)
        XCTAssertTrue(app.buttons["onboarding.plus.close"].isHittable)
    }

    func testRestoreWithNothingFoundShowsTheMessage() {
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.plus.restore"].waitForExistence(timeout: 30))
        let ready = NSPredicate(format: "isEnabled == true")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: ready, object: app.buttons["onboarding.plus.restore"])], timeout: 30)
        app.buttons["onboarding.plus.restore"].tap()
        XCTAssertTrue(app.staticTexts["No purchases to restore."].waitForExistence(timeout: 5))
    }

    func testTermsAndPrivacyAreAlwaysThere() {
        let app = launch("unavailable")
        XCTAssertTrue(app.buttons["onboarding.plus.restore"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.links["onboarding.plus.terms"].exists || app.buttons["onboarding.plus.terms"].exists)
        XCTAssertTrue(app.links["onboarding.plus.privacy"].exists || app.buttons["onboarding.plus.privacy"].exists)
    }
}

extension PlusUITests {
    /// With the flag on, Continue on Passport ready opens the Plus paywall instead of finishing.
    func testPassportReadyContinueGoesToPlusWhenTheFlagIsOn() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-reduce-motion", "-ff-plus", "-uitest-onboarding-start", "passportReady",
                               "-uitest-subscriptions", "ok"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.ready.cta"].waitForExistence(timeout: 30))
        app.buttons["onboarding.ready.cta"].tap()
        XCTAssertTrue(app.buttons["onboarding.plus.close"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.tabBars.buttons["Home"].exists)
    }
}
