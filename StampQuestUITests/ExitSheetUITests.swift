import XCTest

/// The exit sheet over the Plus paywall, on fake subscription and pack clients.
@MainActor
final class ExitSheetUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-reduce-motion", "-ff-plus", "-ff-coasts", "-uitest-onboarding-start", "plus",
                               "-uitest-subscriptions", "ok", "-uitest-packs", "ok", "-uitest-pack-art"] + extra
        app.launch()
        return app
    }

    private func openSheet(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboarding.plus.close"].waitForExistence(timeout: 30))
        app.buttons["onboarding.plus.close"].tap()
        XCTAssertTrue(app.buttons["exitSheet.cta"].waitForExistence(timeout: 10))
    }

    func testCloseOpensTheSheetAndSeePlusAgainReturns() {
        let app = launch()
        openSheet(app)
        app.buttons["exitSheet.link"].tap()
        XCTAssertTrue(app.buttons["onboarding.plus.close"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["exitSheet.cta"].exists)
    }

    func testClosingAgainGoesStraightToFinish() {
        let app = launch()
        openSheet(app)
        app.buttons["exitSheet.close"].tap()
        XCTAssertTrue(app.buttons["onboarding.plus.close"].waitForExistence(timeout: 10))
        app.buttons["onboarding.plus.close"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    }

    func testSwipeDownReturnsToPlus() {
        let app = launch()
        openSheet(app)
        app.buttons["exitSheet.cta"].swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["onboarding.plus.close"].waitForExistence(timeout: 10))
    }

    func testBuyingThePackShowsAddedAndTheCallToActionFinishes() {
        let app = launch()
        openSheet(app)
        XCTAssertTrue(app.buttons["exitSheet.pack.buy"].waitForExistence(timeout: 10))
        app.buttons["exitSheet.pack.buy"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["exitSheet.pack.added"].waitForExistence(timeout: 10))
        app.buttons["exitSheet.cta"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    }

    func testTheContinueButtonFinishesOnboarding() {
        let app = launch()
        openSheet(app)
        app.buttons["exitSheet.cta"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    }

    func testWithTheSheetAlreadyShownCloseGoesStraightToFinish() {
        let app = launch(extra: ["-uitest-exit-shown"])
        XCTAssertTrue(app.buttons["onboarding.plus.close"].waitForExistence(timeout: 30))
        app.buttons["onboarding.plus.close"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
    }
}
