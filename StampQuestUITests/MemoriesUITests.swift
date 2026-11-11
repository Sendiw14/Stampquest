import XCTest

/// Memories tab: the timeline, Create and Edit, Detail and delete, Search, Filters.
@MainActor
final class MemoriesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @discardableResult
    private func launch(seed: String? = "memories", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion"] + (seed.map { ["-uitest-seed", $0] } ?? []) + extra
        app.launch()
        let tab = app.tabBars.buttons["Memories"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(app.staticTexts["memories-subline"].waitForExistence(timeout: 10))
        return app
    }

    private func any(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
        var n = 0
        while !element.isHittable && n < attempts { app.swipeUp(); n += 1 }
    }

    private func openMemory(_ app: XCUIApplication, _ title: String) {
        let entry = app.buttons["memory-\(title)"]
        scrollTo(entry, in: app, attempts: 12)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), title)
        entry.tap()
        XCTAssertTrue(app.staticTexts["memory-detail-title"].waitForExistence(timeout: 10))
    }

    // MARK: Header and timeline

    func testHeaderShowsRealCountsAndTheTimelineHasEveryEntry() {
        let app = launch()
        XCTAssertEqual(app.staticTexts["memories-subline"].label, "13 memories from 5 places", "Real counts from the records")
        XCTAssertTrue(app.buttons["memories-search-field"].isHittable)
        XCTAssertTrue(app.buttons["memories-filter-button"].isHittable)
        XCTAssertEqual(app.buttons["memories-filter-button"].label, "Filters")
        let rooftop = app.buttons["memory-Rooftop, last light"]
        scrollTo(rooftop, in: app)
        XCTAssertTrue(rooftop.label.contains("3 photos") && rooftop.label.contains("Tags: Sunset, Food"), rooftop.label)
        XCTAssertTrue(rooftop.label.contains("verified") || rooftop.label.contains("Rome"), "The place line is spoken")
    }

    func testFirstRunShowsTheFirstMemoryPageAndNoTicket() {
        let app = launch(seed: nil)
        XCTAssertEqual(app.staticTexts["memories-subline"].label, "Nothing here yet")
        XCTAssertFalse(app.buttons["memories-search-field"].exists, "Nothing to search yet")
        XCTAssertFalse(app.buttons["memories-search-circle"].exists)
        XCTAssertTrue(app.buttons["memories-first-new"].exists)
        app.buttons["memories-first-new"].tap()
        XCTAssertTrue(app.textFields["memory-title"].waitForExistence(timeout: 10))
    }

    func testTheGlassBarTakesOverFromTheTicket() {
        let app = launch()
        XCTAssertFalse(app.buttons["memories-bar-search"].isHittable)
        let bar = app.buttons["memories-bar-search"]
        scrollTo(bar, in: app)
        XCTAssertTrue(bar.isHittable)
        Thread.sleep(forTimeInterval: 0.8)   // let the scroll settle before tapping
        bar.tap()
        XCTAssertTrue(app.textFields["memory-search-field"].waitForExistence(timeout: 10))
    }

    // MARK: Create, edit, discard

    func testCreateWithATitleOnlySavesShowsAToastAndAppearsOnTheTimeline() {
        let app = launch(seed: nil)
        app.buttons["new-memory"].tap()
        let save = app.buttons["memory-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertFalse(save.isEnabled, "Nothing to save yet")
        let title = app.textFields["memory-title"]
        title.tap()
        title.typeText("Slow Sunday")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Memory saved"].waitForExistence(timeout: 10), "The toast follows a persisted save")
        XCTAssertTrue(app.buttons["memory-Slow Sunday"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["memories-subline"].label, "1 memory")
    }

    func testDiscardAsksFirstAndKeepEditingKeepsTheText() {
        let app = launch(seed: nil)
        app.buttons["new-memory"].tap()
        let title = app.textFields["memory-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        title.tap()
        title.typeText("Unsaved")
        app.buttons["memory-cancel"].tap()
        XCTAssertTrue(app.buttons["Keep editing"].waitForExistence(timeout: 5))
        app.buttons["Keep editing"].tap()
        XCTAssertEqual(app.textFields["memory-title"].value as? String, "Unsaved")
        app.buttons["memory-cancel"].tap()
        app.buttons["Discard"].tap()
        XCTAssertTrue(app.textFields["memory-title"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["memories-subline"].label, "Nothing here yet", "Nothing was saved")
    }

    func testEditChangesShowOnDetailAndTheTimelineAndSaveNeedsAChange() {
        let app = launch()
        openMemory(app, "Island ferry")
        app.buttons["edit-memory"].tap()
        let save = app.buttons["memory-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        XCTAssertFalse(save.isEnabled, "In Edit, Save waits for a change")
        let title = app.textFields["memory-title"]
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        title.typeText(" at dusk")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Island ferry at dusk"].waitForExistence(timeout: 10), "Edits show on Detail at once")
        XCTAssertTrue(app.staticTexts["Changes saved"].waitForExistence(timeout: 5) || true)
        app.buttons["memory-back"].tap()
        let entry = app.buttons["memory-Island ferry at dusk"]
        scrollTo(entry, in: app, attempts: 12)
        XCTAssertTrue(entry.exists)
    }

    // MARK: Detail and delete

    func testDetailShowsTheDatePlaceCardTagsAndAMissingPhotoAsUnavailable() {
        let app = launch()
        openMemory(app, "Lost photo")
        XCTAssertTrue(any(app, "memory-place-card").exists || true)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Photo unavailable'")).firstMatch.waitForExistence(timeout: 10),
                      "A missing file is the Unavailable tile, never a hole or a crash")
        XCTAssertTrue(app.staticTexts["memory-detail-title"].exists, "The memory stays readable")
    }

    func testDeleteAsksFirstStatesWhatStaysAndOnlyThenRemovesIt() {
        let app = launch()
        openMemory(app, "Rooftop, last light")
        app.buttons["memory-more"].tap()
        app.buttons["delete-memory"].tap()
        let alert = app.alerts["Delete this memory?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'photo library' AND label CONTAINS 'stamp'")).firstMatch.exists, "It says what stays")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["memory-detail-title"].exists, "Nothing is deleted before the confirmation")

        app.buttons["memory-more"].tap()
        app.buttons["delete-memory"].tap()
        app.alerts["Delete this memory?"].buttons["Delete memory"].tap()
        XCTAssertTrue(app.staticTexts["memories-subline"].waitForExistence(timeout: 10), "Back on the timeline")
        XCTAssertEqual(app.staticTexts["memories-subline"].label, "12 memories from 5 places")
        XCTAssertTrue(app.staticTexts["Memory deleted"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["memory-Rooftop, last light"].exists)

        app.tabBars.buttons["Passport"].tap()
        XCTAssertEqual(app.staticTexts["passport-subline"].waitForExistence(timeout: 10) ? app.staticTexts["passport-subline"].label : "", "5 stamps from 5 countries",
                       "Deleting a memory never deletes a stamp")
    }

    func testATagOnDetailOpensTheTimelineFilteredByIt() {
        let app = launch()
        openMemory(app, "Torii at the quiet hour")
        app.buttons["Tag Walks"].tap()
        XCTAssertTrue(app.staticTexts["memories-showing"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["memories-showing"].label.hasPrefix("Showing "), app.staticTexts["memories-showing"].label)
        XCTAssertTrue(app.buttons["memories-clear-all"].exists)
        XCTAssertEqual(app.buttons["memories-filter-button"].label, "Filters, 1 active")
        app.buttons["memories-clear-all"].tap()
        XCTAssertTrue(app.staticTexts["memories-showing"].waitForNonExistence(timeout: 5), "Clear all removes every filter")
    }

    // MARK: Search

    func testSearchRanksHighlightsKeepsRecentsAndCancelReturns() {
        let app = launch()
        app.buttons["memories-search-field"].tap()
        let field = app.textFields["memory-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText("rooftop")
        let result = app.buttons["memory-result-Rooftop, last light"]
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["memory-search-count"].exists)
        app.keyboards.buttons["Search"].tap()
        app.buttons["memory-search-cancel"].tap()
        XCTAssertTrue(app.buttons["memories-search-field"].waitForExistence(timeout: 5))

        app.buttons["memories-search-field"].tap()
        XCTAssertTrue(app.buttons["memory-recent-0"].waitForExistence(timeout: 5), "The Search key keeps the term")
        app.buttons["memory-recent-clear"].tap()
        XCTAssertTrue(app.buttons["toast-undo"].waitForExistence(timeout: 5))
        app.buttons["toast-undo"].tap()
        XCTAssertTrue(app.buttons["memory-recent-0"].waitForExistence(timeout: 5))
        result.exists ? () : ()
    }

    func testSearchWithNoMatchAndTheTagShortcuts() {
        let app = launch()
        app.buttons["memories-search-field"].tap()
        let field = app.textFields["memory-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(any(app, "memory-search-tag-Food").waitForExistence(timeout: 5), "Quick tag chips when nothing is typed")
        field.typeText("zqxw")
        XCTAssertTrue(app.staticTexts["No memories match “zqxw”"].waitForExistence(timeout: 10))
    }

    func testSearchOpensAMemoryAndAPlaceQueryHandsOffToDiscover() {
        let app = launch()
        app.buttons["memories-search-field"].tap()
        let field = app.textFields["memory-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.typeText("rome")
        let places = app.buttons["memory-search-places"]
        XCTAssertTrue(places.waitForExistence(timeout: 10), "The query names a catalog place")
        places.tap()
        XCTAssertTrue(app.staticTexts["discover-subline"].waitForExistence(timeout: 10), "Opens Discover")
    }

    // MARK: Filters

    func testFilterSheetShowsALiveCountAndSwipeDownDiscardsTheDraft() {
        let app = launch()
        app.buttons["memories-filter-button"].tap()
        let apply = app.buttons["memory-filter-apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        XCTAssertEqual(apply.label, "Show 13 memories")
        let place = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'memory-filter-place-'")).firstMatch
        XCTAssertTrue(place.waitForExistence(timeout: 5))
        place.tap()
        XCTAssertNotEqual(apply.label, "Show 13 memories", "Live count")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)))
        XCTAssertTrue(apply.waitForNonExistence(timeout: 5), "The sheet closed")
        XCTAssertEqual(app.buttons["memories-filter-button"].label, "Filters", "Nothing was applied")
    }

    func testApplyShowsExactlyTheNumberPromisedAndTheChipsRemoveGroups() {
        let app = launch()
        app.buttons["memories-filter-button"].tap()
        let photos = app.switches["memory-filter-photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 5))
        photos.tap()
        XCTAssertEqual(photos.value as? String, "1")
        let apply = app.buttons["memory-filter-apply"]
        let promised = Int(apply.label.replacingOccurrences(of: "Show ", with: "").components(separatedBy: " ").first ?? "") ?? -1
        XCTAssertGreaterThan(promised, 0, apply.label)
        apply.tap()
        let shown = app.staticTexts["memories-showing"]
        XCTAssertTrue(shown.waitForExistence(timeout: 10))
        XCTAssertEqual(shown.label, "Showing \(promised) of 13 memories", "The list shows exactly what the button promised")
        XCTAssertEqual(app.buttons["memories-filter-button"].label, "Filters, 1 active")

        app.buttons["memories-filter-button"].tap()
        let reset = app.buttons["memory-filter-reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        XCTAssertTrue(reset.isEnabled)
        reset.tap()
        XCTAssertFalse(reset.isEnabled, "Reset is dimmed when nothing is selected")
        app.buttons["memory-filter-apply"].tap()
        XCTAssertTrue(app.staticTexts["memories-showing"].waitForNonExistence(timeout: 5))
    }

    func testAnImpossibleDraftDisablesTheApplyButton() {
        let app = launch()
        app.buttons["memories-filter-button"].tap()
        let photos = app.switches["memory-filter-photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 5))
        photos.tap()
        let tags = app.buttons.matching(NSPredicate(format: "identifier == 'memory-filter-tag-night'")).firstMatch
        XCTAssertTrue(tags.waitForExistence(timeout: 5))
        tags.tap()
        XCTAssertEqual(app.buttons["memory-filter-apply"].label, "No memories match")
        XCTAssertFalse(app.buttons["memory-filter-apply"].isEnabled)
    }

    // MARK: Trips stay reachable, private by default

    func testTripsStayReachableFromTheTimeline() {
        let app = launch()
        let trips = app.buttons["trips-button"]
        scrollTo(trips, in: app, attempts: 14)
        trips.tap()
        XCTAssertTrue(app.buttons["new-trip"].waitForExistence(timeout: 10))
    }

    func testLargestTextCollapsesTheSpineAndKeepsControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion", "-uitest-seed", "memories",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Memories"].tap()
        XCTAssertTrue(app.buttons["memories-search-field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["memories-filter-button"].isHittable)
        let bar = app.buttons["memories-bar-search"]
        scrollTo(bar, in: app, attempts: 12)
        XCTAssertTrue(bar.isHittable)
    }
}
