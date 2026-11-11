import Testing
import Foundation
import SwiftUI
import UIKit
@testable import StampQuest

extension PackManifest {
    /// The manifest as it will be once the packs have real art, for tests of the offer and the sheet.
    static var withArt: [Pack] { all.map { Pack(id: $0.id, interest: $0.interest, subjectKey: $0.subjectKey, stamps: $0.stamps, hasRealArt: true) } }
}

@MainActor
struct ExitSheetPolicyTests {
    @Test func showsOnceForSomeoneWithoutPlusWhenTheFlagIsOn() {
        let store = InMemoryExitSheetStore()
        #expect(ExitSheetPolicy.shouldPresent(plusEnabled: true, isEntitled: false, alreadyShown: store.isShown))
        store.markShown()
        #expect(!ExitSheetPolicy.shouldPresent(plusEnabled: true, isEntitled: false, alreadyShown: store.isShown), "the second close goes to finish")
    }

    @Test func neverWhenEntitledOrTheFlagIsOff() {
        #expect(!ExitSheetPolicy.shouldPresent(plusEnabled: true, isEntitled: true, alreadyShown: false))
        #expect(!ExitSheetPolicy.shouldPresent(plusEnabled: false, isEntitled: false, alreadyShown: false))
    }

    @Test func theShownFlagPersistsUnderItsKey() {
        let defaults = UserDefaults(suiteName: "exit-sheet-tests") ?? .standard
        defaults.removePersistentDomain(forName: "exit-sheet-tests")
        let store = UserDefaultsExitSheetStore(defaults: defaults)
        #expect(!store.isShown)
        store.markShown()
        #expect(UserDefaultsExitSheetStore(defaults: defaults).isShown && defaults.bool(forKey: "onboarding.exitSheetShown"))
    }
}

struct PackOfferTests {
    @Test func theFirstInterestWithAnUnownedPackWins() {
        let offer = PackOffer.choose(interests: [.cities, .coasts], owned: [], manifest: PackManifest.withArt, featured: PackManifest.withArt[0])
        #expect(offer?.pack.id == PackManifest.coasts.id && offer?.isForInterest == true)
    }

    @Test func noInterestsOffersTheFeaturedPackWithTheGenericBlurb() {
        let offer = PackOffer.choose(interests: [], owned: [], manifest: PackManifest.withArt, featured: PackManifest.withArt[0])
        #expect(offer?.pack.id == PackManifest.featured.id && offer?.isForInterest == false)
    }

    @Test func everyCandidateOwnedMeansNoOffer() {
        #expect(PackOffer.choose(interests: [.coasts], owned: [PackProductID.coasts], manifest: PackManifest.withArt, featured: PackManifest.withArt[0]) == nil)
        #expect(PackOffer.choose(interests: [], owned: [PackProductID.coasts], manifest: PackManifest.withArt, featured: PackManifest.withArt[0]) == nil)
    }

    @Test func secondPackIsSkippedWhenTheFirstIsOwned() {
        let second = Pack(id: "pack.mountains", interest: .mountains, subjectKey: "x", stamps: [], hasRealArt: true)
        let manifest = PackManifest.withArt + [second]
        #expect(PackOffer.choose(interests: [.coasts, .mountains], owned: [PackProductID.coasts], manifest: manifest)?.pack == second)
    }

    @Test func f5_aPackWithoutRealArtIsNeverOffered() {
        #expect(!PackManifest.coasts.hasRealArt, "Coasts has no artwork of its own yet")
        #expect(PackOffer.choose(interests: [.coasts], owned: []) == nil && PackOffer.choose(interests: [], owned: []) == nil)
    }

    @Test func f5_theBlurbNamesThePickedInterestsPhraseOrIsGeneric() {
        #expect(PackOffer.blurb(for: PackManifest.coasts, isForInterest: true) == "Stamps for the shores you picked. Buy once, keep forever.")
        #expect(PackOffer.blurb(for: PackManifest.coasts, isForInterest: false) == "A pack of extra stamps. Buy once, keep forever.")
    }
}

struct FreeTierFeatureTests {
    @Test func unshippedRowsAreDroppedAndNoneHidesTheCard() {
        #expect(FreeTierFeature.shipped(isShipped: { $0 != .tools }) == [.collect, .offline])
        #expect(FreeTierFeature.shipped(isShipped: { _ in false }).isEmpty)
        #expect(FreeTierFeature.shipped().count == 3)
    }
}

struct ExitTitleTests {
    @Test func theStampWordIsTakenFromTheMarkers() {
        let parts = ExitTitleParts.parse("Start ⟦free⟧,\nupgrade later")
        #expect(parts == ExitTitleParts.Parts(before: "Start", word: "free", after: ",", second: "upgrade later"))
        #expect(ExitTitleParts.parse("Start free,\nupgrade later") == nil && ExitTitleParts.plain("Start ⟦free⟧") == "Start free")
    }
}

@MainActor
struct ExitSheetModelTests {
    final class Recorder { var back = 0; var finish = 0 }

    func make(_ client: FakePackStoreClient = FakePackStoreClient(), flags: FeatureFlags = FeatureFlags(plusPaywallEnabled: true, coastsPackEnabled: true),
              interests: Set<Interest> = [.coasts]) -> (ExitSheetModel, FakePackStoreClient, Recorder) {
        let recorder = Recorder()
        let model = ExitSheetModel(interests: interests, flags: flags, client: client, manifest: PackManifest.withArt, onBackToPlus: { recorder.back += 1 }, onFinish: { recorder.finish += 1 })
        return (model, client, recorder)
    }

    @Test func prefetchShowsTheStoresPriceNeverALiteral() async {
        let client = FakePackStoreClient(products: [PackProductID.coasts: PackProduct(id: PackProductID.coasts, displayName: "Coasts", displayPrice: "A$4.49")])
        let (model, _, _) = make(client)
        await model.prefetch()
        #expect(model.pack == .idle(price: "A$4.49"))
    }

    @Test func noPackRowWhenTheProductIsMissingTheFlagIsOffOrItIsOwned() async {
        let (missing, _, _) = make(FakePackStoreClient(products: [:]))
        await missing.prefetch()
        let (off, _, _) = make(flags: FeatureFlags(plusPaywallEnabled: true))
        await off.prefetch()
        let (owned, _, _) = make(FakePackStoreClient(owned: [PackProductID.coasts]))
        await owned.prefetch()
        #expect(missing.pack == nil && off.pack == nil && owned.pack == nil)
    }

    @Test func buyingMovesIdleToPurchasingToOwned() async {
        let client = FakePackStoreClient()
        client.delay = .milliseconds(60)
        let (model, _, _) = make(client)
        await model.prefetch()
        let task = Task { await model.buyPack() }
        await Task.yield()
        #expect(model.pack == .purchasing && model.isBusy)
        await task.value
        #expect(model.pack == .owned && model.alert == nil && model.ownedCount == 1 && client.purchases == [PackProductID.coasts])
    }

    @Test func cancelReturnsToIdleSilently() async {
        let client = FakePackStoreClient()
        client.result = .cancelled
        let (model, _, _) = make(client)
        await model.prefetch()
        await model.buyPack()
        #expect(model.pack == .idle(price: "$2.99") && model.alert == nil && model.failureCount == 0)
    }

    @Test func failureReturnsToIdleWithAnAlert() async {
        let client = FakePackStoreClient()
        client.result = .failed
        let (model, _, _) = make(client)
        await model.prefetch()
        await model.buyPack()
        #expect(model.pack == .idle(price: "$2.99") && model.alert == .purchaseFailed && model.failureCount == 1)
    }

    @Test func pendingBecomesOwnedThroughAnUpdate() async throws {
        let client = FakePackStoreClient()
        client.result = .pending
        let (model, _, _) = make(client)
        await model.prefetch()
        await model.buyPack()
        #expect(model.pack == .pending)
        let listener = Task { await model.observeUpdates() }
        await Task.yield()
        client.emitOwned(PackProductID.coasts)
        for _ in 0..<200 where model.pack != .owned { try await Task.sleep(for: .milliseconds(10)) }
        listener.cancel()
        #expect(model.pack == .owned)
    }

    @Test func closeAndContinueCallTheirClosuresAndAreBlockedWhileBuying() async {
        let client = FakePackStoreClient()
        client.delay = .milliseconds(60)
        let (model, _, recorder) = make(client)
        await model.prefetch()
        model.isPresented = true
        let task = Task { await model.buyPack() }
        await Task.yield()
        model.closeToPlus()
        model.continueFree()
        #expect(recorder.back == 0 && recorder.finish == 0 && model.isPresented)
        await task.value
        model.closeToPlus()
        #expect(recorder.back == 1 && !model.isPresented)
        model.continueFree()
        #expect(recorder.finish == 1)
    }
}

struct ExitSheetCatalogAndColorTests {
    nonisolated static let keys = ["exit.title", "exit.subtitle", "exit.free.collect", "exit.free.tools", "exit.free.offline", "exit.pack.label",
                                   "exit.pack.title %@", "exit.pack.blurb %@", "exit.pack.blurb.generic", "exit.pack.subject.coasts", "exit.pack.added",
                                   "exit.pack.pending", "exit.cta", "exit.link", "exit.close", "exit.close.hint", "exit.error.title", "exit.error.body",
                                   "exit.a11y.title", "exit.a11y.list", "exit.a11y.included %@", "exit.a11y.buy %@ %@", "exit.a11y.buying %@",
                                   "exit.a11y.added %@", "exit.a11y.pending %@"]

    @Test(arguments: keys) func everyKeyExistsWithAValue(key: String) {
        let value = Bundle.main.localizedString(forKey: key, value: "__missing__", table: nil)
        #expect(value != "__missing__" && !value.isEmpty, "\(key)")
    }

    @Test(arguments: [(UIUserInterfaceStyle.light, 0), (UIUserInterfaceStyle.dark, 1)])
    func contrastMeetsTheRequiredMinimums(style: UIUserInterfaceStyle, index: Int) {
        func c(_ name: String) -> [CGFloat] { ColorKit.resolved(name, style) }
        func pick(_ light: Double, _ dark: Double) -> Double { index == 0 ? light : dark }
        let paper = c("passportPaper")
        let free = ColorKit.over(c("freeCardFill"), paper)
        #expect(ColorKit.ratio(c("inkPrimary"), paper) >= pick(15.0, 12.5) && ColorKit.ratio(c("inkSecondary"), paper) >= pick(6.2, 7.0))
        #expect(ColorKit.ratio(c("inkPrimary"), free) >= pick(13.5, 10.5), "ink on the free card")
        #expect(ColorKit.ratio(c("ctaFill"), paper) >= pick(4.7, 5.4), "See Plus again on paper")
        #expect(ColorKit.ratio(c("ctaFill"), free) >= pick(4.3, 4.6), "check circles on the free card (3.0 needed)")
        #expect(ColorKit.ratio(c("inkSecondary"), ColorKit.over(c("closeFill"), paper)) >= pick(5.4, 5.0), "close glyph")
    }
}

@MainActor
@Suite(.serialized)
struct ExitSheetSnapshotTests {
    enum Width: String, CaseIterable { case w402, w375, ax3 }

    func makeView(owned: Bool, width: Width) async -> some View {
        ExitSheetMotion.timeScale = 0
        let model = ExitSheetModel(interests: [.coasts], flags: FeatureFlags(plusPaywallEnabled: true, coastsPackEnabled: true),
                                   client: FakePackStoreClient(), manifest: PackManifest.withArt, onFinish: {})
        await model.prefetch()
        if owned { await model.buyPack() }
        return ExitSheetView(model: model)
            .environment(\.obReducesMotion, true)
            .environment(\.dynamicTypeSize, width == .ax3 ? .accessibility3 : .large)
            .frame(width: width == .w375 ? 375 : 402)
    }

    /// `variant` bit 0 is owned, bit 1 is dark.
    @Test(arguments: Width.allCases, [0, 1, 2, 3])
    func snapshot(width: Width, variant: Int) async throws {
        let (owned, dark) = (variant & 1 == 1, variant & 2 == 2)
        let size = CGSize(width: width == .w375 ? 375 : 402, height: width == .ax3 ? 874 : 700)
        let image = try await SnapshotSupport.image(of: await makeView(owned: owned, width: width), size: size, dark: dark)
        try SnapshotSupport.verify(image, named: "exit-\(width.rawValue)-\(owned ? "owned" : "default")-\(dark ? "dark" : "light")", size: size)
    }
}
