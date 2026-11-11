import XCTest

/// Home: first run, a returning passport, Collect, the swap and the failure path.
@MainActor
final class HomeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["home-collect"].waitForExistence(timeout: 15))
        return app
    }

    private func title(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: "home-today-title").firstMatch }

    func testFirstRunShowsParisAndHowItWorksNotAZeroState() {
        let app = launch()
        XCTAssertTrue(title(app).label.hasPrefix("Featured today: Paris"), title(app).label)
        XCTAssertTrue(app.descendants(matching: .any)["home-explore"].exists)
        XCTAssertFalse(app.staticTexts["Finish the set"].exists)
        XCTAssertFalse(app.staticTexts["Your atlas"].exists)
    }

    func testReturningHomeSummaryAndModules() {
        let app = launch(["-uitest-seed", "few"])
        let summary = app.descendants(matching: .any)["home-hero-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.hasPrefix("Your passport has 5 stamps"), summary.label)
        XCTAssertFalse(app.staticTexts["How it works"].exists)
    }

    func testSwapExchangesTheFeaturedStamp() {
        let app = launch(["-uitest-seed", "few"])
        let before = title(app).label
        app.descendants(matching: .any)["home-side-stamp"].tap()
        let after = title(app)
        let changed = NSPredicate(format: "label != %@", before)
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: changed, object: after)], timeout: 5), .completed)
    }

    func testCollectSavesAndOpensTheReveal() {
        let app = launch()
        app.buttons["home-collect"].tap()
        XCTAssertTrue(app.staticTexts["reveal"].waitForExistence(timeout: 12), "the reveal shows \"Added to your passport\" after the save")
    }
}
