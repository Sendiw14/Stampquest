import Foundation

/// Deterministic stand-in for previews, unit tests and UI tests (a DEBUG launch argument selects a scenario). It talks to nobody.
@MainActor
final class FakeSubscriptionClient: SubscriptionClient {
    var products: [PlusProduct]
    var loadError: PurchaseError?
    var purchaseResult: Result<PurchaseOutcome, PurchaseError> = .success(.purchased)
    var entitled: Bool
    /// What `restore()` finds; `nil` throws.
    var restoreResult: Bool?
    /// When set, `purchase` waits this long first, so a test can tap twice while a purchase is in flight.
    var purchaseDelay: Duration?

    private(set) var purchasedIDs: [String] = []
    private(set) var loadCount = 0
    private(set) var restoreCount = 0
    private var listeners: [UUID: AsyncStream<Void>.Continuation] = [:]

    init(products: [PlusProduct] = FakeSubscriptionClient.standardProducts(), entitled: Bool = false, restoreResult: Bool? = false) {
        self.products = products
        self.entitled = entitled
        self.restoreResult = restoreResult
    }

    func loadProducts() async throws -> [PlusProduct] {
        loadCount += 1
        if let loadError { throw loadError }
        return products
    }

    func purchase(_ product: PlusProduct) async throws -> PurchaseOutcome {
        if let purchaseDelay { try? await Task.sleep(for: purchaseDelay) }
        let outcome = try purchaseResult.get()
        purchasedIDs.append(product.id)
        if outcome == .purchased { entitled = true }
        return outcome
    }

    func isEntitled() async -> Bool { entitled }

    func restore() async throws -> Bool {
        restoreCount += 1
        guard let restoreResult else { throw PurchaseError.unavailable }
        if restoreResult { entitled = true }
        return restoreResult
    }

    func updates() -> AsyncStream<Void> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in Task { @MainActor in self?.listeners[id] = nil } }
        return stream
    }

    /// Simulates a `Transaction.updates` delivery.
    func emitUpdate() { listeners.values.forEach { $0.yield() } }
}

extension FakeSubscriptionClient {
    /// A named UI-test scenario (`-uitest-subscriptions <name>`): ok, unavailable, restore-found, entitled, pending, fail, slow.
    static func scenario(_ name: String) -> FakeSubscriptionClient {
        let client = FakeSubscriptionClient()
        switch name {
        case "unavailable": client.loadError = .unavailable
        case "restore-found": client.restoreResult = true
        case "entitled": client.entitled = true
        case "pending": client.purchaseResult = .success(.pending)
        case "fail": client.purchaseResult = .failure(.failed)
        case "slow": client.purchaseDelay = .seconds(2)
        case "no-trial": client.products = standardProducts(eligible: false)
        default: break
        }
        return client
    }

    /// Yearly (with a trial) and monthly (without), USD, en_US.
    static func standardProducts(yearly: Decimal = 29.99, monthly: Decimal = 4.99, trialDays: Int? = 7, eligible: Bool = true,
                                 currencyCode: String = "USD", locale: Locale = Locale(identifier: "en_US")) -> [PlusProduct] {
        func product(_ kind: PlusPlanKind, _ price: Decimal, _ period: SubscriptionPeriod, trial: Int?) -> PlusProduct {
            PlusProduct(id: kind == .yearly ? PlusProductID.yearly : PlusProductID.monthly, kind: kind,
                        displayPrice: price.formatted(.currency(code: currencyCode).locale(locale)), price: price,
                        currencyCode: currencyCode, locale: locale, period: period,
                        introOffer: trial.map { SubscriptionPeriod(unit: .day, value: $0) }, isEligibleForIntro: eligible && trial != nil)
        }
        return [product(.yearly, yearly, SubscriptionPeriod(unit: .year, value: 1), trial: trialDays),
                product(.monthly, monthly, SubscriptionPeriod(unit: .month, value: 1), trial: nil)]
    }
}
