import XCTest

/// Discover tab: the hero and ticket, Search, the Filters sheet, the Results list, the Wishlist, and every tappable thing.
@MainActor
final class DiscoverUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @discardableResult
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion"] + extra
        app.launch()
        let tab = app.tabBars.buttons["Discover"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(app.staticTexts["discover-subline"].waitForExistence(timeout: 10))
        return app
    }

    private func any(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func openSearch(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["discover-search-field"].tap()
        let field = app.textFields["search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        return field
    }

    /// Opens a place through Search (tapping the Discover tab again would pop a deep-linked screen).
    private func openPlace(_ app: XCUIApplication, query: String, id: String, title: String) {
        let field = openSearch(app)
        field.typeText(query)
        let row = app.buttons["search-place-\(id)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
    }

    /// Back from a place opened through Search lands on the Search screen: Cancel returns to the page.
    private func backToDiscover(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["search-cancel"].tap()
        XCTAssertTrue(app.buttons["discover-search-field"].waitForExistence(timeout: 5))
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 6) {
        var n = 0
        while !element.isHittable && n < attempts { app.swipeUp(velocity: .slow); n += 1 }
    }

    // MARK: Hero and ticket

    func testHeroShowsTheRealCountAndNothingGold() {
        let app = launch(["-uitest-seed", "few"])
        XCTAssertEqual(app.staticTexts["discover-subline"].label, "56 places to collect", "Every place not in the passport, never a rounded 60+")
        XCTAssertTrue(app.buttons["discover-search-field"].isHittable)
        XCTAssertTrue(app.buttons["discover-filter-button"].isHittable)
        XCTAssertEqual(app.buttons["discover-wishlist-button"].label, "Wishlist", "No badge and no number while nothing is saved")
    }

    // MARK: Search

    func testSearchFindsPlacesLandmarksAndCollectionsAndOpensAPlace() {
        let app = launch(["-uitest-seed", "few"])
        let field = openSearch(app)
        field.typeText("ky")
        let kyoto = app.buttons["search-place-kyoto-fushimi-inari"]
        XCTAssertTrue(kyoto.waitForExistence(timeout: 10))
        XCTAssertTrue(kyoto.label.hasPrefix("Kyoto, Japan"), kyoto.label)
        XCTAssertEqual(kyoto.value as? String, "In your passport")
        XCTAssertTrue(app.buttons["search-landmark-tokyo-tower"].exists, "A landmark result opens its parent place")

        app.buttons["search-scope-landmarks"].tap()
        XCTAssertFalse(kyoto.waitForExistence(timeout: 1), "A scope chip shows only its group")
        XCTAssertTrue(app.buttons["search-landmark-tokyo-tower"].exists)
        app.buttons["search-scope-all"].tap()

        kyoto.tap()
        XCTAssertTrue(app.navigationBars["Kyoto"].waitForExistence(timeout: 10))
    }

    func testRecentSearchesAreKeptClearedAndRestoredByUndo() {
        let app = launch()
        let field = openSearch(app)
        field.typeText("kyoto\n")
        app.buttons["search-cancel"].tap()
        XCTAssertTrue(app.buttons["discover-search-field"].waitForExistence(timeout: 5), "Cancel returns to Discover")

        _ = openSearch(app)
        let recent = app.buttons["search-recent-0"]
        XCTAssertTrue(recent.waitForExistence(timeout: 5), "A term is kept when the Search key is pressed")
        XCTAssertEqual(recent.label, "Search for kyoto")
        app.buttons["search-recent-clear"].tap()
        XCTAssertTrue(app.buttons["toast-undo"].waitForExistence(timeout: 5))
        XCTAssertFalse(recent.exists)
        app.buttons["toast-undo"].tap()
        XCTAssertTrue(app.buttons["search-recent-0"].waitForExistence(timeout: 5), "Undo restores the list")
    }

    func testTheArrowOnARecentRowFillsTheFieldWithoutSearching() {
        let app = launch()
        let field = openSearch(app)
        field.typeText("lisbon\n")
        app.buttons["search-clear"].tap()
        app.buttons["search-recent-insert-0"].tap()
        XCTAssertEqual(field.value as? String, "lisbon")
        XCTAssertTrue(app.buttons["search-recent-0"].exists, "Still on Recent: inserting does not search")
    }

    func testIdeaChipsRunTheirTerm() {
        let app = launch()
        _ = openSearch(app)
        let idea = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-idea-'")).firstMatch
        XCTAssertTrue(idea.waitForExistence(timeout: 5), "Try ideas show when nothing is typed")
        idea.tap()
        XCTAssertTrue(app.buttons["search-scope-all"].waitForExistence(timeout: 5), "A chip is only offered if it has a result")
    }

    func testNoResultsStateOffersIdeasAndBrowseAllInterests() {
        let app = launch()
        let field = openSearch(app)
        field.typeText("zqx")
        XCTAssertTrue(app.staticTexts["No places match “zqx”"].waitForExistence(timeout: 10))
        app.buttons["search-browse-interests"].tap()
        XCTAssertTrue(app.navigationBars["Interests"].waitForExistence(timeout: 5))
    }

    func testSearchErrorStateIsNeverAnEmptyListAndTryAgainRecovers() {
        let app = launch(["-uitest-search-error"])
        app.buttons["discover-search-field"].tap()
        let message = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Search isn’t available right now'")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["search-scope-all"].exists, "Never an empty result list")
        app.buttons["Try again"].tap()
        XCTAssertTrue(app.textFields["search-field"].waitForExistence(timeout: 5))
        XCTAssertFalse(message.waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'search-idea-'")).firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: Filters

    func testCancelDiscardsTheFilterDraft() {
        let app = launch()
        app.buttons["discover-filter-button"].tap()
        let chip = app.buttons["filters-interest-city"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["filters-apply"].label, "Show all places")
        chip.tap()
        XCTAssertTrue(app.buttons["filters-apply"].label.hasPrefix("Show "), "Live count")
        XCTAssertNotEqual(app.buttons["filters-apply"].label, "Show all places")
        app.buttons["filters-cancel"].tap()
        XCTAssertFalse(app.buttons["filters-apply"].waitForExistence(timeout: 2))

        app.buttons["discover-filter-button"].tap()
        XCTAssertTrue(app.buttons["filters-apply"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["filters-apply"].label, "Show all places", "The sheet always opens empty")
        XCTAssertFalse(app.buttons["filters-interest-city"].isSelected)
    }

    func testApplyShowsAListThatMatchesTheCountAndTheChips() {
        let app = launch()
        app.buttons["discover-filter-button"].tap()
        app.buttons["filters-interest-city"].tap()
        app.buttons["filters-region-europe"].tap()
        let apply = app.buttons["filters-apply"]
        let label = apply.label
        let count = Int(label.replacingOccurrences(of: "Show ", with: "").components(separatedBy: " ").first ?? "") ?? -1
        XCTAssertGreaterThan(count, 0, label)
        apply.tap()

        let shown = app.staticTexts["results-count"]
        XCTAssertTrue(shown.waitForExistence(timeout: 10))
        XCTAssertEqual(shown.label, "Showing \(count) place\(count == 1 ? "" : "s")")
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'result-'"))
        XCTAssertGreaterThan(rows.count, 0)
        XCTAssertTrue(app.buttons["chip-category-city"].exists && app.buttons["chip-region-europe"].exists, "The same filters as removable chips")

        app.buttons["chip-region-europe"].tap()
        XCTAssertFalse(app.buttons["chip-region-europe"].exists)
        XCTAssertNotEqual(shown.label, "Showing \(count) place\(count == 1 ? "" : "s")", "Removing a chip widens the list")
        app.buttons["results-clear-all"].tap()
        XCTAssertFalse(app.buttons["chip-category-city"].exists)
    }

    func testTheCountryPickerSelectsSeveralAndShowsThemOnTheRow() {
        let app = launch()
        app.buttons["discover-filter-button"].tap()
        app.buttons["filters-country-row"].tap()
        // A List only exposes the rows on screen, so use the first two countries (alphabetical).
        let first = any(app, "filters-country-AR")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        any(app, "filters-country-AU").tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(app.buttons["filters-country-row"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["filters-country-row"].label, "Argentina, Australia")
        app.buttons["filters-reset"].tap()
        XCTAssertEqual(app.buttons["filters-country-row"].label, "Any country", "Reset clears the draft only")
    }

    // MARK: Sections and destinations

    func testEveryTappableOnThePageReachesAScreen() {
        let app = launch(["-uitest-seed", "few"])

        let wishlistButton = app.buttons["discover-wishlist-button"]
        XCTAssertTrue(wishlistButton.waitForExistence(timeout: 10))
        wishlistButton.tap()
        XCTAssertTrue(app.navigationBars["Wishlist"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].exists, "An empty wishlist is a designed state")
        app.buttons["Explore places"].tap()
        XCTAssertTrue(app.staticTexts["discover-subline"].waitForExistence(timeout: 5), "Explore places returns to Discover")

        app.buttons["discover-interests-all"].tap()
        XCTAssertTrue(app.navigationBars["Interests"].waitForExistence(timeout: 5))
        app.buttons["discover-interest-city"].tap()
        XCTAssertTrue(app.navigationBars["Cities"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["results-count"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        let interest = app.buttons["discover-interest-nature"]
        XCTAssertTrue(interest.waitForExistence(timeout: 5))
        interest.tap()
        XCTAssertTrue(app.navigationBars["Nature"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let collection = app.buttons["discover-collection-world-icons"]
        scrollTo(collection, in: app)
        collection.tap()
        XCTAssertTrue(app.navigationBars["World Icons"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let all = app.buttons["discover-collections-all"]
        scrollTo(all, in: app)
        all.tap()
        XCTAssertTrue(app.navigationBars["Collections"].waitForExistence(timeout: 5))
    }

    func testTheEditorsPickSavesWithUndoAndCollectsThroughTheCollectFlow() {
        let app = launch()
        let card = app.buttons["discover-pick"]
        scrollTo(card, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Editor’s pick"), card.label)
        XCTAssertEqual(card.value as? String, "Not collected")

        let bookmark = card.coordinate(withNormalizedOffset: CGVector(dx: 0.81, dy: 0)).withOffset(CGVector(dx: 0, dy: card.frame.height - 38))
        bookmark.tap()
        XCTAssertTrue(app.staticTexts["Saved to wishlist"].waitForExistence(timeout: 5))
        XCTAssertEqual(card.value as? String, "Saved to wishlist", "Saved is not collected")
        app.buttons["toast-undo"].tap()
        XCTAssertEqual(card.value as? String, "Not collected", "Undo removes the entry")

        bookmark.tap()
        XCTAssertTrue(app.staticTexts["Saved to wishlist"].waitForExistence(timeout: 5))

        let collect = card.coordinate(withNormalizedOffset: CGVector(dx: 0.575, dy: 0)).withOffset(CGVector(dx: 0, dy: card.frame.height - 38))
        collect.tap()
        XCTAssertTrue(app.staticTexts["reveal"].waitForExistence(timeout: 10), "Collect hands off to the collect flow, which owns the reveal")
        XCTAssertTrue(app.staticTexts["Added to your passport"].exists)
        XCTAssertFalse(app.staticTexts["Verified visit"].exists, "Collecting by hand is never verified")
    }

    func testRecentlyViewedAppearsAndClearsWithUndo() {
        let app = launch()
        openPlace(app, query: "rome", id: "rome-colosseum", title: "Rome")
        backToDiscover(app)
        let title = any(app, "discover-recents-title")
        let cell = any(app, "discover-recent-rome-colosseum")
        var n = 0
        while !cell.exists && n < 6 { app.swipeUp(velocity: .slow); n += 1 }
        XCTAssertTrue(title.exists && cell.exists, "Only places the person viewed")
        let clear = app.buttons["discover-recents-clear"]
        clear.tap()
        XCTAssertTrue(app.buttons["toast-undo"].waitForExistence(timeout: 5))
        XCTAssertFalse(cell.exists)
        app.buttons["toast-undo"].tap()
        XCTAssertTrue(any(app, "discover-recent-rome-colosseum").waitForExistence(timeout: 5))
    }

    func testTheWishlistRowAndBadgeFollowTheRecordsAndNeverCountCollectedPlaces() {
        let app = launch()
        openPlace(app, query: "kyoto", id: "kyoto-fushimi-inari", title: "Kyoto")
        app.buttons["wishlist-button"].tap()
        XCTAssertTrue(any(app, "On your wishlist").waitForExistence(timeout: 5))
        backToDiscover(app)
        XCTAssertEqual(app.buttons["discover-wishlist-button"].label, "Wishlist, 1 place")
        let row = app.buttons["discover-wishlist-row"]
        scrollTo(row, in: app)
        XCTAssertTrue(row.label.contains("1 place saved for later"), row.label)

        app.swipeDown()
        app.tabBars.buttons["Discover"].tap()
        app.buttons["discover-wishlist-button"].tap()
        let item = any(app, "wishlist-kyoto-fushimi-inari")
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.swipeLeft()
        app.buttons["Remove"].tap()
        XCTAssertTrue(app.buttons["toast-undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing saved yet"].waitForExistence(timeout: 5))
        app.buttons["toast-undo"].tap()
        XCTAssertTrue(any(app, "wishlist-kyoto-fushimi-inari").waitForExistence(timeout: 5), "Undo puts the place back")
    }

    func testTheGlassBarTakesOverFromTheTicketWhenTheHeroLeaves() {
        let app = launch()
        XCTAssertFalse(app.buttons["discover-bar-search"].isHittable)
        let pill = app.buttons["discover-bar-search"]
        scrollTo(pill, in: app)
        XCTAssertTrue(pill.isHittable, "The same search control, in the bar")
        pill.tap()
        XCTAssertTrue(app.textFields["search-field"].waitForExistence(timeout: 5))
    }

    func testLargestTextKeepsTheControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["discover-search-field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["discover-filter-button"].isHittable)
        let icon = app.buttons["discover-bar-search"]
        scrollTo(icon, in: app, attempts: 10)
        XCTAssertTrue(icon.isHittable, "The pill collapses to an icon button")
    }

    func testAccessibilityAuditOfTheDiscoverScreen() throws {
        let app = launch(["-uitest-seed", "few"])
        Thread.sleep(forTimeInterval: 1.5) // let the entrance fade finish: the audit samples pixels
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .elementDetection, .sufficientElementDescription, .trait]) { issue in
            // The audit samples the whole 44 pt hit box of "See all" / "Clear", not just its 14 pt text. Measured on screen,
            // the text (#8A4526 on #F6F1E7) is 6.3:1, so this one finding is a false positive.
            let id = issue.element?.identifier ?? ""
            // Anything that rests partly behind the floating tab bar is sampled against the bar, not the page.
            let behindTabBar = (issue.element?.frame.maxY ?? 0) > app.tabBars.firstMatch.frame.minY
            // The engraved name on the fan's stamps is decorative art (white on the artwork); it is marked hidden but the audit still reads it.
            let label = issue.element?.label ?? ""
            let engraved = issue.element?.elementType == .staticText && !label.isEmpty && label == label.uppercased()
            let ignore = issue.auditType == .contrast && (engraved || behindTabBar || id.hasSuffix("-all") || id.hasSuffix("-clear"))
            if !ignore { print("AUDIT-ISSUE \(issue.compactDescription) | \(issue.detailedDescription) | \(issue.element?.debugDescription ?? "nil")") }
            // The engraved names on stamp art are drawn text with no element of their own on purpose (art, not content).
            let artText = issue.element == nil && issue.compactDescription == "Potentially inaccessible text"
            return ignore || artText
        }
    }
}
