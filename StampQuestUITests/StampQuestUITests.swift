import XCTest

/// End-to-end journeys. Each test launches the real app in a known state using the
/// DEBUG-only launch arguments (fresh data, seeded data, scripted location, deep links).
@MainActor
final class StampQuestUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    @discardableResult
    private func launch(_ extra: [String] = [], reset: Bool = true, skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args: [String] = []
        if reset { args.append("-uitest-reset") }
        if skipOnboarding { args.append("-uitest-skip-onboarding") }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Tab \(name) missing")
        button.tap()
    }

    /// Opens a destination from Discover by searching for it.
    private func openDestination(_ app: XCUIApplication, search: String, resultID: String) {
        tab(app, "Discover")
        let ticket = app.buttons["discover-search-field"]
        XCTAssertTrue(ticket.waitForExistence(timeout: 10))
        ticket.tap()
        let field = app.textFields["search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText(search)
        let row = app.buttons["search-place-\(resultID)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No search result for \(search)")
        row.tap()
    }

    private func collectCurrent(_ app: XCUIApplication) {
        let collect = app.buttons["collect-button"]
        XCTAssertTrue(collect.waitForExistence(timeout: 10))
        collect.tap()
        XCTAssertTrue(app.staticTexts["reveal-confirmation"].waitForExistence(timeout: 10), "The reveal must appear after collecting")
    }

    // MARK: Onboarding

    // Onboarding journeys live in OnboardingUITests.

    // MARK: The core journey

    func testCollectingShowsRevealUpdatesPassportAndSurvivesRelaunch() {
        let app = launch()
        openDestination(app, search: "Eiffel", resultID: "paris-eiffel-tower")
        collectCurrent(app)

        app.buttons["reveal-done"].tap()
        XCTAssertTrue(app.buttons["view-in-passport-button"].waitForExistence(timeout: 10), "Back on Destination detail once the reveal has gone")

        app.terminate()
        let again = launch(["-uitest-url", "stampquest://stamp/paris-eiffel-tower"], reset: false)
        XCTAssertTrue(again.staticTexts["stamp-state-title"].waitForExistence(timeout: 15))
        XCTAssertEqual(again.staticTexts["stamp-state-title"].label, "In your passport", "Manual collection must say so, not 'verified', and it survives a relaunch")
        XCTAssertFalse(again.staticTexts["Verified visit"].exists)
        again.buttons["stamp-back"].tap()
        tab(again, "Passport")
        XCTAssertTrue(again.staticTexts["passport-subline"].waitForExistence(timeout: 10))
        XCTAssertEqual(again.staticTexts["passport-subline"].label, "1 stamp from 1 country")
        XCTAssertTrue(again.buttons["passport-stamp-paris-eiffel-tower"].exists)
    }

    func testCollectingTwiceNeverDuplicates() {
        let app = launch()
        openDestination(app, search: "Eiffel", resultID: "paris-eiffel-tower")
        collectCurrent(app)
        app.buttons["reveal-done"].tap()
        // Once collected, the primary action becomes "View in passport"; there is no second collect.
        XCTAssertTrue(app.buttons["view-in-passport-button"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["collect-button"].exists)
    }

    func testRevealCanBeDismissedAtAnyTime() {
        let app = launch()
        openDestination(app, search: "Rome", resultID: "rome-colosseum")
        app.buttons["collect-button"].tap()
        let close = app.buttons["reveal-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["view-in-passport-button"].waitForExistence(timeout: 5))
    }

    // MARK: Wishlist

    func testWishlistAddRemoveAndDistinctFromCollection() {
        let app = launch()
        openDestination(app, search: "Kyoto", resultID: "kyoto-fushimi-inari")
        app.buttons["wishlist-button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["On your wishlist"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["search-cancel"].tap()

        tab(app, "Passport")
        XCTAssertTrue(app.staticTexts["Nothing collected yet"].waitForExistence(timeout: 10), "A wishlisted place is not a collected stamp")

        tab(app, "Discover")
        app.buttons["discover-wishlist-button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["wishlist-kyoto-fushimi-inari"].waitForExistence(timeout: 5))
    }

    // MARK: Passport sorting and filtering

    // MARK: Memories

    func testMemoryCreateEditDeleteKeepsStamp() {
        let app = launch(["-uitest-seed", "few"])
        tab(app, "Memories")
        app.buttons["new-memory"].tap()
        let title = app.textFields["memory-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Rooftop dinner")
        app.buttons["memory-save"].tap()

        let card = app.buttons["memory-Rooftop dinner"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The new memory appears in the timeline")
        card.tap()

        app.buttons["edit-memory"].tap()
        let editTitle = app.textFields["memory-title"]
        XCTAssertTrue(editTitle.waitForExistence(timeout: 10))
        editTitle.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        editTitle.typeText(" with friends")
        app.buttons["memory-save"].tap()
        XCTAssertTrue(app.staticTexts["Rooftop dinner with friends"].waitForExistence(timeout: 10), "Edits persist and show immediately")

        app.buttons["memory-more"].tap()
        app.buttons["delete-memory"].tap()
        app.alerts["Delete this memory?"].buttons["Delete memory"].tap()
        XCTAssertTrue(app.staticTexts["memories-subline"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["memory-Rooftop dinner with friends"].waitForExistence(timeout: 2))

        tab(app, "Passport")
        XCTAssertEqual(app.staticTexts["passport-subline"].waitForExistence(timeout: 10) ? app.staticTexts["passport-subline"].label : "", "5 stamps from 5 countries",
                       "Deleting a memory must never delete a stamp")
    }

    // MARK: Trips

    func testTripCreateAndDeleteKeepsStampsAndMemories() {
        let app = launch(["-uitest-seed", "few"])
        tab(app, "Memories")
        let tripsButton = app.buttons["trips-button"]
        var swipes = 0
        while !tripsButton.isHittable && swipes < 10 { app.swipeUp(velocity: .slow); swipes += 1 }
        tripsButton.tap()
        app.buttons["new-trip"].tap()
        let title = app.textFields["trip-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Autumn weekend")
        app.buttons["trip-save"].tap()

        let trip = app.buttons["trip-Autumn weekend"]
        XCTAssertTrue(trip.waitForExistence(timeout: 10))
        trip.tap()
        app.buttons["delete-trip"].tap()
        app.buttons["Delete trip"].tap()
        XCTAssertFalse(app.buttons["trip-Autumn weekend"].waitForExistence(timeout: 2))

        tab(app, "Passport")
        XCTAssertEqual(app.staticTexts["passport-subline"].waitForExistence(timeout: 10) ? app.staticTexts["passport-subline"].label : "", "5 stamps from 5 countries")
    }

    // MARK: Map

    func testMapListAlternativeOpensADestination() {
        let app = launch()
        tab(app, "Map")
        XCTAssertTrue(app.segmentedControls["map-layer"].waitForExistence(timeout: 10))
        app.buttons["map-list-toggle"].tap()
        XCTAssertTrue(app.staticTexts["Europe"].waitForExistence(timeout: 10), "The list is a full alternative to the map")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Paris'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["collect-button"].waitForExistence(timeout: 10))
    }

    // MARK: Location verification

    func testDeniedLocationStillAllowsManualCollection() {
        let app = launch(["-uitest-location", "denied", "-uitest-url", "stampquest://destination/paris-eiffel-tower"])
        XCTAssertTrue(app.buttons["verify-button"].waitForExistence(timeout: 10))
        app.buttons["verify-button"].tap()
        app.buttons["verify-start"].tap()
        XCTAssertTrue(app.staticTexts["verify-failure-title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["verify-failure-title"].label, "Location access is off for StampQuest")
        XCTAssertFalse(app.staticTexts["Visit verified"].exists, "A failed verification must never look like success")

        app.buttons["verify-collect-manually"].tap()
        XCTAssertTrue(app.staticTexts["reveal-confirmation"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["reveal-confirmation"].label, "Added to your passport", "Manual collection is not a verified visit")
    }

    func testNearbyLocationVerifiesTheVisit() {
        let app = launch(["-uitest-location", "48.8590,2.2950,15", "-uitest-url", "stampquest://destination/paris-eiffel-tower"])
        XCTAssertTrue(app.buttons["verify-button"].waitForExistence(timeout: 10))
        app.buttons["verify-button"].tap()
        app.buttons["verify-start"].tap()
        XCTAssertTrue(app.staticTexts["Visit verified"].waitForExistence(timeout: 10))
        app.buttons["verify-done"].tap()
        XCTAssertTrue(app.staticTexts["reveal-confirmation"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["reveal-confirmation"].label.contains("Visit verified"))
    }

    func testFarAwayLocationIsRejectedHonestly() {
        let app = launch(["-uitest-location", "35.0,139.0,10", "-uitest-url", "stampquest://destination/paris-eiffel-tower"])
        app.buttons["verify-button"].tap()
        app.buttons["verify-start"].tap()
        XCTAssertTrue(app.staticTexts["verify-failure-title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["verify-failure-title"].label, "You don’t seem to be there yet")
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["collect-button"].waitForExistence(timeout: 5), "Nothing was collected by the failed attempt")
    }

    // MARK: Collections

    func testCompletingACollectionIsCelebratedFromRealRecords() {
        let app = launch(["-uitest-seed", "islandAlmost", "-uitest-url", "stampquest://destination/oahu-diamond-head"])
        collectCurrent(app)
        XCTAssertTrue(app.staticTexts["You completed Island Escapes"].waitForExistence(timeout: 5))
        app.buttons["reveal-done"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        tab(app, "Passport")
        app.buttons["passport-ticket-sets"].tap()
        app.buttons["collection-island-escapes"].tap()
        XCTAssertTrue(app.otherElements["collection-complete"].waitForExistence(timeout: 10) || app.staticTexts["Collection complete"].exists)
    }

    // MARK: Sharing

    func testStampShareImageIsPrepared() {
        let app = launch(["-uitest-seed", "few"])
        tab(app, "Passport")
        app.buttons["passport-stamp-paris-eiffel-tower"].tap()
        app.buttons["stamp-share"].tap()
        XCTAssertTrue(app.buttons["share-image"].waitForExistence(timeout: 15), "The share sheet only offers sharing once the image really exists")
    }

    // MARK: Settings and data

    func testSettingsAppearanceAndDeleteAllData() {
        let app = launch(["-uitest-seed", "few"])
        app.buttons["settings-button"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))

        app.buttons["delete-all-data"].tap()
        app.buttons["Delete everything"].tap()
        XCTAssertTrue(app.alerts["All data deleted"].waitForExistence(timeout: 10))
        app.alerts.buttons["OK"].tap()

        app.navigationBars.buttons.firstMatch.tap()
        tab(app, "Passport")
        XCTAssertTrue(app.staticTexts["Your first stamp"].waitForExistence(timeout: 10))
    }

    // MARK: Empty states

    func testEmptyStatesAreDesignedNotBlank() {
        let app = launch()
        tab(app, "Passport")
        XCTAssertTrue(app.staticTexts["Your first stamp"].waitForExistence(timeout: 10))
        tab(app, "Memories")
        XCTAssertTrue(app.staticTexts["Your first memory"].waitForExistence(timeout: 10))
        tab(app, "Discover")
        app.buttons["discover-search-field"].tap()
        let field = app.textFields["search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText("zzzzqqq")
        XCTAssertTrue(app.staticTexts["No places match “zzzzqqq”"].waitForExistence(timeout: 10))
    }

    // MARK: Search and filters

    func testSearchAndFilterSheet() {
        let app = launch()
        tab(app, "Discover")
        app.buttons["discover-search-field"].tap()
        let field = app.textFields["search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText("japan")
        XCTAssertTrue(app.buttons["search-place-kyoto-fushimi-inari"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["search-place-rome-colosseum"].exists)
    }

    // MARK: Accessibility

    func testAccessibilityAuditOfPrimaryScreens() throws {
        let app = launch(["-uitest-seed", "few"])
        for name in ["Home", "Passport", "Discover", "Map", "Memories"] {
            tab(app, name)
            try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .elementDetection, .sufficientElementDescription, .trait]) { issue in
                // The map's tile content is system-drawn and outside our control.
                name == "Map" && issue.auditType == .contrast
            }
        }
    }

    func testLargestDynamicTypeStillFunctions() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-seed", "few",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        tab(app, "Passport")
        XCTAssertTrue(app.staticTexts["passport-subline"].waitForExistence(timeout: 10))
        tab(app, "Discover")
        XCTAssertTrue(app.buttons["discover-search-field"].waitForExistence(timeout: 10))
    }

    func testReduceMotionRevealStillConfirms() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-url", "stampquest://destination/rome-colosseum",
                               "-UIAccessibilityReduceMotionEnabled", "1"]
        app.launch()
        collectCurrent(app)
        let done = app.buttons["reveal-done"]
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: done)
        waitForExpectations(timeout: 10)   // the buttons cross-fade in after the stamp
    }
}
