import XCTest

/// Stamp detail (S2 Stage) and the collection reveal. Seed `memories` is the `few` passport plus ten memories: Paris is a verified
/// visit; Kyoto, Santorini and Rome are collected by hand; Sydney is not collected.
@MainActor
final class StampDetailUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @discardableResult
    private func launch(_ id: String, extra: [String] = [], reduceMotion: Bool = true, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-uitest-skip-onboarding", "-uitest-seed", "memories", "-uitest-url", "stampquest://stamp/\(id)"]
        if reset { args.append("-uitest-reset") }
        if reduceMotion { args.append("-uitest-reduce-motion") }
        app.launchArguments = args + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["stamp-state-title"].waitForExistence(timeout: 15), "Stamp detail did not open")
        return app
    }

    private func title(_ app: XCUIApplication) -> String { app.staticTexts["stamp-state-title"].label }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 8) {
        var n = 0
        while !element.isHittable && n < attempts { app.swipeUp(); n += 1 }
    }

    private func openMore(_ app: XCUIApplication) {
        let more = app.buttons["stamp-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
    }

    // MARK: The four states

    func testEachStateShowsItsOwnTicketAndActions() {
        let verified = launch("paris-eiffel-tower")
        XCTAssertEqual(title(verified), "Verified visit")
        XCTAssertTrue(verified.buttons["stamp-add-memory"].exists && verified.buttons["stamp-share"].exists)
        XCTAssertFalse(verified.buttons["verify-button"].exists, "A verified stamp has nothing left to verify")
        XCTAssertFalse(verified.buttons["stamp-collect"].exists)
        verified.terminate()

        let manual = launch("kyoto-fushimi-inari")
        XCTAssertEqual(title(manual), "In your passport")
        XCTAssertTrue(manual.buttons["verify-button"].exists, "Collected by hand can still be verified")
        manual.terminate()

        let none = launch("sydney-opera-house")
        XCTAssertEqual(title(none), "Not in your passport yet")
        XCTAssertTrue(none.buttons["stamp-collect"].exists && none.buttons["stamp-wishlist"].exists)
        XCTAssertFalse(none.buttons["stamp-add-memory"].exists)
    }

    func testTheStampItselfSaysItsStateInWords() {
        let app = launch("kyoto-fushimi-inari")
        let stamp = app.images.matching(NSPredicate(format: "label CONTAINS 'Collected by hand'")).firstMatch
        XCTAssertTrue(stamp.waitForExistence(timeout: 5), "The stamp's own label carries the state, never colour alone")
    }

    // MARK: Wishlist

    func testWishlistThenSavedThenBackWithoutCountingAsCollected() {
        let app = launch("sydney-opera-house")
        app.buttons["stamp-wishlist"].tap()
        XCTAssertTrue(app.staticTexts["On your wishlist"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["stamp-collect"].exists, "A wishlisted stamp can still be collected")
        XCTAssertFalse(app.buttons["stamp-add-memory"].exists, "It is not in the passport")
        app.buttons["stamp-wishlist"].tap()
        XCTAssertTrue(app.staticTexts["Not in your passport yet"].waitForExistence(timeout: 5))
    }

    // MARK: Collect and the reveal

    func testCollectRevealDoneMorphsBackAndSurvivesARelaunch() {
        let app = launch("sydney-opera-house")
        app.buttons["stamp-collect"].tap()
        let chip = app.staticTexts["reveal-confirmation"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "The reveal follows the saved collect")
        XCTAssertEqual(chip.label, "Added to your passport", "Collected by hand is never labelled verified")
        XCTAssertTrue(app.staticTexts["reveal-date"].label.hasPrefix("Collected by hand"))
        app.buttons["reveal-done"].tap()
        XCTAssertTrue(app.buttons["reveal-done"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(title(app), "In your passport")
        XCTAssertTrue(app.buttons["stamp-add-memory"].exists)
        app.terminate()

        let again = launch("sydney-opera-house", reset: false)
        XCTAssertEqual(title(again), "In your passport", "Collected stays collected")
        XCTAssertFalse(again.buttons["reveal-done"].exists, "The reveal never replays on reopening")
    }

    func testTheRevealCanBeLeftWithXAtAnyMoment() {
        let app = launch("sydney-opera-house", reduceMotion: false)
        app.buttons["stamp-collect"].tap()
        let close = app.buttons["reveal-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "The X is there from the first frame")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertEqual(title(app), "In your passport")
    }

    func testAddAMemoryFromTheRevealOpensTheCreateSheet() {
        let app = launch("sydney-opera-house")
        app.buttons["stamp-collect"].tap()
        XCTAssertTrue(app.buttons["reveal-add-memory"].waitForExistence(timeout: 10))
        app.buttons["reveal-add-memory"].tap()
        XCTAssertTrue(app.textFields["memory-title"].waitForExistence(timeout: 10))
        app.buttons["memory-cancel"].tap()
        XCTAssertEqual(title(app), "In your passport", "Cancel leaves the collected detail, and there is no second reveal")
        XCTAssertFalse(app.staticTexts["reveal-confirmation"].exists)
    }

    // MARK: Failures

    func testCollectFailedShowsTheAlertChangesNothingAndTryAgainWorks() {
        let app = launch("sydney-opera-house", extra: ["-uitest-stamp-collect-fails-once"])
        app.buttons["stamp-collect"].tap()
        let alert = app.alerts["Sydney was not added"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts["Nothing was saved and your passport is unchanged. Your stamp stays where it was."].exists)
        XCTAssertFalse(app.staticTexts["reveal-confirmation"].exists, "A failure never plays a success")
        alert.buttons["Not now"].tap()
        XCTAssertEqual(title(app), "Not in your passport yet")

        app.buttons["stamp-collect"].tap()
        XCTAssertTrue(app.staticTexts["reveal-confirmation"].waitForExistence(timeout: 10), "The retry succeeds")
    }

    func testTryAgainOnTheCollectAlertCollects() {
        let app = launch("sydney-opera-house", extra: ["-uitest-stamp-collect-fails-once"])
        app.buttons["stamp-collect"].tap()
        let alert = app.alerts["Sydney was not added"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.buttons["Try again"].tap()
        XCTAssertTrue(app.staticTexts["reveal-confirmation"].waitForExistence(timeout: 10))
    }

    // MARK: Remove

    func testRemoveAsksFirstKeepsMemoriesAndReturnsToNotCollected() {
        let app = launch("kyoto-fushimi-inari")
        openMore(app)
        app.buttons["stamp-menu-remove"].tap()
        let alert = app.alerts["Remove Kyoto from your passport?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'memories and trips stay'")).firstMatch.exists, "It states its scope")
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(title(app), "In your passport", "Nothing is removed before the confirmation")

        openMore(app)
        app.buttons["stamp-menu-remove"].tap()
        app.alerts["Remove Kyoto from your passport?"].buttons["Remove stamp"].tap()
        XCTAssertTrue(app.staticTexts["Not in your passport yet"].waitForExistence(timeout: 5), "The stamp returns to not collected at once")
        XCTAssertTrue(app.staticTexts["Kyoto removed from your passport."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["stamp-collect"].exists)

        app.buttons["stamp-back"].tap()
        app.tabBars.buttons["Memories"].tap()
        XCTAssertTrue(app.staticTexts["memories-subline"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["memories-subline"].label, "13 memories from 5 places", "Removing a stamp never removes a memory")
    }

    func testRemovingAVerifiedStampSaysTheVerifiedVisitGoesToo() {
        let app = launch("paris-eiffel-tower")
        openMore(app)
        app.buttons["stamp-menu-remove"].tap()
        let alert = app.alerts["Remove Paris from your passport?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'verified visit is removed too'")).firstMatch.exists)
    }

    func testRemoveFailedShowsAnAlertAndChangesNothing() {
        let app = launch("kyoto-fushimi-inari", extra: ["-uitest-stamp-remove-fails-once"])
        openMore(app)
        app.buttons["stamp-menu-remove"].tap()
        app.alerts["Remove Kyoto from your passport?"].buttons["Remove stamp"].tap()
        let alert = app.alerts["Kyoto was not removed"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.buttons["Not now"].tap()
        XCTAssertEqual(title(app), "In your passport")
    }

    func testTheMenuOfAStampThatIsNotCollectedHasNoRemove() {
        let app = launch("sydney-opera-house")
        openMore(app)
        XCTAssertTrue(app.buttons["stamp-menu-destination"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["stamp-menu-remove"].exists, "Wishlist removal is the Saved pill, not the menu")
    }

    // MARK: Lower page and scroll

    func testThePostmarkSwitchTogglesAndKeepsItsValue() {
        let app = launch("kyoto-fushimi-inari")
        let sw = app.switches["stamp-postmark-switch"]
        scrollTo(sw, in: app)
        XCTAssertEqual(sw.value as? String, "1")
        sw.tap()
        XCTAssertEqual(sw.value as? String, "0")
        app.buttons["stamp-bar-back"].exists ? () : ()
    }

    func testTheStickyBarTakesOverAndBackStillWorks() {
        let app = launch("kyoto-fushimi-inari")
        XCTAssertFalse(app.buttons["stamp-bar-back"].isHittable)
        let back = app.buttons["stamp-bar-back"]
        scrollTo(back, in: app, attempts: 6)
        XCTAssertTrue(back.isHittable)
        Thread.sleep(forTimeInterval: 0.6)
        back.tap()
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 10), "Back pops to the screen it came from")
    }

    func testEveryTappableReachesItsDestination() {
        let app = launch("kyoto-fushimi-inari")
        let card = app.buttons["stamp-collection-card"]
        scrollTo(card, in: app)
        XCTAssertTrue(card.label.contains("collected"), card.label)
        let collectionTitle = card.label.components(separatedBy: ", ").first ?? ""
        card.tap()
        XCTAssertTrue(app.navigationBars[collectionTitle].waitForExistence(timeout: 10), "The collection card opens its collection: \(collectionTitle)")
        app.navigationBars.buttons.firstMatch.tap()

        let related = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'stamp-related-' AND identifier != 'stamp-related-all'")).firstMatch
        scrollTo(related, in: app)
        XCTAssertTrue(related.exists)
        related.tap()
        XCTAssertTrue(app.staticTexts["stamp-state-title"].waitForExistence(timeout: 10), "A related stamp opens another Stamp detail")
        app.buttons["stamp-back"].tap()

        let destination = app.buttons["stamp-destination-row"]
        scrollTo(destination, in: app)
        destination.tap()
        XCTAssertTrue(app.buttons["collect-button"].waitForExistence(timeout: 10) || app.buttons["view-in-passport-button"].waitForExistence(timeout: 10), "Destination detail")
    }

    func testMemoriesHereOpensTheTimelineFilteredToThisPlace() {
        let app = launch("kyoto-fushimi-inari")
        let row = app.buttons["stamp-memories-row"]
        scrollTo(row, in: app, attempts: 10)
        XCTAssertTrue(row.exists, "Shown whenever the place has memories")
        row.tap()
        XCTAssertTrue(app.staticTexts["memories-showing"].waitForExistence(timeout: 10), "The Memories tab, filtered to the place")
    }

    func testAddMemoryAndShareOpenTheirFlows() {
        let app = launch("kyoto-fushimi-inari")
        app.buttons["stamp-add-memory"].tap()
        XCTAssertTrue(app.textFields["memory-title"].waitForExistence(timeout: 10))
        app.buttons["memory-cancel"].tap()
        app.buttons["stamp-share"].tap()
        XCTAssertTrue(app.buttons["share-image"].waitForExistence(timeout: 15))
    }

    func testLargestTextStacksTheActionsAndKeepsEverythingReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-skip-onboarding", "-uitest-reduce-motion", "-uitest-seed", "memories", "-uitest-url", "stampquest://stamp/sydney-opera-house",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["stamp-state-title"].waitForExistence(timeout: 15))
        let collect = app.buttons["stamp-collect"], wishlist = app.buttons["stamp-wishlist"]
        scrollTo(collect, in: app)
        XCTAssertTrue(collect.isHittable)
        XCTAssertGreaterThan(wishlist.frame.minY, collect.frame.minY, "At accessibility sizes the pills stack")
    }
}
