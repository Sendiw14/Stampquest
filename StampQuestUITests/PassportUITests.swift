import XCTest

/// Passport tab: the ticket, the cover, filters, layouts, remove and Undo, the empty state.
@MainActor
final class PassportUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion"] + extra
        app.launch()
        let tab = app.tabBars.buttons["Passport"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(app.staticTexts["passport-subline"].waitForExistence(timeout: 10))
        return app
    }

    private func any(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    func testTicketShowsWholePassportNumbers() {
        let app = launch(["-uitest-seed", "few"])
        XCTAssertEqual(app.staticTexts["passport-subline"].label, "5 stamps from 5 countries")
        XCTAssertTrue(app.buttons["passport-ticket-verified"].label.hasPrefix("2 verified visits"), app.buttons["passport-ticket-verified"].label)
        XCTAssertTrue(app.buttons["passport-ticket-collected"].label.hasPrefix("5 collected stamps"))
    }

    func testVerifiedTicketAppliesAndClearsTheFilter() {
        let app = launch(["-uitest-seed", "few"])
        app.buttons["passport-ticket-verified"].tap()
        XCTAssertTrue(app.staticTexts["passport-count"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["passport-count"].label, "Showing 2 of 5 stamps")
        XCTAssertEqual(app.staticTexts["passport-subline"].label, "5 stamps from 5 countries", "The ticket ignores filters")
        app.buttons["passport-clear-all"].tap()
        XCTAssertFalse(app.staticTexts["passport-count"].waitForExistence(timeout: 2))
    }

    func testFilterSheetCountsLiveAndKeepsChoices() {
        let app = launch(["-uitest-seed", "few"])
        app.buttons["passport-options"].tap()
        XCTAssertTrue(app.buttons["passport-filter-done"].waitForExistence(timeout: 5), "sheet=\(app.descendants(matching: .any)["passport-filter-sheet"].exists) buttons=\(app.buttons.allElementsBoundByIndex.prefix(40).map(\.identifier))")
        XCTAssertEqual(app.buttons["passport-filter-done"].label, "Show 5 stamps")
        let toggle = app.switches["passport-toggle-verified"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "toggle exists: \(app.debugDescription)")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1", "toggle on after tap; buttons: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(app.buttons["Show 2 stamps"].waitForExistence(timeout: 5))
        app.buttons["Show 2 stamps"].tap()
        XCTAssertTrue(app.buttons["passport-chip-verified"].waitForExistence(timeout: 5))
        app.buttons["passport-chip-verified"].tap()
        XCTAssertFalse(app.buttons["passport-chip-verified"].waitForExistence(timeout: 2))
    }

    func testLayoutsSwitchAndCoverOpensPages() {
        let app = launch(["-uitest-seed", "few"])
        let layout = app.segmentedControls["passport-layout"]
        XCTAssertTrue(layout.waitForExistence(timeout: 10))
        layout.buttons["List"].tap()
        XCTAssertTrue(any(app, "passport-row-paris-eiffel-tower").waitForExistence(timeout: 5))
        layout.buttons["Grid"].tap()
        XCTAssertTrue(app.buttons["passport-stamp-paris-eiffel-tower"].waitForExistence(timeout: 5))
        app.buttons["passport-cover"].tap()
        XCTAssertTrue(any(app, "passport-page-1").waitForExistence(timeout: 5), "The cover is a route into the pages")
        XCTAssertTrue(app.buttons["passport-add-slot"].exists, "The partial last page offers add by hand")
    }

    func testRemoveAsksFirstAndUndoRestores() {
        let app = launch(["-uitest-seed", "few"])
        let stamp = app.buttons["passport-stamp-rome-colosseum"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 5))
        stamp.press(forDuration: 1.0)
        app.buttons["Remove from passport"].tap()
        XCTAssertTrue(app.buttons["Remove stamp"].waitForExistence(timeout: 5), "Removing asks first")
        app.buttons["Remove stamp"].tap()
        XCTAssertTrue(app.buttons["passport-undo"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["passport-subline"].label, "4 stamps from 4 countries")
        app.buttons["passport-undo"].tap()
        XCTAssertTrue(app.staticTexts["5 stamps from 5 countries"].waitForExistence(timeout: 5))
    }

    func testEmptyPassportShowsFirstStampCardAndAddByHand() {
        let app = launch()
        XCTAssertEqual(app.staticTexts["passport-subline"].label, "Nothing collected yet")
        XCTAssertFalse(app.buttons["passport-ticket-collected"].exists, "No 0 / 0 / 0 ticket")
        XCTAssertTrue(app.buttons["passport-first-explore"].exists)
        app.buttons["passport-add-by-hand"].tap()
        let row = app.buttons["passport-add-rome-colosseum"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["reveal"].waitForExistence(timeout: 10), "Add by hand saves through the normal collect flow")
        XCTAssertTrue(app.staticTexts["Added to your passport"].exists, "Never verified")
        XCTAssertFalse(app.staticTexts["Verified visit"].exists)
    }
}
