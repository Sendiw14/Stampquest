import XCTest

/// Map tab: the counts, the layer chips, the preview card in each state, Search, Locate, the List, the Marker guide, and every
/// tappable thing. Leaf controls carry the identifiers; a container id would shadow them.
@MainActor
final class MapUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @discardableResult
    private func launch(_ extra: [String] = [], seed: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion"] + (seed.map { ["-uitest-seed", $0] } ?? []) + extra
        app.launch()
        let tab = app.tabBars.buttons["Map"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(any(app, "map-title").waitForExistence(timeout: 10))
        return app
    }

    private func any(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    /// Shows a place on the map through Search, the way a person who cannot find the marker would.
    private func showPlace(_ app: XCUIApplication, query: String, id: String) {
        app.buttons["map-search"].tap()
        let field = app.textFields["search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText(query)
        let row = app.buttons["search-place-\(id)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["map-card-open"].waitForExistence(timeout: 10))
    }

    // MARK: Counts and chips

    func testFirstRunSaysNothingCollectedAndEverythingStillWorks() {
        let app = launch()
        XCTAssertEqual(any(app, "map-counts").label, "Nothing collected yet")
        XCTAssertEqual(app.buttons["map-chip-collected"].label, "Collected, 0 places")
        XCTAssertEqual(app.buttons["map-chip-verified"].label, "Verified, 0 places")
        XCTAssertEqual(app.buttons["map-chip-saved"].label, "Saved, 0 places")
        XCTAssertTrue(app.buttons["map-list-button"].isHittable && app.buttons["map-search"].isHittable)
        XCTAssertFalse(app.buttons["map-card-open"].exists)
    }

    func testCountsAndChipsMatchTheRecordsAndEmptyLayersOfferAllPlaces() {
        let app = launch(seed: "few")
        XCTAssertEqual(any(app, "map-counts").label, "5 collected · 2 verified · 0 saved")
        XCTAssertEqual(app.buttons["map-chip-collected"].label, "Collected, 5 places")
        XCTAssertEqual(app.buttons["map-chip-verified"].label, "Verified, 2 places")
        XCTAssertTrue(app.buttons["map-chip-all"].isSelected)

        app.buttons["map-chip-verified"].tap()
        XCTAssertTrue(app.buttons["map-chip-verified"].isSelected && !app.buttons["map-chip-all"].isSelected)

        app.buttons["map-chip-saved"].tap()
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 5))
        any(app, "map-empty-show-all").tap()
        XCTAssertTrue(app.buttons["map-chip-all"].isSelected)
        XCTAssertFalse(app.staticTexts["Nothing saved yet"].exists)
    }

    // MARK: Card

    func testSelectingACollectedPlaceShowsViewStampAndNoBookmark() {
        let app = launch(seed: "few")
        showPlace(app, query: "Rome", id: "rome-colosseum")
        XCTAssertTrue(app.buttons["map-card-view-stamp"].exists)
        XCTAssertFalse(app.buttons["map-card-save"].exists && app.buttons["map-card-collect"].exists)
        XCTAssertTrue(app.staticTexts["In your passport"].exists)
    }

    func testSelectingAnAvailablePlaceShowsCollectAndBookmarkAndOpensDetails() {
        let app = launch(seed: "few")
        showPlace(app, query: "Lisbon", id: "lisbon-belem-tower")
        XCTAssertTrue(app.buttons["map-card-collect"].exists && app.buttons["map-card-save"].exists)
        XCTAssertTrue(app.staticTexts["Not in your passport yet"].exists)
        app.buttons["map-card-open"].tap()
        XCTAssertTrue(app.navigationBars["Lisbon"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(any(app, "map-title").waitForExistence(timeout: 5))
    }

    func testSavingShowsAToastAndUndoPutsTheCountsBack() {
        let app = launch(seed: "few")
        showPlace(app, query: "Lisbon", id: "lisbon-belem-tower")
        app.buttons["map-card-save"].tap()
        XCTAssertTrue(app.staticTexts["Saved to wishlist"].waitForExistence(timeout: 5))
        XCTAssertEqual(any(app, "map-counts").label, "5 collected · 2 verified · 1 saved")
        XCTAssertEqual(app.buttons["map-chip-saved"].label, "Saved, 1 place")
        XCTAssertTrue(app.staticTexts["On your wishlist"].exists)
        app.buttons["toast-undo"].tap()
        XCTAssertEqual(any(app, "map-counts").label, "5 collected · 2 verified · 0 saved")
    }

    func testCollectFromTheCardHandsOffToTheRevealAndUpdatesTheCounts() {
        let app = launch(seed: "few")
        showPlace(app, query: "Lisbon", id: "lisbon-belem-tower")
        app.buttons["map-card-collect"].tap()
        let done = app.buttons["Keep exploring"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        XCTAssertTrue(any(app, "map-counts").waitForExistence(timeout: 10))
        XCTAssertEqual(any(app, "map-counts").label, "6 collected · 2 verified · 0 saved")
        XCTAssertTrue(app.buttons["map-card-view-stamp"].waitForExistence(timeout: 5), "The open card follows the new state")
    }

    func testViewStampOpensTheStampInPassport() {
        let app = launch(seed: "few")
        showPlace(app, query: "Rome", id: "rome-colosseum")
        app.buttons["map-card-view-stamp"].tap()
        XCTAssertTrue(app.navigationBars["Rome"].waitForExistence(timeout: 10))
    }

    // MARK: Locate

    func testLocateWithPermissionNeverAskedShowsTheExplainerAndNotNowAsksNothing() {
        let app = launch(["-uitest-location", "undetermined-then-allow"])
        app.buttons["map-locate"].tap()
        XCTAssertTrue(app.staticTexts["Use your location?"].waitForExistence(timeout: 5))
        any(app, "map-location-not-now").tap()
        XCTAssertFalse(app.staticTexts["Use your location?"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Location is off"].exists)
        XCTAssertEqual(app.buttons["map-locate"].value as? String ?? "", "")
    }

    func testLocateWhenPermissionIsDeniedShowsTheBannerAndTheMapStaysUsable() {
        let app = launch(["-uitest-location", "denied"])
        app.buttons["map-locate"].tap()
        XCTAssertTrue(app.staticTexts["Location is off"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["map-banner-settings"].exists)
        app.buttons["map-chip-collected"].tap()
        XCTAssertTrue(app.buttons["map-chip-collected"].isSelected)
        app.buttons["map-list-button"].tap()
        XCTAssertTrue(any(app, "map-list-title").waitForExistence(timeout: 5))
    }

    func testLocateWithPermissionTurnsOnAndOffAgain() {
        let app = launch(["-uitest-location", "41.9,12.5"])
        app.buttons["map-locate"].tap()
        let on = NSPredicate(format: "value == 'On'")
        expectation(for: on, evaluatedWith: app.buttons["map-locate"])
        waitForExpectations(timeout: 10)
        app.buttons["map-locate"].tap()
        expectation(for: NSPredicate(format: "value != 'On'"), evaluatedWith: app.buttons["map-locate"])
        waitForExpectations(timeout: 10)
    }

    // MARK: Guide, Search, List

    func testMarkerGuideListsFiveMarkersAndDoneCloses() {
        let app = launch()
        app.buttons["map-guide-button"].tap()
        XCTAssertTrue(app.staticTexts["Map markers"].waitForExistence(timeout: 5))
        for title in ["Place to collect", "On your wishlist", "In your passport", "Verified visit", "Several places"] {
            XCTAssertTrue(app.staticTexts[title].exists, title)
        }
        app.buttons["map-guide-done"].tap()
        XCTAssertFalse(app.staticTexts["Map markers"].waitForExistence(timeout: 2))
    }

    func testSearchCancelReturnsToTheMapAsItWas() {
        let app = launch(seed: "few")
        app.buttons["map-chip-collected"].tap()
        app.buttons["map-search"].tap()
        XCTAssertTrue(app.textFields["search-field"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Map"].isHittable, "The tab bar is hidden while Search is open")
        app.buttons["search-cancel"].tap()
        XCTAssertTrue(app.buttons["map-chip-collected"].waitForExistence(timeout: 5) && app.buttons["map-chip-collected"].isSelected)
    }

    func testASearchResultThatTheLayerHidesSwitchesToAll() {
        let app = launch(seed: "few")
        app.buttons["map-chip-collected"].tap()
        showPlace(app, query: "Lisbon", id: "lisbon-belem-tower")
        XCTAssertTrue(app.buttons["map-chip-all"].isSelected)
    }

    func testListSharesTheLayerOpensDetailsAndGoesBack() {
        let app = launch(seed: "few")
        app.buttons["map-chip-verified"].tap()
        app.buttons["map-list-button"].tap()
        XCTAssertTrue(any(app, "map-list-title").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["map-chip-verified"].isSelected, "The list opens on the map's layer")
        XCTAssertTrue(app.tabBars.buttons["Map"].isSelected)
        XCTAssertTrue(app.buttons["map-row-paris-eiffel-tower"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["map-row-rome-colosseum"].exists, "Rome is collected by hand, not verified")

        app.buttons["map-chip-all"].tap()
        // Amsterdam heads the Europe section, which the Verified layer left out of the list.
        let amsterdam = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Amsterdam'")).firstMatch
        XCTAssertTrue(amsterdam.waitForExistence(timeout: 5))
        app.buttons["map-row-paris-eiffel-tower"].tap()
        XCTAssertTrue(app.navigationBars["Paris"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["map-list-back"].tap()
        XCTAssertTrue(app.buttons["map-chip-all"].waitForExistence(timeout: 5) && app.buttons["map-chip-all"].isSelected, "The layer is shared both ways")
    }

    func testListSearchFiltersOfflineAndShowsAnEmptyResult() {
        let app = launch()
        app.buttons["map-list-button"].tap()
        let field = app.textFields["map-list-search"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Lisbon")
        XCTAssertTrue(app.buttons["map-row-lisbon-belem-tower"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["map-row-paris-eiffel-tower"].exists)
        field.clearAndType("zzzzqq")
        XCTAssertTrue(app.staticTexts["No places match"].waitForExistence(timeout: 5))
    }

    func testMapUnavailableStillOffersTheListAndTryAgain() {
        let app = launch(["-uitest-map-unavailable"])
        XCTAssertTrue(app.staticTexts["The map can’t load right now"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["map-chip-all"].exists, "Chips and the side stack are hidden")
        XCTAssertTrue(app.buttons["map-row-lisbon-belem-tower"].waitForExistence(timeout: 5) || app.staticTexts["Lisbon"].exists)
        app.buttons["map-unavailable-open-list"].tap()
        XCTAssertTrue(any(app, "map-list-title").waitForExistence(timeout: 5))
        app.buttons["map-list-back"].tap()
        app.buttons["map-retry"].tap()
        // Try again starts the map over. If tiles still cannot load, the same card comes back: never a dead end.
        let chip = app.buttons["map-chip-all"]
        let card = app.staticTexts["The map can’t load right now"]
        XCTAssertTrue(chip.waitForExistence(timeout: 8) || card.waitForExistence(timeout: 2))
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        guard let current = value as? String, !current.isEmpty else { typeText(text); return }
        tap()
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        typeText(text)
    }
}
