import Foundation

/// Plus entitlement and purchases. The StoreKit 2 implementation belongs to onboarding prompts 07 and 07b and is
/// not built yet: until then the app uses `UnavailablePurchaseService`, and the paywall flag stays off.
@MainActor
protocol PurchaseService {
    var isPlusEntitled: Bool { get }
    /// Throws `PurchaseError.unavailable` when purchases are not offered.
    func purchase(productID: String) async throws -> PurchaseOutcome
}

nonisolated enum PurchaseOutcome: Equatable, Sendable { case purchased, cancelled, pending }

nonisolated enum PurchaseError: Error, Equatable { case unavailable, failed }

/// Used while the paywall flag is off: nobody is entitled and nothing can be bought.
@MainActor
struct UnavailablePurchaseService: PurchaseService {
    var isPlusEntitled: Bool { false }
    func purchase(productID: String) async throws -> PurchaseOutcome { throw PurchaseError.unavailable }
}

/// Deterministic stand-in for previews and tests.
@MainActor
final class MockPurchaseService: PurchaseService {
    var isPlusEntitled: Bool
    var nextOutcome: Result<PurchaseOutcome, PurchaseError>
    private(set) var purchasedProductIDs: [String] = []

    init(isPlusEntitled: Bool = false, nextOutcome: Result<PurchaseOutcome, PurchaseError> = .success(.purchased)) {
        self.isPlusEntitled = isPlusEntitled
        self.nextOutcome = nextOutcome
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        let outcome = try nextOutcome.get()
        purchasedProductIDs.append(productID)
        if outcome == .purchased { isPlusEntitled = true }
        return outcome
    }
}
