import Testing
import SwiftUI
import UIKit
@testable import StampQuest

@MainActor
struct CoverScreenTests {
    let repository = InMemoryOnboardingRepository()

    func makeModel(plus: Bool = false) -> OnboardingModel {
        OnboardingModel(repository: repository, collector: StubCollector(), purchases: MockPurchaseService(),
                        flags: FeatureFlags(plusPaywallEnabled: plus), complete: { _ in })
    }

    @Test func harborIsTheDefaultAndTheNameIsEmpty() {
        let vm = CoverViewModel(model: makeModel())
        #expect(vm.selected == .harbor && vm.displayName.isEmpty && vm.typedName.isEmpty)
    }

    /// F1: the selected cover is stored at once; the name is stored only on Continue.
    @Test func selectingStoresTheCoverAtOnceAndTheNameWaitsForContinue() throws {
        let model = makeModel()
        let vm = CoverViewModel(model: model)
        vm.select(.forest)
        vm.setName("Alex")
        #expect(vm.selected == .forest && model.coverStyle == .forest && model.coverName.isEmpty)
        #expect(model.path.isEmpty)
        vm.continueTapped()
        #expect(try repository.load().coverStyle == .forest && model.path == [.passportReady])
    }

    @Test func plusMarkersFollowTheFlag() {
        let off = CoverViewModel(model: makeModel())
        #expect(off.covers.allSatisfy { !(off.showsPlus && $0.isPlus) } && off.covers == [.clay, .forest, .harbor])
        let on = CoverViewModel(model: makeModel(plus: true))
        #expect(on.showsPlus && on.covers.filter(\.isPlus) == [.midnight, .rosewood])
        on.select(.rosewood)
        #expect(on.selectedShowsPlusMarker && on.coverIsPlus)
        on.select(.harbor)
        #expect(!on.selectedShowsPlusMarker && !on.coverIsPlus)
    }

    @Test func aPlusCoverIsNeverBlocked() {
        let model = makeModel(plus: true)
        let vm = CoverViewModel(model: model)
        vm.select(.midnight)
        #expect(vm.selected == .midnight)
        vm.continueTapped()
        #expect(model.path == [.passportReady], "Continue went on")
    }

    @Test func theNameIsNormalisedAndCappedAtTwentyFourCharacters() {
        let vm = CoverViewModel(model: makeModel())
        vm.setName("  Alex \t  Rivera \u{7}  ")
        #expect(vm.displayName == "Alex Rivera")
        vm.setName(String(repeating: "x", count: 40))
        #expect(vm.displayName.count == CoverMetrics.nameLimit)
    }

    @Test(arguments: [(0, 14.0), (14, 14.0), (20, 9.8), (24, 8.5), (100, 8.5)])
    func theNameFontScalesPastFourteenCharactersAndNeverBelowEightPointFive(count: Int, expected: Double) {
        #expect(abs(Double(CoverMetrics.nameFontSize(characterCount: count)) - expected) < 0.01)
    }

    @Test func skipRoutesWithTheDefaultsAndBackKeepsTheStoredCover() throws {
        let model = makeModel()
        let vm = CoverViewModel(model: model)
        vm.select(.forest)
        model.back()
        #expect(model.coverStyle == .forest && model.path.isEmpty, "Back leaves the stored selection, which Cover shows again")
        vm.skipTapped()
        #expect(model.coverStyle == .harbor && model.coverName.isEmpty && model.path == [.passportReady])
    }

    @Test func theNameStaysOnTheDevice() throws {
        let model = makeModel()
        let vm = CoverViewModel(model: model)
        vm.setName("Alex Rivera")
        vm.continueTapped()
        #expect(try repository.load().name == "Alex Rivera")
        #expect(MockPurchaseService().isPlusEntitled == false, "nothing on this screen touches purchases")
    }
}

struct CoverMetricsTests {
    @Test func theHeroGroupIsTwoHundredFifteenByTwoEightyNine() {
        let group = CoverMetrics.groupSize(width: CoverMetrics.heroWidth, showsPageBlock: true)
        #expect(abs(group.width - 215.3) < 0.1 && abs(group.height - 288.6) < 0.1)
        #expect(CoverMetrics.groupSize(width: 206, showsPageBlock: false).width < group.width)
    }

    @Test func neighboursAreSevenTwentyEightThousandthsOnePitchAway() {
        #expect(CoverMetrics.scale(atDistance: 0) == 1)
        #expect(abs(CoverMetrics.scale(atDistance: 1) - 0.728) < 0.0001 && abs(CoverMetrics.scale(atDistance: -1) - 0.728) < 0.0001)
        #expect(CoverMetrics.scale(atDistance: 3) == CoverMetrics.scale(atDistance: 1), "further covers stay at the neighbour pose")
    }

    @Test func thePageBlockVanishesHalfAPitchFromTheCentre() {
        #expect(CoverMetrics.pageBlockOpacity(atDistance: 0) == 1)
        #expect(CoverMetrics.pageBlockOpacity(atDistance: 0.5) == 0 && CoverMetrics.pageBlockOpacity(atDistance: 1) == 0)
        #expect(abs(CoverMetrics.pageBlockOpacity(atDistance: 0.25) - 0.5) < 0.0001)
    }

    @Test func theDockIsCentredAtX71OnA402PointScreen() {
        let width = CoverMetrics.swatchOffset(4) + CoverMetrics.miniSize.width
        #expect(width == 260 && (402 - width) / 2 == 71)
        #expect(CoverMetrics.swatchOffset(1) == 56)
    }

    @Test func theEntranceFollowsTheSpecifiedOrder() {
        let timeline = CoverTimeline.standard
        let expected: [(CoverTimeline.Beat, Double)] = [
            (.back, 0.05), (.skip, 0.08), (.progress, 0.10), (.firstLine, 0.20), (.cover, 0.62), (.stop, 0.95), (.subtitle, 1.00),
            (.hero, 1.05), (.neighbours, 1.40), (.ring, 1.95), (.name, 2.05), (.field, 2.20), (.helper, 2.28), (.cta, 2.40),
        ] + (0..<5).map { (CoverTimeline.Beat.swatch($0), 1.75 + 0.06 * Double($0)) }
        for (beat, delay) in expected { #expect(abs(timeline.delay(of: beat) - delay) < 0.0001, "\(beat)") }
        #expect(Set(timeline.beats) == Set(expected.map(\.0)))
    }

    @Test func theHeadlineMarksTheCoverWordAndKeepsTheFullStopTight() throws {
        let markup = String(localized: "onboarding.cover.title")
        let tokens = try #require(HeadlineMarkup.parse(markdown: markup))
        #expect(tokens.map(\.text) == ["Pick", "your", "cover", "."] && tokens[2].kind == .highlight(0) && !tokens[3].spaceBefore)
        #expect(HeadlineMarkup.plainText(markup) == "Pick your cover.")
        #expect(tokens.indices.map { CoverTimeline.beat(forTokenAt: $0, in: tokens) } == [.firstLine, .firstLine, .cover, .stop])
    }

    @Test func everyStringTheScreenUsesIsInTheCatalog() {
        let keys = ["onboarding.cover.title", "onboarding.cover.subtitle", "onboarding.cover.name.placeholder", "onboarding.cover.name.helper",
                    "onboarding.cover.name.a11y", "onboarding.cover.cta", "onboarding.cover.plus", "onboarding.cover.a11y.carousel",
                    "onboarding.cover.a11y.swatches", "onboarding.cover.a11y.swatch %@", "onboarding.cover.a11y.swatch.plus %@",
                    "onboarding.cover.a11y.selected %@", "onboarding.cover.a11y.selected.plus %@", "onboarding.cover.a11y.hero.name %@ %@"]
            + CoverStyle.allCases.map(\.nameKey)
        for key in keys {
            let value = Bundle.main.localizedString(forKey: key, value: "MISSING", table: nil)
            #expect(value != "MISSING" && !value.isEmpty, "\(key)")
        }
        #expect(String(localized: "onboarding.cover.name.placeholder") == "Your name")
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func fieldUnderlineAndPlaceholderMeetTheirContrast(style: UIUserInterfaceStyle) {
        let background = ColorKit.resolved("onbBackground", style)
        let underline = ColorKit.over(ColorKit.resolved("inkPrimary", style), background, alpha: 0.5)
        #expect(ColorKit.ratio(underline, background) >= 3.0)
        #expect(ColorKit.ratio(ColorKit.resolved("inkSecondary", style), background) >= 4.5, "placeholder")
        #expect(ColorKit.ratio(ColorKit.resolved("accentText", style), background) >= 4.5)
        #expect(ColorKit.ratio(ColorKit.resolved("ctaLabel", style), ColorKit.resolved("ctaFill", style)) >= 4.5)
        #expect(ColorKit.ratio(ColorKit.resolved("inkPrimary", style), background) >= 14.5, "swatch ring")
    }
}
