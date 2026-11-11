import Foundation
import StoreKit
import OSLog

/// StoreKit 2 implementation. Entitlement is read from `Transaction.currentEntitlements`, never stored. A `Transaction.updates`
/// listener runs from creation, finishes verified transactions and wakes the paywall.
@MainActor
final class StoreKitSubscriptionClient: SubscriptionClient {
    private var products: [String: Product] = [:]
    private var listeners: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var updatesTask: Task<Void, Never>?
    private let log = Logger(subsystem: "app.stampquest.ios", category: "subscriptions")

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update { await transaction.finish() }
                self.listeners.values.forEach { $0.yield() }
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async throws -> [PlusProduct] {
        let loaded: [Product]
        do { loaded = try await Product.products(for: PlusProductID.all) } catch {
            log.error("Could not load plans: \(String(describing: type(of: error)), privacy: .public)")
            throw PurchaseError.unavailable
        }
        var plans: [PlusProduct] = []
        for product in loaded {
            guard let subscription = product.subscription, let kind = Self.kind(of: product.id) else { continue }
            products[product.id] = product
            let offer = subscription.introductoryOffer.flatMap { $0.paymentMode == .freeTrial ? Self.period($0.period) : nil }
            let eligible = await Product.SubscriptionInfo.isEligibleForIntroOffer(for: subscription.subscriptionGroupID)
            plans.append(PlusProduct(id: product.id, kind: kind, displayPrice: product.displayPrice, price: product.price,
                                     currencyCode: product.priceFormatStyle.currencyCode, locale: product.priceFormatStyle.locale,
                                     period: Self.period(subscription.subscriptionPeriod), introOffer: offer,
                                     isEligibleForIntro: eligible && offer != nil))
        }
        guard !plans.isEmpty else { throw PurchaseError.unavailable }
        return plans
    }

    func purchase(_ product: PlusProduct) async throws -> PurchaseOutcome {
        guard let storeProduct = products[product.id] else { throw PurchaseError.unavailable }
        let result: Product.PurchaseResult
        do { result = try await storeProduct.purchase() } catch {
            log.error("Purchase failed: \(String(describing: type(of: error)), privacy: .public)")
            throw PurchaseError.failed
        }
        switch result {
        case .success(.verified(let transaction)):
            await transaction.finish()
            return .purchased
        case .success(.unverified): throw PurchaseError.failed
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: throw PurchaseError.failed
        }
    }

    func isEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  PlusProductID.all.contains(transaction.productID) else { continue }
            return true
        }
        return false
    }

    func restore() async throws -> Bool {
        do { try await AppStore.sync() } catch {
            log.error("Restore failed: \(String(describing: type(of: error)), privacy: .public)")
            throw PurchaseError.unavailable
        }
        return await isEntitled()
    }

    func updates() -> AsyncStream<Void> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in Task { @MainActor in self?.listeners[id] = nil } }
        return stream
    }

    private static func kind(of id: String) -> PlusPlanKind? {
        switch id {
        case PlusProductID.yearly: .yearly
        case PlusProductID.monthly: .monthly
        default: nil
        }
    }

    private static func period(_ period: Product.SubscriptionPeriod) -> SubscriptionPeriod {
        let unit: PeriodUnit = switch period.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: .day
        }
        return SubscriptionPeriod(unit: unit, value: period.value)
    }
}
