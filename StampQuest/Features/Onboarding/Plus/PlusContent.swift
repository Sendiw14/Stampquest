import Foundation

/// Perks shown as tiles. A perk is listed only while `isAvailable`: hide one by adding it to `unavailable` the moment it is not real.
enum PlusPerk: CaseIterable, Hashable, Sendable {
    case collections, covers, layouts, sync

    /// Perks that are not shipped and must not be promised. None are hidden today; see the hand-over note about layouts and sync.
    static let unavailable: Set<PlusPerk> = []

    var isAvailable: Bool { !Self.unavailable.contains(self) }

    static func available(hiding hidden: Set<PlusPerk> = unavailable) -> [PlusPerk] { allCases.filter { !hidden.contains($0) } }

    var titleKey: String {
        switch self {
        case .collections: "onboarding.plus.perk.collections"
        case .covers: "onboarding.plus.perk.covers"
        case .layouts: "onboarding.plus.perk.layouts"
        case .sync: "onboarding.plus.perk.sync"
        }
    }

    var symbol: String {
        switch self {
        case .collections: "seal"
        case .covers: "book.closed"
        case .layouts: "square.grid.2x2"
        case .sync: "cloud"
        }
    }
}

/// Plan arithmetic. Pure.
nonisolated enum PlusPricing {
    /// Save percent of the yearly plan against twelve monthly payments, rounded; nil when below 10%, when a plan is missing or when
    /// the plans are not one year against one month in the same currency.
    static func savePercent(yearly: PlusProduct?, monthly: PlusProduct?) -> Int? {
        guard let yearly, let monthly, yearly.currencyCode == monthly.currencyCode, monthly.price > 0, yearly.price > 0,
              yearly.period == SubscriptionPeriod(unit: .year, value: 1), monthly.period == SubscriptionPeriod(unit: .month, value: 1)
        else { return nil }
        let ratio = NSDecimalNumber(decimal: yearly.price / (monthly.price * 12)).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded())
        return percent >= 10 ? percent : nil
    }

    /// The yearly price spread over twelve months, in the product's own format.
    static func perMonth(_ yearly: PlusProduct) -> String { yearly.format(yearly.price / 12) }
}

/// What the paywall says, for the plans StoreKit returned. Trial claims appear only for a plan whose trial this person is eligible
/// for; the "We remind you" step only when a reminder will really be scheduled. Dates come from the injected `now`. Pure.
struct PlusContent: Equatable {
    struct Plan: Equatable, Identifiable {
        let kind: PlusPlanKind
        let title: String
        let price: String
        /// "per year"
        let perPeriod: String
        /// "$2.50 per month" or "Billed monthly".
        let subline: String?
        let accessibilityLabel: String
        var id: PlusPlanKind { kind }
    }

    struct Step: Equatable {
        enum Icon: Equatable { case star, bell, card }
        let icon: Icon
        let title: String
        let caption: String
    }

    enum Success: Equatable { case trial, subscribed, restored }

    struct ReminderPlan: Equatable {
        let date: Date
        let title: String
        let body: String
    }

    static let reminderID = "plus.trial.reminder"
    static let reminderLeadDays = 2
    static let minimumTrialDaysForReminder = 4

    let plans: [Plan]
    /// "Save 50%" on the yearly card.
    let saveBadge: String?
    let selected: PlusPlanKind
    let ctaTitle: String
    let hasTrial: Bool
    let steps: [Step]
    /// Fine print: the price and period line, then the cancellation line.
    let finePrint: [String]

    init(products: [PlusProduct], selected: PlusPlanKind, canRemind: Bool, now: Date, calendar: Calendar = .current,
         locale: Locale = .current) {
        let yearly = products.first { $0.kind == .yearly }
        let monthly = products.first { $0.kind == .monthly }
        let save = PlusPricing.savePercent(yearly: yearly, monthly: monthly)
        self.selected = selected
        saveBadge = save.map { String(localized: "onboarding.plus.badge.save \($0)") }
        plans = PlusPlanKind.allCases.compactMap { kind in
            products.first { $0.kind == kind }.map { Self.plan($0, save: kind == .yearly ? save : nil) }
        }
        let product = products.first { $0.kind == selected } ?? products.first
        guard let product else {
            ctaTitle = ""; hasTrial = false; steps = []; finePrint = []
            return
        }
        let noun = Self.noun(product.period)
        let trial = product.eligibleTrial
        hasTrial = trial != nil
        func day(_ date: Date) -> String { OnboardingFormat.date(date, .dayMonth, locale: locale, calendar: calendar) }
        let today = String(localized: "onboarding.plus.timeline.today")
        if let trial {
            let end = trial.advance(now, calendar: calendar)
            let days = Self.dayCount(from: now, to: end, calendar: calendar)
            ctaTitle = String(localized: "onboarding.plus.cta.trial \(days)")
            finePrint = [String(localized: "onboarding.plus.finePrint.trial \(days) \(product.displayPrice) \(noun)"),
                         String(localized: "onboarding.plus.finePrint.trial.cancel")]
            var steps = [Step(icon: .star, title: today, caption: String(localized: "onboarding.plus.timeline.fullAccess"))]
            if canRemind, let reminder = Self.reminderDate(trialEnd: end, days: days, calendar: calendar) {
                steps.append(Step(icon: .bell, title: day(reminder), caption: String(localized: "onboarding.plus.timeline.remind")))
            }
            steps.append(Step(icon: .card, title: day(end), caption: String(localized: "onboarding.plus.timeline.begins")))
            self.steps = steps
        } else {
            ctaTitle = String(localized: "onboarding.plus.cta.subscribe \(product.displayPrice) \(noun)")
            finePrint = [String(localized: "onboarding.plus.finePrint.billed \(product.displayPrice) \(noun)"),
                         String(localized: "onboarding.plus.finePrint.billed.cancel")]
            steps = [Step(icon: .star, title: today, caption: String(localized: "onboarding.plus.timeline.billed \(product.displayPrice)")),
                     Step(icon: .card, title: day(product.period.advance(now, calendar: calendar)), caption: Self.renews(product.period))]
        }
    }

    // MARK: Reminder

    /// The one local notification for a trial that is really started: 10:00 local, two days before the trial ends. Nil when the
    /// product has no trial this person can use, or the trial is shorter than four days.
    static func reminder(for product: PlusProduct, start: Date, calendar: Calendar = .current) -> ReminderPlan? {
        guard let trial = product.eligibleTrial else { return nil }
        let end = trial.advance(start, calendar: calendar)
        guard let date = reminderDate(trialEnd: end, days: dayCount(from: start, to: end, calendar: calendar), calendar: calendar)
        else { return nil }
        return ReminderPlan(date: date, title: String(localized: "onboarding.plus.reminder.title"),
                            body: String(localized: "onboarding.plus.reminder.body"))
    }

    static func reminderDate(trialEnd end: Date, days: Int, calendar: Calendar) -> Date? {
        guard days >= minimumTrialDaysForReminder, let lead = calendar.date(byAdding: .day, value: -reminderLeadDays, to: end) else { return nil }
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: lead)
    }

    /// Whole days from `start` to `end`, by calendar day.
    static func dayCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    // MARK: Text

    static func banner(_ success: Success) -> String {
        switch success {
        case .trial: String(localized: "onboarding.plus.banner.trial")
        case .subscribed: String(localized: "onboarding.plus.banner.subscribed")
        case .restored: String(localized: "onboarding.plus.banner.restored")
        }
    }

    /// "year", "3 months"
    static func noun(_ period: SubscriptionPeriod) -> String {
        switch period.unit {
        case .year: String(localized: "onboarding.plus.unit.year \(period.value)")
        case .month: String(localized: "onboarding.plus.unit.month \(period.value)")
        case .week: String(localized: "onboarding.plus.unit.week \(period.value)")
        case .day: String(localized: "onboarding.plus.unit.day \(period.value)")
        }
    }

    private static func renews(_ period: SubscriptionPeriod) -> String {
        guard period.value == 1 else { return String(localized: "onboarding.plus.renews.every \(noun(period))") }
        return switch period.unit {
        case .year: String(localized: "onboarding.plus.renews.year")
        case .month: String(localized: "onboarding.plus.renews.month")
        case .week: String(localized: "onboarding.plus.renews.week")
        case .day: String(localized: "onboarding.plus.renews.day")
        }
    }

    private static func plan(_ product: PlusProduct, save: Int?) -> Plan {
        let title = String(localized: product.kind == .yearly ? "onboarding.plus.plan.yearly" : "onboarding.plus.plan.monthly")
        let noun = noun(product.period)
        var subline: String?
        var parts = ["\(title), \(product.displayPrice) \(String(localized: "onboarding.plus.per \(noun)"))"]
        if product.kind == .yearly, product.period == SubscriptionPeriod(unit: .year, value: 1) {
            let perMonth = PlusPricing.perMonth(product)
            subline = String(localized: "onboarding.plus.perMonth \(perMonth)")
            parts.append(String(localized: "onboarding.plus.perMonth \(perMonth)"))
        } else if product.kind == .monthly, product.period == SubscriptionPeriod(unit: .month, value: 1) {
            subline = String(localized: "onboarding.plus.billedMonthly")
        }
        if let save { parts.append(String(localized: "onboarding.plus.a11y.save \(save)")) }
        return Plan(kind: product.kind, title: title, price: product.displayPrice, perPeriod: String(localized: "onboarding.plus.per \(noun)"),
                    subline: subline, accessibilityLabel: parts.joined(separator: ", ") + ".")
    }
}
