import Testing
import Foundation
import UIKit
@testable import StampQuest

/// Regression tests for the onboarding fix pass (F3, F4, F6, F7).
@MainActor
struct OnboardingFixPassTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
    let now = Date(timeIntervalSince1970: 1_792_972_800 + 12 * 3_600)
    let locale = Locale(identifier: "en_US")

    func content(name: String, collected: Bool, verification: VerificationChoice, authorization: LocationAuthorization,
                 cover: CoverStyle = .harbor, entitled: Bool = true, on date: Date? = nil) -> ReadyContent {
        ReadyContent(holderName: name, cover: cover, isEntitled: entitled, firstStamp: collected ? (.paris, date ?? now) : nil,
                     verification: verification, authorization: authorization, issuedAt: now, now: now, calendar: calendar, locale: locale)
    }

    // MARK: F3

    @Test(arguments: ["", "   ", "\t \n"])
    func f3_anEmptyOrBlankNameIsNilSoTheWritingLineShows(name: String) {
        #expect(content(name: name, collected: true, verification: .undecided, authorization: .notDetermined).holderName == nil)
    }

    @Test func f3_aNormalAndALongNameArePrinted() {
        #expect(content(name: "Alex Rivera", collected: true, verification: .undecided, authorization: .notDetermined).holderName == "Alex Rivera")
        let long = String(repeating: "Wolfeschlegelstein ", count: 3)
        #expect((content(name: long, collected: true, verification: .undecided, authorization: .notDetermined).holderName?.count ?? 99) <= CoverMetrics.nameLimit)
    }

    // MARK: F4

    nonisolated static let combos: [[Int]] = (0..<12).map { [$0 % 2, ($0 / 2) % 3, $0 / 6] }

    /// {stamp collected or skipped} x {verified on, off, denied} x {name, no name}.
    @Test(arguments: combos)
    func f4_rowsAndSubtitleAreComputedFromState(parts: [Int]) {
        let collected = parts[0] == 0
        let (verification, authorization): (VerificationChoice, LocationAuthorization) = switch parts[1] {
        case 0: (.enabled, .authorized)
        case 1: (.skipped, .notDetermined)
        default: (.enabled, .denied)
        }
        let name = parts[2] == 0 ? "Alex Rivera" : ""
        let result = content(name: name, collected: collected, verification: verification, authorization: authorization)
        #expect(result.rows[0].status == .done && result.rows[0].text.hasPrefix("Harbor cover"))
        #expect(result.rows[0].text.contains("with your name") == !name.isEmpty)
        if collected {
            #expect(result.rows[1] == ReadyContent.Row(status: .done, text: "Paris stamp, collected today"))
            #expect(result.subtitle == (name.isEmpty ? "Your first stamp is already inside." : "Alex, your first stamp is already inside."))
        } else {
            #expect(result.rows[1] == ReadyContent.Row(status: .off, text: "No stamp yet"))
            #expect(result.subtitle == "Add your first stamp whenever you like.")
        }
        #expect(result.rows[2] == (parts[1] == 0 ? ReadyContent.Row(status: .done, text: "Verified stamps are on")
                                                  : ReadyContent.Row(status: .off, text: "Verified stamps are off")))
    }

    @Test func f4_collectedTodayIsOnlyWordedTodayWhenItIsToday() {
        let earlier = now.addingTimeInterval(-3 * 86_400)
        let result = content(name: "", collected: true, verification: .undecided, authorization: .notDetermined, on: earlier)
        #expect(result.rows[1].text == "Paris stamp, collected Oct 23, 2026")
    }

    @Test func f4_aPlusCoverWithoutPlusSaysPreview() {
        let result = content(name: "Alex", collected: true, verification: .undecided, authorization: .notDetermined, cover: .midnight, entitled: false)
        #expect(result.rows[0].text == "Terracotta cover, Midnight is a Plus preview")
        let owned = content(name: "Alex", collected: true, verification: .undecided, authorization: .notDetermined, cover: .midnight, entitled: true)
        #expect(owned.rows[0].text == "Midnight cover, with your name")
    }

    // MARK: F6

    @Test func f6_thePostmarkClearsTheNumberLabelByTenPointsUpAndRight() {
        #expect(StampPostmark.labelClearance == CGSize(width: 10, height: -10))
    }

    // MARK: F7

    @Test(arguments: ["en_GB", "en_LK", "si_LK", "ta_LK", "en_US", "de_DE", "fr_FR"])
    func f7_oneFormatterIsLocaleAwareAndThePostmarkStaysShort(identifier: String) {
        let locale = Locale(identifier: identifier)
        let date = Date(timeIntervalSince1970: 1_793_534_400) // 1 Nov 2026
        let postmark = OnboardingFormat.stampDate(date, locale: locale, calendar: calendar)
        #expect(postmark.count <= 13 && !postmark.isEmpty, "\(identifier): \(postmark) must fit the ring")
        #expect(OnboardingFormat.date(date, .dayMonth, locale: locale, calendar: calendar).contains("1") || identifier.hasSuffix("LK"))
    }

    @Test func f7_dayFirstWhereTheRegionPutsItFirst() {
        let date = Date(timeIntervalSince1970: 1_793_534_400)
        #expect(OnboardingFormat.date(date, .dayMonth, locale: Locale(identifier: "en_GB"), calendar: calendar) == "1 Nov")
        #expect(OnboardingFormat.date(date, .dayMonthYear, locale: Locale(identifier: "en_GB"), calendar: calendar) == "1 Nov 2026")
        #expect(OnboardingFormat.date(date, .dayMonth, locale: Locale(identifier: "en_US"), calendar: calendar) == "Nov 1")
    }

    @Test func f7_plusAndReadyUseTheSameFormatter() {
        let plus = PlusContent(products: FakeSubscriptionClient.standardProducts(), selected: .yearly, canRemind: true, now: now, calendar: calendar,
                               locale: Locale(identifier: "en_GB"))
        let end = OnboardingFormat.date(now.addingTimeInterval(7 * 86_400), .dayMonth, locale: Locale(identifier: "en_GB"), calendar: calendar)
        #expect(plus.steps.last?.title == end)
    }
}
