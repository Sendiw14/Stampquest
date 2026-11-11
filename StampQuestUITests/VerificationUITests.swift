import XCTest

/// Verification (step 4): the preview toggle, the explainer, and the paths to Cover. The real system location alert is
/// never automated; the scripted location provider (`-uitest-location`) stands in for it.
@MainActor
final class VerificationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(location: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset", "-uitest-reduce-motion", "-uitest-onboarding-start", "verification"] + extra
        if let location { app.launchArguments += ["-uitest-location", location] }
        app.launch()
        return app
    }

    private func select(_ app: XCUIApplication, verified: Bool) {
        let segment = app.buttons["onboarding.verification.control." + (verified ? "verified" : "collected")]
        if !segment.waitForExistence(timeout: 10) { XCTFail("segment missing") }
        segment.tap()
    }

    /// The hero is one accessibility element whose identifier says which overlay it shows.
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    private func reachesCover(_ app: XCUIApplication) -> Bool { app.buttons["onboarding.cover.cta"].waitForExistence(timeout: 10) }

    func testTogglingChangesTheCaptionAndTheOverlay() {
        let app = launch()
        let caption = app.staticTexts["onboarding.verification.caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        XCTAssertEqual(caption.label, "You added it yourself. No location needed.")
        XCTAssertTrue(element(app, "verification.postmark").exists)
        XCTAssertFalse(element(app, "verification.seal").exists)
        select(app, verified: true)
        XCTAssertTrue(element(app, "verification.seal").waitForExistence(timeout: 5))
        XCTAssertTrue(caption.waitForLabel("Your phone was there. It earns a gold seal."))
        select(app, verified: false)
        XCTAssertTrue(element(app, "verification.postmark").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "verification.seal").exists, "toggling back removes the seal")
        XCTAssertFalse(app.alerts.firstMatch.exists, "the toggle never asks for location")
    }

    func testTheCTAOpensTheExplainerAndNotNowThereLandsOnCoverWithTheNotice() {
        let app = launch(location: "undetermined-then-allow")
        app.buttons["onboarding.verification.cta"].tap()
        XCTAssertTrue(app.staticTexts["Before your iPhone asks"].waitForExistence(timeout: 10))
        app.buttons["onboarding.verification.explainer.notNow"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.verification.notice"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["onboarding.verification.cta"].label, "Continue")
        app.buttons["onboarding.verification.cta"].tap()
        XCTAssertTrue(reachesCover(app))
    }

    func testGrantedPathAdvancesToCover() {
        let app = launch(location: "undetermined-then-allow")
        app.buttons["onboarding.verification.cta"].tap()
        app.buttons["onboarding.verification.explainer.continue"].tap()
        XCTAssertTrue(reachesCover(app))
    }

    func testDeniedPathShowsTheNoticeThenContinueReachesCover() {
        let app = launch(location: "denied")
        app.buttons["onboarding.verification.cta"].tap()
        app.buttons["onboarding.verification.explainer.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.verification.notice"].waitForExistence(timeout: 10))
        app.buttons["onboarding.verification.cta"].tap()
        XCTAssertTrue(reachesCover(app))
    }

    func testNotNowLandsOnCover() {
        let app = launch()
        app.buttons["onboarding.verification.notNow"].tap()
        XCTAssertTrue(reachesCover(app))
    }

    func testSkipLandsOnCover() {
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.verification.skip"].waitForExistence(timeout: 10))
        app.buttons["onboarding.verification.skip"].tap()
        XCTAssertTrue(reachesCover(app))
    }

    func testBackReturnsToTheFirstStamp() {
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.verification.back"].waitForExistence(timeout: 10))
        app.buttons["onboarding.verification.back"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.firstStamp.title"].waitForExistence(timeout: 10))
    }

    func testLargestDynamicTypeKeepsTheActionsReachable() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].isHittable)
        XCTAssertTrue(app.buttons["onboarding.verification.notNow"].isHittable)
    }

    func testScreenshotsForTheReport() {
        for (name, args) in [("light", ["-AppleInterfaceStyle", "Light"]), ("dark", ["-AppleInterfaceStyle", "Dark"])] {
            let app = launch(extra: args)
            XCTAssertTrue(app.staticTexts["onboarding.verification.caption"].waitForExistence(timeout: 10))
            attach(app, "verification-collected-\(name)")
            select(app, verified: true)
            XCTAssertTrue(element(app, "verification.seal").waitForExistence(timeout: 10), "seal in \(name)")
            attach(app, "verification-verified-\(name)")
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
    func waitForLabel(_ label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
