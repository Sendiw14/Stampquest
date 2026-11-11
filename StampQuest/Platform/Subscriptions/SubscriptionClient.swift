import Foundation

/// Product identifiers of the Plus subscription group. PLACEHOLDERS: the owner sets the real ones in App Store Connect and here.
nonisolated enum PlusProductID {
    static let yearly = "com.stampquest.plus.yearly"
    static let monthly = "com.stampquest.plus.monthly"
    static let all = [yearly, monthly]
}

nonisolated enum PlusPlanKind: String, CaseIterable, Sendable { case yearly, monthly }

nonisolated enum PeriodUnit: Sendable { case day, week, month, year }

nonisolated struct SubscriptionPeriod: Equatable, Sendable {
    var unit: PeriodUnit
    var value: Int

    /// The date one period after `date`.
    func advance(_ date: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component = switch unit {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }
}

/// A plan as the store reports it. Nothing here is typed in by hand at run time: price, period, trial and eligibility all
/// come from StoreKit (or a fake with the same shape).
nonisolated struct PlusProduct: Equatable, Identifiable, Sendable {
    var id: String
    var kind: PlusPlanKind
    /// The localised price, as the product formats it ("$29.99").
    var displayPrice: String
    var price: Decimal
    var currencyCode: String
    /// The locale of the product's price format, so derived prices (per month) format the same way.
    var locale: Locale
    var period: SubscriptionPeriod
    /// A free-trial introductory offer on this product, if it has one.
    var introOffer: SubscriptionPeriod?
    /// Whether this person may still use the introductory offer (the whole subscription group is considered).
    var isEligibleForIntro: Bool

    /// The trial that applies to this person, if any.
    var eligibleTrial: SubscriptionPeriod? { isEligibleForIntro ? introOffer : nil }

    /// `value` in this product's currency and locale, e.g. the per-month price of a yearly plan.
    func format(_ value: Decimal) -> String { value.formatted(.currency(code: currencyCode).locale(locale)) }
}

/// Used while the paywall flag is off: nothing can be loaded or bought and nobody is entitled.
@MainActor
final class UnavailableSubscriptionClient: SubscriptionClient {
    func loadProducts() async throws -> [PlusProduct] { throw PurchaseError.unavailable }
    func purchase(_ product: PlusProduct) async throws -> PurchaseOutcome { throw PurchaseError.unavailable }
    func isEntitled() async -> Bool { false }
    func restore() async throws -> Bool { throw PurchaseError.unavailable }
    func updates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

/// Everything the paywall needs from the store, behind one seam so the screen can run on a deterministic fake.
@MainActor
protocol SubscriptionClient: AnyObject {
    /// The plans with intro-offer eligibility resolved. Throws `PurchaseError.unavailable` when none can be loaded.
    func loadProducts() async throws -> [PlusProduct]
    /// Throws `PurchaseError.failed` for an error or an unverified transaction.
    func purchase(_ product: PlusProduct) async throws -> PurchaseOutcome
    /// Whether any Plus subscription is currently active.
    func isEntitled() async -> Bool
    /// Syncs with the App Store, then reports the entitlement. Throws `PurchaseError.unavailable` when the sync fails.
    func restore() async throws -> Bool
    /// Fires when a transaction update (a pending purchase approved, a renewal, a refund) may have changed the entitlement.
    func updates() -> AsyncStream<Void>
}
