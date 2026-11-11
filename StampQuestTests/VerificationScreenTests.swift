import Testing
import SwiftUI
import UIKit
@testable import StampQuest

struct VerificationContentTests {
    @Test func theSealHasTwentyEightScallops() {
        #expect(ScallopedCircle.scallopCount == 28)
        let path = ScallopedCircle().path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(path.boundingRect.width > 88 && path.boundingRect.width < 94)
    }

    @Test func theHeadlineMarksTwoStampWordsOnTwoLines() throws {
        let markup = String(localized: "onboarding.verification.title")
        let tokens = try #require(HeadlineMarkup.parse(markdown: markup))
        #expect(tokens.map(\.text) == ["Collected", "is", "yours", ".", "Verified", "is", "earned", "."])
        #expect(tokens.map(\.kind) == [.plain, .plain, .highlight(0), .plain, .plain, .plain, .highlight(1), .plain])
        #expect(tokens.filter { !$0.spaceBefore && $0.text == "." }.count == 2, "full stops sit tight against the frames")
        #expect(tokens[4].lineBreakBefore)
        #expect(HeadlineMarkup.plainText(markup) == "Collected is yours. Verified is earned.")
    }

    @Test func headlineTokensMapToTheirEntranceBeats() throws {
        let tokens = try #require(HeadlineMarkup.parse(markdown: String(localized: "onboarding.verification.title")))
        let beats = tokens.indices.map { VerificationTimeline.beat(forTokenAt: $0, in: tokens) }
        #expect(beats == [.firstLine, .firstLine, .yours, .firstStop, .secondLine, .secondLine, .earned, .secondStop])
    }

    @Test func entranceFollowsTheSpecifiedOrder() {
        let timeline = VerificationTimeline.standard
        let expected: [(VerificationTimeline.Beat, Double)] = [
            (.back, 0.05), (.skip, 0.08), (.progress, 0.10), (.firstLine, 0.20), (.secondLine, 0.40), (.yours, 0.62), (.firstStop, 0.95),
            (.earned, 1.00), (.secondStop, 1.30), (.subtitle, 1.00), (.hero, 1.05), (.control, 1.60), (.caption, 1.70), (.postmark, 1.80),
            (.bullet(0), 2.00), (.bullet(1), 2.10), (.bullet(2), 2.20), (.cta, 2.30), (.notNow, 2.45),
        ]
        for (beat, delay) in expected { #expect(abs(timeline.delay(of: beat) - delay) < 0.0001, "\(beat)") }
        #expect(Set(timeline.beats) == Set(expected.map(\.0)))
    }

    @Test func everyStringTheScreenUsesIsInTheCatalog() {
        let keys = [
            "onboarding.verification.title", "onboarding.verification.subtitle", "onboarding.verification.control.collected",
            "onboarding.verification.control.verified", "onboarding.verification.control.a11y", "onboarding.verification.caption.collected",
            "onboarding.verification.caption.verified", "onboarding.verification.trust.optional", "onboarding.verification.trust.foreground",
            "onboarding.verification.trust.private", "onboarding.verification.cta", "onboarding.verification.notNow",
            "onboarding.verification.postmark", "onboarding.verification.notice", "onboarding.verification.explainer.title",
            "onboarding.verification.explainer.body", "onboarding.verification.explainer.continue", "onboarding.verification.explainer.notNow",
            "onboarding.verification.a11y.hero.collected", "onboarding.verification.a11y.hero.verified", "onboarding.common.continue",
        ]
        for key in keys {
            let value = Bundle.main.localizedString(forKey: key, value: "MISSING", table: nil)
            #expect(value != "MISSING" && !value.isEmpty, "\(key)")
        }
    }

    @Test func theCopyMatchesTheSpecification() {
        #expect(String(localized: "onboarding.verification.cta") == "Turn on verified stamps")
        #expect(String(localized: "onboarding.verification.caption.collected") == "You added it yourself. No location needed.")
        #expect(String(localized: "onboarding.verification.caption.verified") == "Your phone was there. It earns a gold seal.")
        #expect(String(localized: "onboarding.verification.notice") == "No problem. Verified stamps stay off. You can turn them on later in Settings.")
    }

    @Test func theLocationUsageDescriptionIsWhenInUseOnly() {
        let info = Bundle.main.infoDictionary ?? [:]
        #expect(info["NSLocationWhenInUseUsageDescription"] as? String
                == "Used only when you tap Locate or verify a visit.", "The Map brief set this copy: location is used only for Locate and for verifying a visit")
        #expect(info["NSLocationAlwaysAndWhenInUseUsageDescription"] == nil && info["NSLocationAlwaysUsageDescription"] == nil)
        #expect(info["UIBackgroundModes"] == nil, "no background modes")
    }
}

struct VerificationColorTests {
    @Test func everyTokenResolvesInBothAppearances() {
        for name in ["goldWordFill", "goldWordLabel", "goldGlow", "segTrack", "segThumb", "segLabelOff", "sealInk", "sealRingShadow"] {
            for style in [UIUserInterfaceStyle.light, .dark] { #expect(!ColorKit.resolved(name, style).isEmpty, "\(name) \(style.rawValue)") }
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func textPairsMeetTheListedMinimums(style: UIUserInterfaceStyle) {
        let background = ColorKit.resolved("onbBackground", style)
        func ratio(_ foreground: String, _ against: [CGFloat]) -> Double { ColorKit.ratio(ColorKit.resolved(foreground, style), against) }
        #expect(ratio("inkPrimary", background) >= 14.5)
        #expect(ratio("inkSecondary", background) >= 6.0)
        #expect(ratio("accentText", background) >= 4.5)
        #expect(ratio("ctaLabel", ColorKit.resolved("ctaFill", style)) >= 4.5)
        #expect(ratio("goldWordLabel", ColorKit.resolved("goldWordFill", style)) >= 7.0)
        #expect(ratio("segLabelOff", ColorKit.resolved("segTrack", style)) >= 4.5)
        #expect(ratio("inkPrimary", ColorKit.resolved("segThumb", style)) >= 4.5)
    }

    @Test func trackAndThumbAreOnlyFaintlyDifferentFromTheirSurroundings() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let track = ColorKit.ratio(ColorKit.resolved("segTrack", style), ColorKit.resolved("onbBackground", style))
            #expect(track < 1.3, "the known gap: the thumb plus the label weight carry the selection (\(style.rawValue))")
        }
    }

    @Test func increaseContrastRemovesTheGoldGlow() {
        #expect(ColorKit.resolved("goldGlow", .light, contrast: .high)[3] == 0)
        #expect(ColorKit.resolved("goldGlow", .dark, contrast: .high)[3] == 0)
    }
}
