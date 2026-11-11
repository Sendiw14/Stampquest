import Testing
import StoreKit
import StoreKitTest
@testable import StampQuest

/// Runs the live `StoreKitSubscriptionClient` against `Plus.storekit` in a StoreKitTest session (no network, no real purchase).
@MainActor
@Suite(.serialized)
struct PlusStoreKitTests {
    final class Anchor {}

    func session() throws -> SKTestSession {
        let url = try #require(Bundle(for: Anchor.self).url(forResource: "Plus", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        return session
    }

    @Test func aNewUserIsEligibleForTheYearlyTrialOnly() async throws {
        _ = try session()
        let products = try await StoreKitSubscriptionClient().loadProducts()
        let yearly = try #require(products.first { $0.kind == .yearly })
        let monthly = try #require(products.first { $0.kind == .monthly })
        #expect(yearly.isEligibleForIntro && yearly.eligibleTrial == SubscriptionPeriod(unit: .week, value: 1))
        #expect(monthly.introOffer == nil && !monthly.isEligibleForIntro)
        #expect(yearly.price == Decimal(string: "29.99") && monthly.price == Decimal(string: "4.99") && yearly.period.unit == .year && monthly.period.unit == .month)
        let content = PlusContent(products: products, selected: .yearly, canRemind: true, now: .now)
        #expect(content.ctaTitle == "Start 7-day free trial" && content.saveBadge == "Save 50%")
    }

    /// The purchase sheet itself (`Product.purchase()`) cannot be confirmed from a unit-test host, so the transaction is made through the
    /// test session; what is checked is what a fresh launch then sees.
    @Test func afterBuyingAFreshLaunchIsIneligibleAndEntitled() async throws {
        let session = try session()
        #expect(await !StoreKitSubscriptionClient().isEntitled())
        try await session.buyProduct(identifier: PlusProductID.yearly)
        let fresh = StoreKitSubscriptionClient()
        #expect(await fresh.isEntitled())
        // While the trial runs the test store may still report the offer as available; once the subscription has run out the trial is
        // used up. Expire it so the state is settled, then let the store's answer catch up instead of reading it once.
        try session.expireSubscription(productIdentifier: PlusProductID.yearly)
        var after = try await fresh.loadProducts()
        for _ in 0..<50 where after.first(where: { $0.kind == .yearly })?.isEligibleForIntro == true {
            try await Task.sleep(for: .milliseconds(100))
            after = try await fresh.loadProducts()
        }
        #expect(after.first { $0.kind == .yearly }?.isEligibleForIntro == false, "the trial is used up, so no trial claim")
        #expect(PlusContent(products: after, selected: .yearly, canRemind: true, now: .now).hasTrial == false)
    }

    @Test func restoreFindsAnExistingEntitlement() async throws {
        let session = try session()
        try await session.buyProduct(identifier: PlusProductID.monthly)
        let client = StoreKitSubscriptionClient()
        #expect(try await client.restore())
    }

    @Test func restoreWithNothingFindsNothing() async throws {
        _ = try session()
        #expect(try await StoreKitSubscriptionClient().restore() == false)
    }

    @Test func thePackLoadsWithTheStoresPriceAndOwnershipFollowsAPurchase() async throws {
        let session = try session()
        let client = StoreKitPackStoreClient()
        let product = try #require(await client.product(for: PackProductID.coasts))
        #expect(product.displayName == "Coasts" && product.displayPrice == "$2.99")
        #expect(await client.ownedIDs().isEmpty)
        try await session.buyProduct(identifier: PackProductID.coasts)
        #expect(await StoreKitPackStoreClient().ownedIDs() == [PackProductID.coasts])
        let model = ExitSheetModel(interests: [.coasts], flags: FeatureFlags(plusPaywallEnabled: true, coastsPackEnabled: true), client: client, manifest: PackManifest.withArt, onFinish: {})
        await model.prefetch()
        #expect(model.pack == nil, "an owned pack is not offered again")
    }
}
