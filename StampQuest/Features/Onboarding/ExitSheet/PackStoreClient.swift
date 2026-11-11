import Foundation
import StoreKit
import OSLog

nonisolated struct PackProduct: Equatable, Sendable {
    let id: Pack.ID
    /// "Coasts"; the sheet writes "Coasts pack".
    let displayName: String
    /// `Product.displayPrice`, never typed in.
    let displayPrice: String
}

nonisolated enum PackPurchaseResult: Equatable, Sendable { case owned, cancelled, pending, failed }

/// Everything the exit sheet needs from the store for one-time packs.
@MainActor
protocol PackStoreClient: AnyObject {
    func product(for id: Pack.ID) async -> PackProduct?
    /// Packs owned right now, from the store's entitlements (so Restore Purchases covers them).
    func ownedIDs() async -> Set<Pack.ID>
    /// `.failed` covers an error and an unverified transaction.
    func purchase(_ product: PackProduct) async -> PackPurchaseResult
    /// Fires with the pack's id when a transaction update makes it owned (an Ask to Buy approval).
    func ownedUpdates() -> AsyncStream<Pack.ID>
}

/// Used while the pack flag is off: nothing is offered.
@MainActor
final class UnavailablePackStoreClient: PackStoreClient {
    func product(for id: Pack.ID) async -> PackProduct? { nil }
    func ownedIDs() async -> Set<Pack.ID> { [] }
    func purchase(_ product: PackProduct) async -> PackPurchaseResult { .failed }
    func ownedUpdates() -> AsyncStream<Pack.ID> { AsyncStream { $0.finish() } }
}

/// StoreKit 2: products, `purchase()` with the verification result checked, entitlements from `Transaction.currentEntitlements`, and a
/// `Transaction.updates` listener that finishes verified transactions after reporting them.
@MainActor
final class StoreKitPackStoreClient: PackStoreClient {
    private var products: [String: Product] = [:]
    private var listeners: [UUID: AsyncStream<Pack.ID>.Continuation] = [:]
    private var updatesTask: Task<Void, Never>?
    private let packIDs: Set<Pack.ID>
    private let log = Logger(subsystem: "app.stampquest.ios", category: "packs")

    init(manifest: [Pack] = PackManifest.all) {
        packIDs = Set(manifest.map(\.id))
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self, case .verified(let transaction) = update, self.packIDs.contains(transaction.productID) else { continue }
                if transaction.revocationDate == nil { self.listeners.values.forEach { $0.yield(transaction.productID) } }
                await transaction.finish()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func product(for id: Pack.ID) async -> PackProduct? {
        guard let product = try? await Product.products(for: [id]).first else { return nil }
        products[id] = product
        return PackProduct(id: id, displayName: product.displayName, displayPrice: product.displayPrice)
    }

    func ownedIDs() async -> Set<Pack.ID> {
        var owned: Set<Pack.ID> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil, packIDs.contains(transaction.productID) {
                owned.insert(transaction.productID)
            }
        }
        return owned
    }

    func purchase(_ product: PackProduct) async -> PackPurchaseResult {
        guard let storeProduct = products[product.id] else { return .failed }
        do {
            switch try await storeProduct.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                return .owned
            case .success(.unverified): return .failed
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .failed
            }
        } catch {
            log.error("Pack purchase failed: \(String(describing: type(of: error)), privacy: .public)")
            return .failed
        }
    }

    func ownedUpdates() -> AsyncStream<Pack.ID> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Pack.ID>.makeStream()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in Task { @MainActor in self?.listeners[id] = nil } }
        return stream
    }
}

/// Deterministic stand-in for previews, unit tests and UI tests (`-uitest-packs <scenario>`).
@MainActor
final class FakePackStoreClient: PackStoreClient {
    var products: [Pack.ID: PackProduct]
    var owned: Set<Pack.ID>
    var result: PackPurchaseResult = .owned
    var delay: Duration?
    private(set) var purchases: [Pack.ID] = []
    private var listeners: [UUID: AsyncStream<Pack.ID>.Continuation] = [:]

    init(products: [Pack.ID: PackProduct] = FakePackStoreClient.standard, owned: Set<Pack.ID> = []) {
        self.products = products
        self.owned = owned
    }

    static let standard = [PackProductID.coasts: PackProduct(id: PackProductID.coasts, displayName: "Coasts", displayPrice: "$2.99")]

    /// ok, owned, pending, fail, cancel, slow, missing
    static func scenario(_ name: String) -> FakePackStoreClient {
        let client = FakePackStoreClient()
        switch name {
        case "owned": client.owned = [PackProductID.coasts]
        case "pending": client.result = .pending
        case "fail": client.result = .failed
        case "cancel": client.result = .cancelled
        case "slow": client.delay = .seconds(2)
        case "missing": client.products = [:]
        default: break
        }
        return client
    }

    func product(for id: Pack.ID) async -> PackProduct? { products[id] }
    func ownedIDs() async -> Set<Pack.ID> { owned }

    func purchase(_ product: PackProduct) async -> PackPurchaseResult {
        if let delay { try? await Task.sleep(for: delay) }
        purchases.append(product.id)
        if result == .owned { owned.insert(product.id) }
        return result
    }

    func ownedUpdates() -> AsyncStream<Pack.ID> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Pack.ID>.makeStream()
        listeners[id] = continuation
        continuation.onTermination = { [weak self] _ in Task { @MainActor in self?.listeners[id] = nil } }
        return stream
    }

    /// Simulates a `Transaction.updates` delivery.
    func emitOwned(_ id: Pack.ID) {
        owned.insert(id)
        listeners.values.forEach { $0.yield(id) }
    }
}
