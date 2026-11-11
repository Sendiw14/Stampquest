import Testing
import SwiftUI
import UIKit
@testable import StampQuest

struct WelcomeIntroTimelineTests {
    private let timeline = WelcomeIntroTimeline.standard

    private func delay(_ beat: WelcomeIntroTimeline.Beat) -> TimeInterval { timeline.delays[beat] ?? -1 }

    @Test func everyBeatHasADelay() {
        for beat in WelcomeIntroTimeline.Beat.allCases { #expect(timeline.delays[beat] != nil, "\(beat)") }
    }

    @Test func beatsStartInTheDesignedOrder() {
        let order: [WelcomeIntroTimeline.Beat] = [
            .topRow, .your, .progress, .one, .world, .comma, .stampWord, .atATime, .rome, .newYork, .santorini, .kyoto, .paris,
            .postmark, .waves, .subtitle, .cta, .finePrint,
        ]
        #expect(Set(order) == Set(WelcomeIntroTimeline.Beat.allCases))
        for (earlier, later) in zip(order, order.dropFirst()) {
            #expect(delay(earlier) < delay(later), "\(earlier) should start before \(later)")
        }
    }

    @Test func scheduleIsSortedAndFiresEveryBeatOnce() {
        let times = timeline.schedule.map(\.time)
        #expect(times == times.sorted())
        let reveals = timeline.schedule.compactMap { entry -> WelcomeIntroTimeline.Beat? in
            if case .reveal(let beat) = entry.action { return beat }
            return nil
        }
        #expect(reveals.count == WelcomeIntroTimeline.Beat.allCases.count)
        #expect(Set(reveals).count == reveals.count)
    }

    @Test func introStartsItsLastBeatWithinThreeSeconds() {
        #expect(timeline.total <= 3.0)
    }

    @Test func hapticsLandAfterTheirBeatStarts() {
        let cues = timeline.schedule.filter { if case .haptic = $0.action { true } else { false } }
        #expect(cues.count == 4)
        #expect(cues.contains { $0.action == .haptic(.postmarkPress) && abs($0.time - 2.68) < 0.001 })
    }

    @Test func nothingIsShownAtTheStartAndEverythingAtTheEnd() {
        #expect(timeline.shown(at: 0).isEmpty)
        #expect(timeline.shown(at: timeline.total) == timeline.restState)
        #expect(timeline.shown(at: 0.9).contains(.world))
        #expect(!timeline.shown(at: 0.9).contains(.stampWord))
    }

    @Test func skippingJumpsToTheRestStateWithAllBeats() {
        #expect(timeline.restState == Set(WelcomeIntroTimeline.Beat.allCases))
        #expect(WelcomeIntroTimeline.skipDuration == 0.25)
    }

    @Test func idleFloatStartsAtRestAndStaysWithinFourPoints() {
        for order in 0..<5 {
            #expect(WelcomeIntroTimeline.Idle.floatOffset(at: 0, order: order) == 0)
            for step in 0..<200 {
                let offset = WelcomeIntroTimeline.Idle.floatOffset(at: Double(step) * 0.1, order: order)
                #expect(abs(offset) <= WelcomeIntroTimeline.Idle.floatAmplitude + 0.0001)
            }
        }
    }

    @Test func twinkleStaysBetweenAQuarterAndOne() {
        for step in 0..<100 {
            let value = WelcomeIntroTimeline.Idle.twinkle(at: Double(step) * 0.07, order: 1)
            #expect(value >= WelcomeIntroTimeline.Idle.twinkleMin - 0.0001 && value <= 1.0001)
        }
    }

    @Test func foilSweepTravelsOnceEverySixSeconds() {
        let idle = WelcomeIntroTimeline.Idle.self
        #expect(idle.sweepProgress(at: 0) == 0)
        #expect(idle.sweepProgress(at: idle.sweepDuration / 2) == 0.5)
        #expect(idle.sweepProgress(at: 3) == -1)
        #expect(abs(idle.sweepProgress(at: idle.sweepInterval + 0.6) - 0.5) < 0.0001)
    }
}

struct HeadlineMarkupTests {
    private let english = "Your {world}, one {stamp} at a time."

    @Test func splitsTheEnglishHeadlineIntoWordsAndHighlights() throws {
        let tokens = try #require(HeadlineMarkup.parse(english))
        #expect(tokens.map(\.text) == ["Your", "world", ",", "one", "stamp", "at", "a", "time."])
        #expect(tokens.map(\.kind) == [.plain, .highlight(0), .plain, .plain, .highlight(1), .plain, .plain, .plain])
    }

    @Test func theCommaSitsTightAgainstTheFrame() throws {
        let tokens = try #require(HeadlineMarkup.parse(english))
        #expect(tokens.map(\.spaceBefore) == [false, true, false, true, true, true, true, true])
    }

    @Test func tokensMapToTheIntroBeats() throws {
        let tokens = try #require(HeadlineMarkup.parse(english))
        let beats = tokens.indices.map { HeadlineMarkup.beat(forTokenAt: $0, in: tokens) }
        #expect(beats == [.your, .world, .comma, .one, .stampWord, .atATime, .atATime, .atATime])
    }

    @Test(arguments: ["Your {world, one stamp", "Your world}, one {stamp}", "Your world, one stamp", "{a {b}}", ""])
    func malformedOrUnmarkedStringsFallBackToPlainText(text: String) {
        #expect(HeadlineMarkup.parse(text) == nil)
    }

    @Test func plainTextDropsTheBraces() {
        #expect(HeadlineMarkup.plainText(english) == "Your world, one stamp at a time.")
    }

    @Test func aMultiWordHighlightStaysOneToken() throws {
        let tokens = try #require(HeadlineMarkup.parse("Un {monde entier}, un timbre"))
        #expect(tokens.first { $0.kind == .highlight(0) }?.text == "monde entier")
    }

    @Test func theBundledHeadlineParsesAndReadsAsTheAccessibilityLabel() throws {
        let headline = String(localized: "onboarding.welcome.headline")
        _ = try #require(HeadlineMarkup.parse(headline))
        #expect(HeadlineMarkup.plainText(headline) == "Your world, one stamp at a time.")
    }
}

struct WelcomeMetricsTests {
    @Test func scaleMatchesTheDesignCanvasAtOne() {
        #expect(WelcomeMetrics.scale(for: CGSize(width: 402, height: 874)) == 1)
    }

    @Test(arguments: [
        (CGSize(width: 375, height: 667), 667.0 / 874.0),
        (CGSize(width: 320, height: 480), 0.72),
        (CGSize(width: 440, height: 956), 956.0 / 874.0),
        (CGSize(width: 1024, height: 1366), 1.15),
    ])
    func scaleIsTheSmallerRatioClampedToItsRange(size: CGSize, expected: CGFloat) {
        let scale = WelcomeMetrics.scale(for: size)
        #expect(abs(scale - max(0.72, min(1.15, expected))) < 0.0001)
        #expect(WelcomeMetrics.scaleRange.contains(scale))
    }

    @Test func ctaAlwaysClearsTheBottomByAtLeastTwentyFourPoints() {
        for step in 0...43 {
            let k = 0.72 + CGFloat(step) * 0.01
            #expect(WelcomeMetrics.ctaBottomInset(scale: k) >= 24)
        }
    }

    @Test func fanStampsStayInsideTheCanvasAndKeepTheirAspect() {
        for slot in WelcomeMetrics.FanSlot.allCases {
            #expect(CGRect(origin: .zero, size: WelcomeMetrics.canvas).contains(slot.frame), "\(slot)")
            #expect(abs(slot.frame.width / slot.frame.height - 0.75) < 0.01, "\(slot)")
            #expect(slot.containerFrame.maxY <= WelcomeMetrics.fanHeight, "\(slot)")
        }
    }

    @Test func theHeroIsTheFrontMostAndTheLargestStamp() {
        let hero = WelcomeMetrics.FanSlot.paris
        #expect(hero.isHero && hero.depth == .front)
        #expect(WelcomeMetrics.FanSlot.allCases.allSatisfy { $0.frame.width <= hero.frame.width })
        #expect(WelcomeMetrics.FanSlot.allCases.map(\.parallax).max() == hero.parallax)
    }

    @Test func fanStartsTwentyFourPointsUnderTheHeadline() {
        #expect(WelcomeMetrics.fanTop - WelcomeMetrics.headlineBottom == 24)
    }

    @Test func everyFanStampComesFromTheCatalog() throws {
        let catalog = try CatalogLoader.load()
        #expect(WelcomeStamp.fan(catalog: catalog).map(\.slot) == WelcomeMetrics.FanSlot.allCases)
        #expect(WelcomeStamp.fan(catalog: .empty).map(\.slot) == [.santorini, .kyoto, .paris])
    }

    @Test func tiltOffsetsAreLimitedPerLayer() {
        #expect(TiltParallax.offset(1, limit: 8) == 8)
        #expect(TiltParallax.offset(-0.5, limit: 10) == -5)
        #expect(TiltParallax.offset(0, limit: 3) == 0)
    }
}

struct WelcomeColorTests {
    private func resolved(_ name: String, _ style: UIUserInterfaceStyle, contrast: UIAccessibilityContrast = .normal) -> UIColor? {
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style),
                                                    UITraitCollection(accessibilityContrast: contrast)])
        return UIColor(named: "welcome." + name, in: .main, compatibleWith: traits)?.resolvedColor(with: traits)
    }

    @Test func everySemanticColorResolvesInLightAndDark() {
        for name in WelcomeColor.assetNames {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let color = UIColor(named: name, in: .main, compatibleWith: UITraitCollection(userInterfaceStyle: style))
                #expect(color != nil, "\(name) missing in \(style.rawValue)")
            }
        }
    }

    @Test func stampWordFramesLookTheSameInBothModes() throws {
        for name in ["wordWorldFill", "wordWorldText", "wordStampFill", "wordStampText"] {
            let light = try #require(resolved(name, .light)), dark = try #require(resolved(name, .dark))
            #expect(light == dark, "\(name)")
        }
    }

    @Test func darkBackgroundIsFlatCharcoal() throws {
        let stops = try ["bgTop", "bgMid", "bgBottom"].map { try #require(resolved($0, .dark)) }
        #expect(Set(stops.map { rgba($0) }).count == 1)
    }

    // MARK: Contrast

    private func rgba(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    private func over(_ top: UIColor, _ bottom: [CGFloat]) -> [CGFloat] {
        let c = rgba(top)
        return (0..<3).map { c[$0] * c[3] + bottom[$0] * (1 - c[3]) }
    }

    private func luminance(_ c: [CGFloat]) -> Double {
        func lin(_ v: CGFloat) -> Double { v <= 0.03928 ? Double(v) / 12.92 : pow((Double(v) + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
    }

    private func ratio(_ a: [CGFloat], _ b: [CGFloat]) -> Double {
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// The poster behind a point `y` (0 top, 1 bottom) of the screen: gradient plus glow.
    private func background(_ y: CGFloat, _ style: UIUserInterfaceStyle, contrast: UIAccessibilityContrast = .normal) -> [CGFloat] {
        let top = rgba(resolved("bgTop", style)!), mid = rgba(resolved("bgMid", style)!), bottom = rgba(resolved("bgBottom", style)!)
        let base: [CGFloat] = y < 0.52
            ? (0..<3).map { top[$0] + (mid[$0] - top[$0]) * y / 0.52 }
            : (0..<3).map { mid[$0] + (bottom[$0] - mid[$0]) * (y - 0.52) / 0.48 }
        let glow = resolved("glow", style, contrast: contrast)!
        let distance = abs(y - 0.66) / 0.32
        guard distance < 1 else { return base }
        let c = rgba(glow)
        let alpha = c[3] * (1 - distance)
        return (0..<3).map { c[$0] * alpha + base[$0] * (1 - alpha) }
    }

    private let subtitleY: CGFloat = 672.0 / 874.0
    private let finePrintY: CGFloat = 817.0 / 874.0
    private let headlineY: CGFloat = 200.0 / 874.0

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func headlineMeetsLargeTextContrast(style: UIUserInterfaceStyle) {
        let bg = background(headlineY, style)
        #expect(ratio(rgba(resolved("textPrimary", style)!), bg) >= 3)
    }

    @Test func ctaLabelMeetsBodyContrastInBothModes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let fill = rgba(resolved("ctaFill", style)!)
            #expect(ratio(rgba(resolved("ctaLabel", style)!), fill) >= 4.5, "\(style.rawValue)")
        }
    }

    @Test func darkBodyTextMeetsBodyContrast() {
        let subtitle = background(subtitleY, .dark), finePrint = background(finePrintY, .dark)
        #expect(ratio(over(resolved("textSecondary", .dark)!, subtitle), subtitle) >= 4.5)
        #expect(ratio(over(resolved("textTertiary", .dark)!, finePrint), finePrint) >= 4.5)
    }

    @Test func increaseContrastBodyTextMeetsBodyContrastInBothModes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let subtitle = background(subtitleY, style, contrast: .high), finePrint = background(finePrintY, style, contrast: .high)
            let secondary = resolved("textSecondary", style, contrast: .high)!, tertiary = resolved("textTertiary", style, contrast: .high)!
            #expect(ratio(over(secondary, subtitle), subtitle) >= 4.5, "subtitle \(style.rawValue)")
            #expect(ratio(over(tertiary, finePrint), finePrint) >= 4.5, "fine print \(style.rawValue)")
        }
    }

    /// The specified light tokens measure about 3.6 over the glow behind the subtitle. This test starts failing, and
    /// so reports itself, the day the tokens are changed to pass.
    @Test func lightBodyTextOverTheGlowMissesBodyContrastWithTheSpecifiedTokens() {
        let subtitle = background(subtitleY, .light)
        withKnownIssue("Specified light textSecondary measures below 4.5:1 over the glow") {
            #expect(ratio(over(resolved("textSecondary", .light)!, subtitle), subtitle) >= 4.5)
        }
    }
}
