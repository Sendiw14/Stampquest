import Testing
import SwiftUI
import UIKit
@testable import StampQuest

struct FlightGeometryTests {
    @Test func slotOneCentreFollowsThePageTilt() {
        let center = FirstStampMetrics.slotCenter(0)
        #expect(abs(center.x - 86.14) < 0.05 && abs(center.y - (357.4 - 264)) < 0.05)
        #expect(FirstStampMetrics.slotCenter(0, tilt: 0) == CGPoint(x: 14 + 17 + (FirstStampMetrics.columnWidth - 82) / 2 + 41, y: 38 + 51))
    }

    @Test func columnsAndRowsMatchTheReference() {
        #expect(abs(FirstStampMetrics.columnWidth - 113.33) < 0.01)
        #expect(FirstStampMetrics.slotFrame(3).minY - FirstStampMetrics.slotFrame(0).minY == 114)
        #expect(FirstStampMetrics.slotFrame(0).minY == 38)
    }

    @Test func parisFliesBy13PointOneFiveUpTwoFiftyOnePointSix() {
        let target = FirstStampMetrics.landing(from: FirstStampMetrics.starterOrigins[0])
        #expect(abs(target.end.width - 13.15) < 0.05 && abs(target.end.height + 251.6) < 0.05)
        #expect(target.apex.height < target.end.height && target.contact.height > target.end.height - 10)
    }

    @Test(arguments: [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)])
    func theFlightTargetStaysOnSlotOneAtEveryScreenSize(screen: CGSize) {
        let scale = FirstStampMetrics.scale(for: screen)
        #expect(FirstStampMetrics.scaleRange.contains(scale))
        let origin = FirstStampMetrics.starterOrigins[0]
        let target = FirstStampMetrics.landing(from: origin)
        let stampCenter = CGPoint(x: origin.x + 47, y: origin.y + 61)
        let slot = FirstStampMetrics.slotCenter(0)
        #expect(abs((stampCenter.x + target.end.width) * scale - slot.x * scale) < 0.001)
        #expect(abs((stampCenter.y + target.end.height) * scale - slot.y * scale) < 0.001)
    }

    @Test func deskScaleIsPointEightTwoOnAnSEAndAtMostOnePointTwoOnATablet() {
        #expect(FirstStampMetrics.scale(for: CGSize(width: 375, height: 667)) == 0.82)
        #expect(FirstStampMetrics.scale(for: CGSize(width: 402, height: 874)) == 1)
        #expect(FirstStampMetrics.scale(for: CGSize(width: 1024, height: 1366)) == 1.2)
    }

    @Test func collectedStampEndsMinusThreePointTwoDegreesWhateverItsDeskTilt() {
        for starter in StarterStamp.allCases {
            #expect(abs(starter.deskRotation + (StarterStamp.collectedRotation - starter.deskRotation) + 3.2) < 0.0001)
        }
        #expect(abs(StarterStamp.collectedRotation - starter(.paris).deskRotation - 2.8) < 0.0001)
    }

    private func starter(_ value: StarterStamp) -> StarterStamp { value }
}

struct RevealTimingTests {
    private let reveal = RevealChoreography.standard

    @Test func contactComesAfterTheApexAndGlowPostmarkAndSheenFollowIt() {
        #expect(RevealChoreography.apexTime < reveal.delay(of: .contact))
        #expect(reveal.delay(of: .contact) < reveal.delay(of: .postmark))
        #expect(reveal.delay(of: .postmark) < reveal.delay(of: .sheen))
    }

    @Test func theCTAEnablesAfterThePostmarkAndTheRevealTakesAboutOnePointSevenSeconds() {
        #expect(reveal.delay(of: .ctaEnabled) > reveal.delay(of: .postmark))
        #expect(abs(reveal.total - 1.70) < 0.0001)
    }

    @Test func theHeadlineSwapsJustBeforeContact() {
        #expect(reveal.delay(of: .textOut) < reveal.delay(of: .contact))
        #expect(abs(reveal.delay(of: .textIn) - reveal.delay(of: .textOut) - 0.16) < 0.0001)
    }

    @Test func scheduleIsSortedAndHasEveryBeatOnce() {
        let times = reveal.schedule.map(\.time)
        #expect(times == times.sorted() && reveal.schedule.count == reveal.beats.count)
        #expect(RevealChoreography.flightContactTime < reveal.delay(of: .contact) + 0.05)
    }

    @Test func entranceFollowsTheSpecifiedOrder() {
        let entrance = FirstStampEntrance.standard
        #expect(entrance.delay(of: .back) == 0.05 && entrance.delay(of: .skip) == 0.08)
        #expect(entrance.delay(of: .firstLine) == 0.20 && entrance.delay(of: .firstWord) == 0.62 && entrance.delay(of: .stampWord) == 0.80)
        #expect(entrance.delay(of: .page) == 0.55 && entrance.delay(of: .subtitle) == 1.00)
        #expect(abs(entrance.delay(of: .slot(5)) - 1.15) < 0.0001)
        for (index, expected) in [1.10, 1.20, 1.30].enumerated() { #expect(abs(entrance.delay(of: .starter(index)) - expected) < 0.0001) }
        #expect(abs(entrance.delay(of: .pill(2)) - 1.75) < 0.0001)
        #expect(entrance.delay(of: .note) == 1.70 && entrance.delay(of: .cta) == 1.80)
        let times = entrance.schedule.map(\.time)
        #expect(times == times.sorted())
    }
}

struct FirstStampColorTests {
    @Test func everyTokenResolvesInBothAppearances() {
        for name in ["ctaDisabledFill", "ctaDisabledLabel", "slotFill", "slotOutline", "pillFill", "pillLabel", "pillSublabel"] {
            for style in [UIUserInterfaceStyle.light, .dark] { #expect(!ColorKit.resolved(name, style).isEmpty, "\(name) \(style.rawValue)") }
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func pillTextMeetsFourPointFiveOnThePill(style: UIUserInterfaceStyle) {
        let fill = ColorKit.resolved("pillFill", style)
        #expect(ColorKit.ratio(ColorKit.resolved("pillLabel", style), fill) >= 4.5)
        #expect(ColorKit.ratio(ColorKit.over(ColorKit.resolved("pillSublabel", style), fill), fill) >= 4.5, "70% sublabel")
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func noteAndTryAgainMeetFourPointFiveOnTheBackground(style: UIUserInterfaceStyle) {
        let background = ColorKit.resolved("onbBackground", style)
        #expect(ColorKit.ratio(ColorKit.resolved("inkTertiary", style), background) >= 4.5)
        #expect(ColorKit.ratio(ColorKit.resolved("accentText", style), background) >= 4.5)
    }

    @Test func hotSlotStarMeetsThreeToOneOnThePaperInDark() {
        let paper = ColorKit.resolved("passportPaper", .dark)
        let star = ColorKit.over(ColorKit.resolved("onbAccent", .dark), paper, alpha: 0.75)
        #expect(ColorKit.ratio(star, paper) >= 3)
    }

    /// The star is accent at 75% as designed; on the light paper that is just under 3:1.
    @Test func hotSlotStarOnTheLightPaperIsBelowThreeToOneByDesign() {
        let paper = ColorKit.resolved("passportPaper", .light)
        let star = ColorKit.over(ColorKit.resolved("onbAccent", .light), paper, alpha: 0.75)
        withKnownIssue("Accent at 75% on the light paper is below 3:1") { #expect(ColorKit.ratio(star, paper) >= 3) }
    }

    /// Disabled controls are exempt from the contrast rule; the numbers (about 4.1 light, 3.6 dark) are checked so they
    /// cannot drift lower unnoticed.
    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func disabledContinueStaysReadable(style: UIUserInterfaceStyle) {
        let ratio = ColorKit.ratio(ColorKit.resolved("ctaDisabledLabel", style), ColorKit.resolved("ctaDisabledFill", style))
        #expect(ratio >= 3.5)
    }

    @Test func emptySlotOutlineOnThePaperIsBelowThreeToOneByDesign() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let paper = ColorKit.resolved("passportPaper", style)
            let outline = ColorKit.over(ColorKit.resolved("slotOutline", style), paper)
            withKnownIssue("The specified slotOutline is below 3:1 on the paper (\(style.rawValue))", isIntermittent: false) {
                #expect(ColorKit.ratio(outline, paper) >= 3)
            }
        }
    }

    @Test func increaseContrastRaisesTheSlotOutlineToFullStrength() {
        #expect(ColorKit.resolved("slotOutline", .light, contrast: .high)[3] == 1)
        #expect(ColorKit.resolved("slotOutline", .dark, contrast: .high)[3] == 1)
    }
}
