import Foundation
import Observation

enum ExitSheetAlert: Equatable { case purchaseFailed }

/// State of the exit sheet. The router and the persistence are closures: the model imports neither.
@MainActor
@Observable
final class ExitSheetModel {
    enum PackState: Equatable { case idle(price: String), purchasing, pending, owned }

    /// nil means there is no pack row at all.
    private(set) var pack: PackState?
    private(set) var offer: PackOffer.Offer?
    private(set) var product: PackProduct?
    private(set) var features: [FreeTierFeature]
    var alert: ExitSheetAlert?
    var isPresented = false
    /// Counters the view turns into haptics, animations and announcements.
    private(set) var ownedCount = 0
    private(set) var failureCount = 0

    private let interests: Set<Interest>
    private let manifest: [Pack]
    private let flags: FeatureFlags
    private let client: PackStoreClient
    private let onBackToPlus: () -> Void
    private let onFinish: () -> Void

    var isBusy: Bool { pack == .purchasing }

    init(interests: Set<Interest>, flags: FeatureFlags, client: PackStoreClient, manifest: [Pack] = PackManifest.all, features: [FreeTierFeature] = FreeTierFeature.shipped(),
         onBackToPlus: @escaping () -> Void = {}, onFinish: @escaping () -> Void) {
        self.interests = interests
        self.manifest = manifest
        self.flags = flags
        self.client = client
        self.features = features
        self.onBackToPlus = onBackToPlus
        self.onFinish = onFinish
    }

    /// Chooses the pack and loads its product, so the sheet opens with the price ready. No pack, or a product that did not load, leaves
    /// no row: never a dead one.
    func prefetch() async {
        guard flags.coastsPackEnabled, pack == nil else { return }
        let owned = await client.ownedIDs()
        guard let offer = PackOffer.choose(interests: interests, owned: owned, manifest: manifest, featured: manifest.first ?? PackManifest.featured), let product = await client.product(for: offer.pack.id) else { return }
        self.offer = offer
        self.product = product
        pack = .idle(price: product.displayPrice)
    }

    func buyPack() async {
        guard case .idle(let price) = pack, let product else { return }
        pack = .purchasing
        switch await client.purchase(product) {
        case .owned: markOwned()
        case .cancelled: pack = .idle(price: price)
        case .pending: pack = .pending
        case .failed:
            pack = .idle(price: price)
            alert = .purchaseFailed
            failureCount += 1
        }
    }

    /// A transaction update for the offered pack, while the sheet is open, completes a pending purchase.
    func observeUpdates() async {
        for await id in client.ownedUpdates() where id == product?.id && pack == .pending { markOwned() }
    }

    /// The close button, a swipe down and "See Plus again".
    func closeToPlus() {
        guard !isBusy else { return }
        isPresented = false
        onBackToPlus()
    }

    func continueFree() {
        guard !isBusy else { return }
        isPresented = false
        onFinish()
    }

    private func markOwned() {
        pack = .owned
        ownedCount += 1
    }
}
