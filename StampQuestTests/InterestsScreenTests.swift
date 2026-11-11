import Testing
import SwiftUI
import UIKit
@testable import StampQuest

struct InterestsContentTests {
    @Test func interestsStayInTheDesignedRowMajorOrder() {
        #expect(Interest.allCases == [.cities, .coasts, .mountains, .food, .history, .hiddenGems])
        #expect(Interest.allCases.map(\.index) == Array(0..<6))
    }

    @Test(arguments: Interest.allCases)
    func everyInterestHasStringsArtAPastelAndAnIdentifier(interest: Interest) {
        let name = Bundle.main.localizedString(forKey: interest.nameKey, value: nil, table: nil)
        let description = Bundle.main.localizedString(forKey: interest.descKey, value: nil, table: nil)
        #expect(name != interest.nameKey && !name.isEmpty)
        #expect(description != interest.descKey && !description.isEmpty)
        #expect(interest.accessibilityIdentifier == "interest." + interest.rawValue)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let paper = UIColor(interest.paper).resolvedColor(with: traits)
            #expect(paper.cgColor.alpha == 1)
        }
    }

    @Test func theBadgeAndPostmarkShowExactlyWhenAStampIsPicked() {
        let picked = InterestSlotLayers(isSelected: true), empty = InterestSlotLayers(isSelected: false)
        #expect(picked.badge && picked.postmark && picked.stamp && !picked.ghost)
        #expect(!empty.badge && !empty.postmark && !empty.stamp && empty.ghost)
    }

    @Test func pickedStampsTiltTwoDegreesAlternately() {
        #expect(Interest.allCases.map(\.pickedTilt) == [-2, 2, -2, 2, -2, 2])
    }

    @Test(arguments: [(0, "Pick at least one to continue."), (1, "1 picked. You can change this any time."),
                      (2, "2 picked. You can change this any time."), (6, "6 picked. You can change this any time.")])
    func counterTextCoversZeroOneTwoAndSix(count: Int, expected: String) {
        let text = count == 0
            ? String(localized: "onboarding.interests.hint.none")
            : String(localized: "onboarding.interests.hint.count \(count)")
        #expect(text == expected)
    }

    @Test func announcementReadsHowManyArePicked() {
        #expect(String(localized: "onboarding.interests.a11y.selectedCount \(2)") == "2 picked")
        #expect(String(localized: "onboarding.interests.a11y.hint") == "Double tap to pick or unpick.")
    }

    @Test func titleMarksOneStampWordOnTwoLines() throws {
        let tokens = try #require(HeadlineMarkup.parse(markdown: String(localized: "onboarding.interests.title")))
        #expect(tokens.map(\.text) == ["What", "do", "you", "love", "to", "find", "?"])
        #expect(tokens.map(\.kind) == [.plain, .plain, .plain, .plain, .plain, .highlight(0), .plain])
        #expect(tokens.map(\.lineBreakBefore) == [false, false, false, true, false, false, false])
        #expect(tokens.last?.spaceBefore == false, "the question mark follows the frame with no gap")
        #expect(HeadlineMarkup.plainText(String(localized: "onboarding.interests.title")) == "What do you love to find?")
    }

    @Test func markdownWithUnbalancedMarkersFallsBackToPlainText() {
        #expect(HeadlineMarkup.parse(markdown: "What do you love to **find?") == nil)
        #expect(HeadlineMarkup.parse(markdown: "What do you love to find?") == nil)
    }

    @Test func headlineTokensMapToTheirEntranceBeats() throws {
        let tokens = try #require(HeadlineMarkup.parse(markdown: String(localized: "onboarding.interests.title")))
        let beats = tokens.indices.map { InterestsTimeline.beat(forTokenAt: $0, in: tokens) }
        #expect(beats == [.firstLine, .firstLine, .firstLine, .secondLine, .secondLine, .find, .questionMark])
    }
}

struct InterestsMetricsTests {
    @Test func pageAndColumnsMatchTheReferenceOnA402PointScreen() {
        let page = InterestsMetrics.pageWidth(screenWidth: 402)
        #expect(page == 362)
        #expect(abs(InterestsMetrics.columnWidth(pageWidth: page, columns: 3) - 109.33) < 0.01)
        #expect(InterestsMetrics.stampScale(columnWidth: 109) == 1)
    }

    @Test func stampsShrinkToFitAnSEAndGrowAtMostTwentyPercent() {
        let se = InterestsMetrics.columnWidth(pageWidth: InterestsMetrics.pageWidth(screenWidth: 375), columns: 3)
        #expect(InterestsMetrics.stampScale(columnWidth: se) < 1 && se * 0.9 > InterestsMetrics.stampSize.width)
        let pad = InterestsMetrics.columnWidth(pageWidth: InterestsMetrics.pageWidth(screenWidth: 1024), columns: 3)
        #expect(InterestsMetrics.stampScale(columnWidth: pad) == 1.2)
    }

    @Test func iPadUsesACenteredColumnOfFiveHundredTwentyPoints() {
        #expect(InterestsMetrics.pageWidth(screenWidth: 1024) == 480)
    }

    @Test func stampWindowAndCaptionMatchTheAnatomy() {
        let layout = StampCard<EmptyView, EmptyView>.layout(size: InterestsMetrics.stampSize, minBorder: InterestsMetrics.stampMinBorder,
                                                            minCaption: InterestsMetrics.stampMinCaption)
        #expect(layout.art == CGRect(x: 9, y: 9, width: 66, height: 73))
        #expect(layout.caption.height == 24)
    }
}

struct InterestsTimelineTests {
    private let timeline = InterestsTimeline.standard

    @Test func cellsStaggerNinetyMillisecondsAndLabelsFollowByOneHundred() {
        for index in 0..<6 {
            #expect(abs(timeline.delay(of: .cell(index)) - (0.95 + 0.09 * Double(index))) < 0.0001)
            #expect(abs(timeline.delay(of: .label(index)) - timeline.delay(of: .cell(index)) - 0.10) < 0.0001)
        }
    }

    @Test func scheduleIsSortedAndEndsWithTheCTA() {
        let schedule = timeline.schedule(cells: 6)
        #expect(schedule.map(\.time) == schedule.map(\.time).sorted())
        #expect(schedule.count == timeline.beats(cells: 6).count)
        #expect(schedule.last?.beat == .cta || schedule.last?.beat == .label(5))
        #expect(timeline.delay(of: .cta) == 1.5)
    }

    @Test func entranceFollowsTheSpecifiedOrder() {
        let order: [InterestsTimeline.Beat] = [.back, .skip, .progress, .firstLine, .secondLine, .page, .find, .questionMark, .subtitle, .counter, .cta]
        let delays = order.map { timeline.delay(of: $0) }
        #expect(delays == [0.05, 0.08, 0.10, 0.20, 0.36, 0.55, 0.62, 0.95, 1.00, 1.30, 1.50])
        #expect(timeline.delay(of: .progressDots) == 0.40)
    }
}

struct InterestsColorTests {
    private func resolved(_ name: String, _ style: UIUserInterfaceStyle) -> [CGFloat] {
        let traits = UITraitCollection(userInterfaceStyle: style)
        guard let color = UIColor(named: name, in: .main, compatibleWith: traits)?.resolvedColor(with: traits) else { return [] }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    private func over(_ top: [CGFloat], _ bottom: [CGFloat], alpha: CGFloat) -> [CGFloat] {
        (0..<3).map { top[$0] * alpha + bottom[$0] * (1 - alpha) } + [1]
    }

    private func ratio(_ a: [CGFloat], _ b: [CGFloat]) -> Double {
        func luminance(_ c: [CGFloat]) -> Double {
            func lin(_ v: CGFloat) -> Double { v <= 0.03928 ? Double(v) / 12.92 : pow((Double(v) + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    @Test func everyTokenResolvesInBothAppearances() {
        for name in OnbColor.assetNames {
            for style in [UIUserInterfaceStyle.light, .dark] { #expect(!resolved(name, style).isEmpty, "\(name) \(style.rawValue)") }
        }
    }

    @Test func pastelBordersAreTheSameInBothAppearances() {
        for name in ["stampCities", "stampCoasts", "stampMountains", "stampFood", "stampHistory", "stampHiddenGems"] {
            #expect(resolved(name, .light) == resolved(name, .dark), "\(name)")
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func textMeetsFourPointFiveOnTheScreenBackground(style: UIUserInterfaceStyle) {
        let background = resolved("onbBackground", style)
        for name in ["inkPrimary", "inkSecondary", "inkTertiary", "accentText"] {
            #expect(ratio(resolved(name, style), background) >= 4.5, "\(name) \(style.rawValue)")
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func inkMeetsFourPointFiveOnThePassportPaperExceptTertiaryInDark(style: UIUserInterfaceStyle) {
        let paper = resolved("passportPaper", style)
        for name in ["inkPrimary", "inkSecondary"] { #expect(ratio(resolved(name, style), paper) >= 4.5, "\(name) \(style.rawValue)") }
        if style == .light {
            #expect(ratio(resolved("inkTertiary", style), paper) >= 4.5)
        } else {
            withKnownIssue("Specified dark inkTertiary measures 4.17:1 on passportPaper; the screen only sets it on the background") {
                #expect(ratio(resolved("inkTertiary", style), paper) >= 4.5)
            }
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func buttonAndStampWordLabelsMeetFourPointFive(style: UIUserInterfaceStyle) {
        #expect(ratio(resolved("ctaLabel", style), resolved("ctaFill", style)) >= 4.5)
        #expect(ratio(resolved("stampWordLabel", style), resolved("stampWordFill", style)) >= 4.5)
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func badgeGlyphAndSlotOutlineAtFullStrengthMeetThreeToOne(style: UIUserInterfaceStyle) {
        #expect(ratio(resolved("ctaLabel", style), resolved("onbAccent", style)) >= 3)
        #expect(ratio(resolved("onbAccent", style), resolved("passportPaper", style)) >= 3, "Increase Contrast slot outline")
    }

    /// The design keeps the slot outline at 60%: light measures about 2.4:1 on the paper. The test records it; it fails
    /// the day the opacity or token changes enough to pass, and 85% is the suggested fix.
    @Test func defaultSlotOutlineIsBelowThreeToOneAndEightyFivePercentPasses() {
        let paper = resolved("passportPaper", .light), accent = resolved("onbAccent", .light)
        let atSixty = ratio(over(accent, paper, alpha: 0.6), paper)
        let atEightyFive = ratio(over(accent, paper, alpha: 0.85), paper)
        withKnownIssue("Slot outline at 60% opacity is below 3:1 on the paper") { #expect(atSixty >= 3) }
        #expect(atEightyFive >= 3)
    }
}
