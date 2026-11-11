import Testing
import SwiftUI
import UIKit
@testable import StampQuest

@MainActor
struct PassportReadyTests {
    let repository = InMemoryOnboardingRepository()
    let location = MockLocationProvider()
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
    let now = Date(timeIntervalSince1970: 1_792_972_800 + 12 * 3_600)
    let locale = Locale(identifier: "en_US")

    func makeModel(plus: Bool = false) -> OnboardingModel {
        OnboardingModel(repository: repository, collector: StubCollector(), purchases: MockPurchaseService(),
                        flags: FeatureFlags(plusPaywallEnabled: plus), now: { now }, complete: { _ in })
    }

    func content(name: String = "Alex Rivera", stamp: (stamp: StarterStamp, collectedAt: Date)? = (.paris, Date(timeIntervalSince1970: 1_792_972_800 + 12 * 3_600)),
                 verification: VerificationChoice = .undecided, authorization: LocationAuthorization = .notDetermined) -> ReadyContent {
        ReadyContent(holderName: name, cover: .harbor, firstStamp: stamp, verification: verification, authorization: authorization,
                     issuedAt: now, now: now, calendar: calendar, locale: locale)
    }

    // MARK: Subtitle

    @Test func theSubtitleUsesOnlyTheFirstWordOfTheName() {
        #expect(content(name: "Alex Rivera").subtitle == "Alex, your first stamp is already inside.")
        #expect(content(name: "  Sam  ").subtitle == "Sam, your first stamp is already inside.")
    }

    @Test(arguments: ["", "   ", "\t "])
    func anEmptyNameUsesTheNamelessSentence(name: String) {
        let ready = content(name: name)
        #expect(ready.subtitle == "Your first stamp is already inside." && ready.holderName == nil)
    }

    @Test func noStampUsesTheReadyForItsFirstStampSentence() {
        #expect(content(stamp: nil).subtitle == "Add your first stamp whenever you like.")
    }

    // MARK: Rows

    @Test func rowOneReadsWithAndWithoutTheName() {
        #expect(content().rows[0] == ReadyContent.Row(status: .done, text: "Harbor cover, with your name"))
        #expect(content(name: "").rows[0] == ReadyContent.Row(status: .done, text: "Harbor cover"))
    }

    @Test func rowTwoSaysTodayAnEarlierDateOrThatThereIsNoStamp() {
        #expect(content().rows[1] == ReadyContent.Row(status: .done, text: "Paris stamp, collected today"))
        let earlier = now.addingTimeInterval(-3 * 86_400)
        #expect(content(stamp: (.paris, earlier)).rows[1].text == "Paris stamp, collected Oct 23, 2026")
        #expect(content(stamp: nil).rows[1] == ReadyContent.Row(status: .off, text: "No stamp yet"))
    }

    @Test(arguments: [
        (VerificationChoice.enabled, LocationAuthorization.authorized, true),
        (.enabled, .denied, false), (.enabled, .restricted, false), (.enabled, .notDetermined, false),
        (.denied, .authorized, false), (.skipped, .authorized, false), (.undecided, .authorized, false), (.undecided, .denied, false),
    ])
    func verifiedStampsAreOnOnlyWhenEnabledAndGrantedRightNow(choice: VerificationChoice, status: LocationAuthorization, on: Bool) {
        let row = content(verification: choice, authorization: status).rows[2]
        #expect(row.status == (on ? .done : .off))
        #expect(row.text == (on ? "Verified stamps are on" : "Verified stamps are off"))
    }

    @Test(arguments: [(0, "0 stamps collected"), (1, "1 stamp collected"), (2, "2 stamps collected")])
    func theCountIsPluralAware(count: Int, expected: String) {
        #expect(String(localized: "onboarding.ready.count \(count)") == expected)
        #expect(content(stamp: nil).stampCount == 0 && content().stampCount == 1)
    }

    @Test func theFirstStampNeverCarriesAVerificationWord() {
        let texts = content(verification: .enabled, authorization: .authorized).rows.map(\.text) + [content().subtitle, content().postmarkTop]
        #expect(!texts.dropLast(2).prefix(2).contains { $0.localizedCaseInsensitiveContains("verified") })
        #expect(!content().postmarkTop.localizedCaseInsensitiveContains("verified") && content().postmarkTop == "PARIS")
    }

    @Test func noRowOrSubtitleMentionsPlusOrPlaceholderJunk() {
        for ready in [content(), content(name: "", stamp: nil)] {
            let all = ready.rows.map(\.text) + [ready.subtitle]
            #expect(!all.contains { $0.localizedCaseInsensitiveContains("plus") || $0.contains("null") || $0.contains("Unknown") })
        }
        #expect(!content(name: "", stamp: nil).subtitle.contains("Alex"))
    }

    // MARK: View model

    @Test func theIssueDateIsSetOnceAndNeverOverwritten() throws {
        let model = makeModel()
        let vm = PassportReadyViewModel(model: model, location: location, now: { now })
        vm.appeared()
        #expect(model.passportIssuedAt == now)
        let first = try repository.load().passportIssuedAt
        #expect(first == now)
        let later = PassportReadyViewModel(model: model, location: location, now: { now.addingTimeInterval(9_999) })
        later.appeared()
        let saved = try repository.load().passportIssuedAt
        #expect(model.passportIssuedAt == now && saved == now)
    }

    @Test func theHeroStartsClosedAutoOpensAndTapsToggle() {
        let vm = PassportReadyViewModel(model: makeModel(), location: location)
        #expect(!vm.isOpen)
        vm.autoOpen()
        #expect(vm.isOpen)
        vm.autoOpen()
        #expect(vm.toggleCount == 1, "a second auto-open does nothing")
        vm.toggle()
        #expect(!vm.isOpen)
        vm.toggle()
        #expect(vm.isOpen)
    }

    @Test func tenRapidTapsEndInOneConsistentState() {
        let vm = PassportReadyViewModel(model: makeModel(), location: location)
        for _ in 0..<10 { vm.toggle() }
        #expect(!vm.isOpen && vm.toggleCount == 10)
        vm.toggle()
        #expect(vm.isOpen)
    }

    @Test func continueFinishesWhenPlusIsOffAndGoesToPlusWhenOn() {
        let off = makeModel()
        PassportReadyViewModel(model: off, location: location).continueTapped()
        #expect(off.isComplete && off.path.isEmpty)
        let on = OnboardingModel(repository: InMemoryOnboardingRepository(), collector: StubCollector(), purchases: MockPurchaseService(),
                                 flags: FeatureFlags(plusPaywallEnabled: true), complete: { _ in })
        PassportReadyViewModel(model: on, location: location).continueTapped()
        #expect(!on.isComplete && on.path == [.plus])
    }

    @Test func backWritesNothingAndTheScreenOnlyWritesTheIssueDate() throws {
        let model = makeModel()
        model.setInterests([.coasts])
        model.commitCover(.forest, name: "Sam")
        let before = try repository.load()
        let vm = PassportReadyViewModel(model: model, location: location, now: { now })
        vm.appeared()
        var expected = before
        expected.passportIssuedAt = now
        #expect(try repository.load() == expected)
        model.back()
        #expect(try repository.load() == expected)
        #expect(location.promptCount == 0 && location.readingRequests == 0, "only a read of the authorization status")
    }

    @Test func theRouteComesAfterCoverAndBeforePlus() {
        #expect(OnboardingRoute.cover.next(plusEnabled: false) == .passportReady)
        #expect(OnboardingRoute.passportReady.next(plusEnabled: false) == nil)
        #expect(OnboardingRoute.passportReady.next(plusEnabled: true) == .plus)
        #expect(OnboardingRoute.flow(plusEnabled: true) == [.interests, .firstStamp, .verification, .cover, .passportReady, .plus])
        #expect(OnboardingRoute.passportReady.progressStep == 5 && !OnboardingRoute.passportReady.hasSkip)
    }

    // MARK: Content

    @Test func theHeadlineMarksReadyAndKeepsTheFullStopTight() throws {
        let markup = String(localized: "onboarding.ready.title")
        let tokens = try #require(HeadlineMarkup.parse(markdown: markup))
        #expect(tokens.map(\.text) == ["Your", "passport", "is", "ready", "."] && tokens[3].kind == .highlight(0) && !tokens[4].spaceBefore)
        #expect(tokens[2].lineBreakBefore && HeadlineMarkup.plainText(markup) == "Your passport is ready.")
        #expect(tokens.indices.map { ReadyTimeline.beat(forTokenAt: $0, in: tokens) } == [.firstLine, .firstLine, .isWord, .ready, .stop])
    }

    @Test func theEntranceAndAutoOpenFollowTheSpecifiedOrder() {
        let timeline = ReadyTimeline.standard
        let open = ReadyTimeline.openTime
        let expected: [(ReadyTimeline.Beat, Double)] = [
            (.back, 0.05), (.progress, 0.10), (.firstLine, 0.20), (.isWord, 0.40), (.ready, 0.62), (.stop, 0.95), (.subtitle, 1.00),
            (.cover, 1.05), (.caption, 2.00), (.cta, 2.40), (.open, open), (.emblem, open + 0.55), (.name, open + 0.66), (.count, open + 0.80),
            (.slot(1), open + 0.91), (.slot(5), open + 1.15), (.stamp, open + 1.00), (.footer, open + 1.20), (.postmark, open + 1.40),
            (.icon(0), open + 1.30), (.icon(2), open + 1.62), (.label(1), open + 1.52),
        ]
        for (beat, delay) in expected { #expect(abs(timeline.delay(of: beat) - delay) < 0.0001, "\(beat)") }
        #expect(open == 2.35)
    }

    @Test func everyStringTheScreenUsesIsInTheCatalog() {
        let keys = ["onboarding.ready.title", "onboarding.ready.subtitle %@", "onboarding.ready.subtitle.noName", "onboarding.ready.subtitle.noStamp",
                    "onboarding.ready.caption", "onboarding.ready.holder", "onboarding.ready.name.placeholder", "onboarding.ready.issued %@",
                    "onboarding.ready.page", "onboarding.ready.cta", "onboarding.ready.row.cover %@", "onboarding.ready.row.cover.name %@",
                    "onboarding.ready.row.stamp.today %@", "onboarding.ready.row.stamp.date %@ %@", "onboarding.ready.row.stamp.none",
                    "onboarding.ready.row.verified.on", "onboarding.ready.row.verified.off", "onboarding.ready.a11y.progress",
                    "onboarding.ready.a11y.value.open", "onboarding.ready.a11y.value.closed", "onboarding.ready.a11y.hint.close",
                    "onboarding.ready.a11y.hint.open", "onboarding.ready.a11y.slot %@", "onboarding.ready.a11y.closed %@",
                    "onboarding.ready.a11y.closed.name %@ %@", "onboarding.ready.a11y.announce.open", "onboarding.ready.a11y.announce.closed",
                    "onboarding.ready.a11y.done %@", "onboarding.ready.a11y.off %@", "onboarding.ready.count %lld", "onboarding.ready.a11y.open %@ %lld"]
        for key in keys {
            let value = Bundle.main.localizedString(forKey: key, value: "MISSING", table: nil)
            #expect(value != "MISSING" && !value.isEmpty, "\(key)")
        }
    }

    @Test(arguments: [UIUserInterfaceStyle.light, .dark])
    func textMeetsFourPointFiveOnThePaperAndTheBackground(style: UIUserInterfaceStyle) {
        let paper = ColorKit.resolved("passportPaper", style), background = ColorKit.resolved("onbBackground", style)
        #expect(ColorKit.ratio(ColorKit.resolved("inkPrimary", style), paper) >= 12.5)
        #expect(ColorKit.ratio(ColorKit.resolved("inkSecondary", style), paper) >= 6.0)
        #expect(ColorKit.ratio(ColorKit.resolved("inkSecondary", style), background) >= 6.0)
        #expect(ColorKit.ratio(ColorKit.resolved("inkPrimary", style), background) >= 14.5)
        #expect(ColorKit.ratio(ColorKit.resolved("ctaLabel", style), ColorKit.resolved("ctaFill", style)) >= 4.5)
    }
}
