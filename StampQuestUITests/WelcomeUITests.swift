import XCTest

/// The Welcome poster: headline, call to action, the Reduce Motion launch argument and tap-to-skip.
@MainActor
final class WelcomeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(reduceMotion: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"] + (reduceMotion ? ["-uitest-reduce-motion"] : [])
        app.launch()
        return app
    }

    func testHeadlineThenCTAGoesToInterests() {
        let app = launch(reduceMotion: true)
        let headline = app.staticTexts["onboarding.welcome.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        XCTAssertEqual(headline.label, "Your world, one stamp at a time.")
        let cta = app.buttons["onboarding.welcome.cta"]
        XCTAssertTrue(cta.waitForHittable(timeout: 5))
        cta.tap()
        XCTAssertTrue(app.staticTexts["onboarding.interests.title"].waitForExistence(timeout: 10))
    }

    /// The intro keeps the CTA out of reach until 2.76 s; the rest state has it at once.
    private static let introCTAReach: TimeInterval = 2.4

    func testReduceMotionLaunchArgumentShowsTheRestStateImmediately() {
        let app = launch(reduceMotion: true)
        let headline = app.staticTexts["onboarding.welcome.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        let start = Date()
        XCTAssertTrue(app.buttons["onboarding.welcome.cta"].waitForHittable(timeout: Self.introCTAReach))
        XCTAssertLessThan(Date().timeIntervalSince(start), Self.introCTAReach)
        XCTAssertTrue(app.staticTexts["onboarding.welcome.subtitle"].exists)
        XCTAssertTrue(app.staticTexts["onboarding.welcome.caption"].exists)
    }

    func testTappingTheBackgroundDuringTheIntroJumpsToTheRestState() {
        let app = launch(reduceMotion: false)
        let headline = app.staticTexts["onboarding.welcome.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        let start = Date()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).tap()
        XCTAssertTrue(app.buttons["onboarding.welcome.cta"].waitForHittable(timeout: Self.introCTAReach))
        XCTAssertLessThan(Date().timeIntervalSince(start), Self.introCTAReach)
    }

    func testStampArtIsHiddenFromVoiceOver() {
        let app = launch(reduceMotion: true)
        XCTAssertTrue(app.staticTexts["onboarding.welcome.headline"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.images.matching(NSPredicate(format: "label CONTAINS[c] 'stamp'")).count, 0)
        XCTAssertFalse(app.buttons["onboarding.welcome.stamp.front"].exists)
    }
}

private extension XCUIElement {
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
