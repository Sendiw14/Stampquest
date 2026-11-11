import Testing
import SwiftUI
import UIKit
@testable import StampQuest

@MainActor
struct PlusRouteTests {
    func makeModel(plus: Bool) -> OnboardingModel {
        OnboardingModel(repository: InMemoryOnboardingRepository(), collector: StubCollector(), purchases: MockPurchaseService(),
                        flags: FeatureFlags(plusPaywallEnabled: plus), complete: { _ in })
    }

    @Test func withTheFlagOffPassportReadyFinishesAndPlusIsNeverOnTheStack() {
        let model = makeModel(plus: false)
        model.continueFrom(.passportReady)
        #expect(model.isComplete && !model.path.contains(.plus))
        #expect(OnboardingRoute.flow(plusEnabled: false).allSatisfy { $0 != .plus })
        #expect(!FeatureFlags().plusPaywallEnabled)
    }

    @Test func withTheFlagOnPassportReadyGoesToPlus() {
        let model = makeModel(plus: true)
        model.continueFrom(.passportReady)
        #expect(model.path == [.plus] && !model.isComplete)
    }

    @Test func aPlusCoverWithoutPlusShowsTheFirstFreeCoverAndKeepsTheSelection() {
        #expect(CoverEntitlementResolver.effectiveCover(selected: .midnight, isEntitled: false) == .clay)
        #expect(CoverEntitlementResolver.effectiveCover(selected: .rosewood, isEntitled: false).rawValue == "clay")
        #expect(CoverEntitlementResolver.effectiveCover(selected: .midnight, isEntitled: true) == .midnight)
        #expect(CoverEntitlementResolver.effectiveCover(selected: .harbor, isEntitled: false) == .harbor)
    }

    @Test func termsAndPrivacyHaveURLs() {
        #expect(AppConfiguration.termsURL != nil && AppConfiguration.privacyPolicyURL != nil)
    }
}

struct PlusStringTests {
    nonisolated static let keys = [
        "onboarding.plus.headline.brand", "onboarding.plus.headline.word", "onboarding.plus.subtitle", "onboarding.plus.perks.a11y",
        "onboarding.plus.perk.collections", "onboarding.plus.perk.covers", "onboarding.plus.perk.layouts", "onboarding.plus.perk.sync",
        "onboarding.plus.plan.yearly", "onboarding.plus.plan.monthly", "onboarding.plus.billedMonthly", "onboarding.plus.timeline.today",
        "onboarding.plus.timeline.fullAccess", "onboarding.plus.timeline.remind", "onboarding.plus.timeline.begins",
        "onboarding.plus.renews.year", "onboarding.plus.renews.month", "onboarding.plus.renews.week", "onboarding.plus.renews.day",
        "onboarding.plus.cta.loading", "onboarding.plus.cta.retry", "onboarding.plus.finePrint.trial.cancel",
        "onboarding.plus.finePrint.billed.cancel", "onboarding.plus.banner.trial", "onboarding.plus.banner.subscribed",
        "onboarding.plus.banner.restored", "onboarding.plus.banner.pending", "onboarding.plus.error.purchase",
        "onboarding.plus.error.unavailable", "onboarding.plus.restore.none", "onboarding.plus.restore.failed", "onboarding.plus.restore",
        "onboarding.plus.terms", "onboarding.plus.privacy", "onboarding.plus.a11y.loading", "onboarding.plus.reminder.title",
        "onboarding.plus.reminder.body", "onboarding.plus.title", "onboarding.common.close", "onboarding.ready.a11y.progress",
        "onboarding.plus.badge.save %lld", "onboarding.plus.a11y.save %lld", "onboarding.plus.per %@", "onboarding.plus.perMonth %@",
        "onboarding.plus.a11y.selected %@ %@", "onboarding.plus.timeline.billed %@", "onboarding.plus.renews.every %@",
        "onboarding.plus.cta.trial %lld", "onboarding.plus.cta.subscribe %@ %@", "onboarding.plus.finePrint.trial %lld %@ %@",
        "onboarding.plus.finePrint.billed %@ %@", "onboarding.plus.unit.year %lld", "onboarding.plus.unit.month %lld",
        "onboarding.plus.unit.week %lld", "onboarding.plus.unit.day %lld",
    ]

    @Test(arguments: keys) func everyKeyExistsInTheCatalog(key: String) {
        let value = Bundle.main.localizedString(forKey: key, value: "__missing__", table: nil)
        #expect(value != "__missing__" && !value.isEmpty, "\(key)")
    }

    @Test func pluralsReadNaturally() {
        #expect(String(localized: "onboarding.plus.unit.year \(1)") == "year" && String(localized: "onboarding.plus.unit.month \(3)") == "3 months")
    }
}

struct PlusColorTests {
    @Test func theNewTokensResolveInBothAppearances() {
        for name in ["stampEdge", "cardHairline", "radioRing", "closeFill", "selectedTint"] {
            for style in [UIUserInterfaceStyle.light, .dark] { #expect(!ColorKit.resolved(name, style).isEmpty, "\(name) \(style.rawValue)") }
        }
    }

    /// Required minimums (light / dark) from the paywall spec.
    @Test(arguments: [(UIUserInterfaceStyle.light, 0), (UIUserInterfaceStyle.dark, 1)])
    func contrastMeetsTheRequiredMinimums(style: UIUserInterfaceStyle, index: Int) {
        func c(_ name: String) -> [CGFloat] { ColorKit.resolved(name, style) }
        let paper = c("passportPaper")
        let tinted = ColorKit.over(c("selectedTint"), paper)
        let background = c("onbBackground")
        func pick(_ light: Double, _ dark: Double) -> Double { index == 0 ? light : dark }
        #expect(ColorKit.ratio(c("inkPrimary"), tinted) >= pick(13.0, 9.3), "ink on selected paper")
        #expect(ColorKit.ratio(c("inkSecondary"), tinted) >= pick(5.4, 5.2), "secondary on selected paper")
        #expect(ColorKit.ratio(c("ctaLabel"), c("ctaFill")) >= pick(4.9, 6.5))
        #expect(ColorKit.ratio(c("ctaFill"), background) >= pick(4.5, 6.5))
        #expect(ColorKit.ratio(ColorKit.over(c("radioRing"), paper), paper) >= pick(3.6, 4.2), "radio ring vs paper")
        #expect(ColorKit.ratio(c("inkPrimary"), ColorKit.over(c("closeFill"), background)) >= pick(5.2, 6.2), "close glyph")
        #expect(ColorKit.ratio(c("ctaFill"), tinted) >= pick(4.1, 3.9), "perk icon on tint (graphic, 3.0 needed)")
        #expect(ColorKit.ratio(c("inkPrimary"), ColorKit.over(c("selectedTint"), background)) >= pick(12.5, 11.0), "banner")
    }
}
