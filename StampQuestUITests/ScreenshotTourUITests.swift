import XCTest

/// Walks every onboarding screen in light and dark and attaches a screenshot of each to the result bundle (export with `xcresulttool export attachments`) for review. It asserts
/// only that each screen appeared; the images are looked at, not compared.
@MainActor
final class ScreenshotTourUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ route: String?, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-uitest-reset", "-uitest-reduce-motion", "-ff-plus", "-ff-coasts", "-uitest-subscriptions", "ok", "-uitest-notifications", "authorized",
                    "-uitest-packs", "ok", "-uitest-pack-art"]
        if ProcessInfo.processInfo.environment["TOUR_MODE"] == "dark" { args += ["-AppleInterfaceStyle", "Dark"] }
        if let route { args += ["-uitest-onboarding-start", route] }
        app.launchArguments = args + extra
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String, wait: TimeInterval = 2.5) {
        sleep(UInt32(wait.rounded(.up)))
        let mode = ProcessInfo.processInfo.environment["TOUR_MODE"] ?? "light"
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(name)-\(mode)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The appearance is set from outside with `xcrun simctl ui <udid> appearance light|dark`; `TEST_RUNNER_TOUR_MODE` only names the files.
    private func tour() {
        var app = launch(nil)
        XCTAssertTrue(app.buttons["onboarding.welcome.cta"].waitForExistence(timeout: 30))
        shot(app, "1-welcome")

        app = launch("interests")
        XCTAssertTrue(app.buttons["onboarding.interests.cta"].waitForExistence(timeout: 30))
        app.buttons["interest.cities"].tap()
        app.buttons["interest.coasts"].tap()
        shot(app, "2-interests")

        app = launch("firstStamp")
        XCTAssertTrue(app.buttons["starter.paris"].waitForExistence(timeout: 30))
        shot(app, "3a-firststamp-choosing")
        app.buttons["starter.paris"].tap()
        shot(app, "3b-firststamp-collected", wait: 3)

        app = launch("verification")
        XCTAssertTrue(app.buttons["onboarding.verification.cta"].waitForExistence(timeout: 30))
        shot(app, "4a-verification-collected")
        app.buttons["Verified"].firstMatch.tap()
        shot(app, "4b-verification-verified", wait: 3)
        app.buttons["onboarding.verification.cta"].tap()
        sleep(2)
        shot(app, "4c-verification-sheet", wait: 1)

        app = launch("cover")
        XCTAssertTrue(app.buttons["onboarding.cover.cta"].waitForExistence(timeout: 30))
        shot(app, "5a-cover-default")
        app.buttons["Rosewood cover, Plus"].firstMatch.tap()
        shot(app, "5b-cover-rosewood", wait: 3)

        app = launch("passportReady")
        XCTAssertTrue(app.buttons["onboarding.ready.cta"].waitForExistence(timeout: 30))
        shot(app, "6-ready", wait: 3)

        app = launch("plus")
        XCTAssertTrue(app.buttons["onboarding.plus.cta"].waitForExistence(timeout: 30))
        shot(app, "7a-plus-yearly", wait: 3)
        app.buttons["onboarding.plus.close"].tap()
        XCTAssertTrue(app.buttons["exitSheet.cta"].waitForExistence(timeout: 15))
        shot(app, "8-exit", wait: 3)
    }

    func testTour() { tour() }
}
