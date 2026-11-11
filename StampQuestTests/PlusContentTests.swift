import Testing
import Foundation
@testable import StampQuest

@MainActor
struct PlusContentTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
    let locale = Locale(identifier: "en_US")
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)) ?? .now }

    func content(_ products: [PlusProduct], _ kind: PlusPlanKind, remind: Bool = true) -> PlusContent {
        PlusContent(products: products, selected: kind, canRemind: remind, now: now, calendar: calendar, locale: locale)
    }

    func products(eligible: Bool = true, trialDays: Int? = 7, monthlyTrial: Bool = false) -> [PlusProduct] {
        var list = FakeSubscriptionClient.standardProducts(trialDays: trialDays, eligible: eligible)
        if monthlyTrial {
            list[1].introOffer = SubscriptionPeriod(unit: .day, value: 7)
            list[1].isEligibleForIntro = eligible
        }
        return list
    }

    // MARK: Matrix

    nonisolated static let matrix: [[Bool]] = (0..<8).map { [$0 & 1 == 0, $0 & 2 == 0, $0 & 4 == 0] }

    @Test(arguments: matrix)
    func ctaTimelineAndFinePrintFollowEligibilityAndNotifications(flags: [Bool]) {
        let (kind, eligible, remind) = (flags[0] ? PlusPlanKind.yearly : .monthly, flags[1], flags[2])
        let result = content(products(eligible: eligible, monthlyTrial: true), kind, remind: remind)
        let price = kind == .yearly ? "$29.99" : "$4.99"
        let noun = kind == .yearly ? "year" : "month"
        if eligible {
            #expect(result.hasTrial && result.ctaTitle == "Start 7-day free trial")
            #expect(result.finePrint == ["Free for 7 days, then \(price) per \(noun).", "No payment due today. Cancel anytime in Settings."])
            #expect(result.steps.map(\.caption) == (remind ? ["Full access", "We remind you", "Plan begins"] : ["Full access", "Plan begins"]))
            #expect(result.steps.map(\.title) == (remind ? ["Today", "Nov 6", "Nov 8"] : ["Today", "Nov 8"]))
        } else {
            #expect(!result.hasTrial && result.ctaTitle == "Subscribe for \(price) per \(noun)")
            #expect(result.finePrint == ["Billed \(price) per \(noun), starting today.", "Cancel anytime in Settings."])
            #expect(result.steps.count == 2 && result.steps[0].caption == "Billed \(price)")
            #expect(result.steps[1].caption == (kind == .yearly ? "Renews yearly" : "Renews monthly"))
        }
    }

    @Test func aPlanWithoutATrialNeverClaimsOne() {
        let result = content(products(), .monthly)
        let text = ([result.ctaTitle] + result.finePrint + result.steps.flatMap { [$0.title, $0.caption] }).joined(separator: " ")
        #expect(!result.hasTrial && !text.localizedCaseInsensitiveContains("free") && !text.contains("No payment due"))
        #expect(!text.contains("We remind you"))
    }

    @Test func theTrialLengthComesFromTheStoreNotTheCode() {
        #expect(content(products(trialDays: 14), .yearly).ctaTitle == "Start 14-day free trial")
        var weekly = products()
        weekly[0].introOffer = SubscriptionPeriod(unit: .week, value: 1)
        #expect(content(weekly, .yearly).ctaTitle == "Start 7-day free trial")
        weekly[0].introOffer = SubscriptionPeriod(unit: .month, value: 1)
        #expect(content(weekly, .yearly).ctaTitle == "Start 30-day free trial", "1 Nov + 1 month = 1 Dec")
    }

    @Test func noTimelineStepIsEverCountedFromAnIneligibleTrial() {
        #expect(content(products(eligible: false), .yearly).steps.map(\.caption).contains("We remind you") == false)
    }

    // MARK: Save percent and per month

    @Test func savePercentIsFiftyForTheStandardPrices() {
        #expect(PlusPricing.savePercent(yearly: products()[0], monthly: products()[1]) == 50)
        #expect(content(products(), .yearly).saveBadge == "Save 50%")
    }

    @Test(arguments: [(Decimal(string: "54") ?? 54, 5, true), (55, 5, false), (59.88, 4.99, false), (29.99, 4.99, true)])
    func theBadgeNeedsAtLeastTenPercent(yearly: Decimal, monthly: Decimal, shown: Bool) {
        let list = FakeSubscriptionClient.standardProducts(yearly: yearly, monthly: monthly)
        #expect((PlusPricing.savePercent(yearly: list[0], monthly: list[1]) != nil) == shown)
    }

    @Test func theBadgeIsHiddenForAMissingPriceOrMixedCurrencies() {
        let list = products()
        #expect(PlusPricing.savePercent(yearly: list[0], monthly: nil) == nil)
        #expect(PlusPricing.savePercent(yearly: nil, monthly: list[1]) == nil)
        var mixed = list
        mixed[1].currencyCode = "EUR"
        #expect(PlusPricing.savePercent(yearly: mixed[0], monthly: mixed[1]) == nil)
        #expect(content([list[0]], .yearly).saveBadge == nil)
    }

    @Test func perMonthIsTheYearlyPriceOverTwelveInTheProductsFormat() {
        #expect(PlusPricing.perMonth(products()[0]) == "$2.50")
        #expect(content(products(), .yearly).plans[0].subline == "$2.50 per month")
        #expect(content(products(), .yearly).plans[1].subline == "Billed monthly")
    }

    @Test func zeroDecimalCurrenciesStaySensible() {
        let yen = FakeSubscriptionClient.standardProducts(yearly: 3190, monthly: 480, currencyCode: "JPY")
        #expect(PlusPricing.perMonth(yen[0]) == "¥266")
        #expect(PlusPricing.savePercent(yearly: yen[0], monthly: yen[1]) == 45)
    }

    // MARK: Dates

    @Test func theReminderIsTenAMTwoDaysBeforeTheTrialEnds() throws {
        let plan = try #require(PlusContent.reminder(for: products()[0], start: now, calendar: calendar))
        #expect(plan.date == calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 10)))
        #expect(plan.title == "Your Plus trial ends in 2 days" && plan.body == "Cancel anytime in Settings.")
    }

    @Test(arguments: [(3, false), (4, true), (5, true), (7, true)])
    func trialsUnderFourDaysGetNoReminder(days: Int, reminds: Bool) {
        let list = products(trialDays: days)
        #expect((PlusContent.reminder(for: list[0], start: now, calendar: calendar) != nil) == reminds)
        #expect(content(list, .yearly).steps.count == (reminds ? 3 : 2))
    }

    @Test func planBeginsIsTheStartPlusTheTrialAndRenewalIsOnePeriodOn() {
        #expect(content(products(), .yearly).steps.last?.title == "Nov 8")
        #expect(content(products(eligible: false), .yearly).steps.last?.title == "Nov 1", "2027")
        #expect(content(products(eligible: false), .monthly).steps.last?.title == "Dec 1")
    }

    @Test func noReminderWithoutATrialTheUserCanUse() {
        #expect(PlusContent.reminder(for: products(eligible: false)[0], start: now, calendar: calendar) == nil)
        #expect(PlusContent.reminder(for: products()[1], start: now, calendar: calendar) == nil)
    }

    // MARK: Plans and perks

    @Test func accessibilityLabelsReadPriceAndSaving() {
        #expect(content(products(), .yearly).plans[0].accessibilityLabel == "Yearly, $29.99 per year, $2.50 per month, save 50 percent.")
        #expect(content(products(), .yearly).plans[1].accessibilityLabel == "Monthly, $4.99 per month.")
    }

    @Test func perkRowsPutALoneLastTileOnItsOwn() {
        #expect(PlusMetrics.perkRows(count: 2) == [[0, 1]])
        #expect(PlusMetrics.perkRows(count: 3) == [[0, 1], [2]])
        #expect(PlusMetrics.perkRows(count: 4) == [[0, 1], [2, 3]])
        #expect(PlusMetrics.perkRows(count: 4, columns: 1) == [[0], [1], [2], [3]])
        #expect(PlusPerk.available(hiding: [.sync]).count == 3 && PlusPerk.available(hiding: [.sync, .layouts]).count == 2)
        #expect(PlusPerk.available().count == 4)
    }

    @Test func heroScaleCompressesGapsBeforeShrinkingAndNeverBelowTheMinimum() {
        #expect(PlusMetrics.scales(forHeight: 874).hero == 1 && PlusMetrics.scales(forHeight: 874).gap == 1)
        #expect(PlusMetrics.scales(forHeight: 667).hero >= PlusMetrics.minHeroScale)
        #expect(PlusMetrics.scales(forHeight: 300) == (gap: 0.5, hero: PlusMetrics.minHeroScale))
    }
}
