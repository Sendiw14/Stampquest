import Testing
import Foundation
@testable import StampQuest

struct OnboardingRouteTests {
    @Test func skipTargetsFollowTheSpecTable() {
        #expect(OnboardingRoute.interests.skipTarget == .firstStamp)
        #expect(OnboardingRoute.firstStamp.skipTarget == .verification)
        #expect(OnboardingRoute.verification.skipTarget == .cover)
        #expect(OnboardingRoute.cover.skipTarget == nil, "Cover's Skip routes like Continue: to Passport ready")
        #expect(OnboardingRoute.plus.skipTarget == nil && !OnboardingRoute.plus.hasSkip)
    }

    @Test func plusExistsOnlyWhenTheFlagIsOn() {
        #expect(OnboardingRoute.flow(plusEnabled: false) == [.interests, .firstStamp, .verification, .cover, .passportReady])
        #expect(OnboardingRoute.flow(plusEnabled: true).last == .plus)
        #expect(OnboardingRoute.cover.next(plusEnabled: false) == .passportReady)
        #expect(OnboardingRoute.passportReady.next(plusEnabled: false) == nil)
        #expect(OnboardingRoute.passportReady.next(plusEnabled: true) == .plus)
        #expect(OnboardingRoute.plus.next(plusEnabled: true) == nil)
    }

    @Test func progressStripCoversStepsTwoToFiveOnly() {
        #expect(OnboardingRoute.allCases.compactMap(\.progressStep) == [2, 3, 4, 5, 5])
        #expect(OnboardingRoute.welcomeProgressStep == 1)
        #expect(OnboardingRoute.plus.progressStep == nil)
    }

    @Test func onlyPlusHasNoBack() {
        #expect(OnboardingRoute.allCases.filter { !$0.hasBack } == [.plus])
    }

    @Test func restoredStackContainsEveryRouteUpToTheReachedOne() {
        #expect(OnboardingRoute.verification.stack(plusEnabled: false) == [.interests, .firstStamp, .verification])
        #expect(OnboardingRoute.plus.stack(plusEnabled: false).isEmpty, "Plus does not exist when the flag is off")
    }
}

struct StarterTrayTests {
    private func ids(_ interests: Set<Interest>) -> [String] { StarterTray.rank(for: interests).map(\.id) }
    private let paris = StampDestination.paris.id, kyoto = StampDestination.kyoto.id, santorini = StampDestination.santorini.id

    @Test func catalogOrderIsParisKyotoSantorini() {
        #expect(StampDestination.catalog.map(\.id) == [paris, kyoto, santorini])
    }

    @Test func emptyInterestsReturnCatalogOrder() {
        #expect(ids([]) == [paris, kyoto, santorini])
    }

    @Test func eachSingleInterestRanksByWeight() {
        #expect(ids([.cities]) == [paris, kyoto, santorini])
        #expect(ids([.coasts]) == [santorini, paris, kyoto])
        #expect(ids([.mountains]) == [kyoto, paris, santorini])
        #expect(ids([.food]) == [paris, kyoto, santorini])
        #expect(ids([.history]) == [kyoto, paris, santorini])
        #expect(ids([.hiddenGems]) == [kyoto, santorini, paris])
    }

    @Test func citiesAndCoastsTieAtThreeSoCatalogOrderDecides() {
        #expect(StarterTray.score(.paris, for: [.cities, .coasts]) == 3)
        #expect(StarterTray.score(.santorini, for: [.cities, .coasts]) == 3)
        #expect(ids([.cities, .coasts]) == [paris, santorini, kyoto])
    }

    @Test func scoresSumTheSelectedWeights() {
        #expect(StarterTray.score(.kyoto, for: Set(Interest.allCases)) == 1 + 1 + 1 + 2 + 2)
        #expect(StarterTray.score(.paris, for: Set(Interest.allCases)) == 5)
    }

    @Test func rankingIsDeterministicAndAlwaysOffersTheThreeStamps() {
        for subset in [[Interest.food], [.history, .hiddenGems], Interest.allCases] {
            #expect(ids(Set(subset)) == ids(Set(subset)))
            #expect(Set(ids(Set(subset))) == [paris, kyoto, santorini])
        }
    }
}

struct CoverAndFlagTests {
    @Test func plusCoversAreHiddenWhenTheFlagIsOff() {
        #expect(CoverStyle.available(plusEnabled: false).count == 3)
        #expect(CoverStyle.available(plusEnabled: false).allSatisfy { !$0.isPlus })
        #expect(CoverStyle.available(plusEnabled: true).count == 5)
        #expect(!CoverStyle.default.isPlus)
    }

    @Test func flagsDefaultOff() {
        #expect(FeatureFlags() == FeatureFlags(plusPaywallEnabled: false, coastsPackEnabled: false))
        #expect(!FeatureFlags().plusPaywallEnabled && !FeatureFlags().coastsPackEnabled)
    }

    #if DEBUG
    @Test func debugArgumentsOverrideFlags() {
        #expect(FeatureFlags(arguments: ["-ff-plus"]) == FeatureFlags(plusPaywallEnabled: true))
        #expect(FeatureFlags(arguments: ["-ff-coasts"]).coastsPackEnabled)
        #expect(FeatureFlags(arguments: []) == FeatureFlags())
    }
    #endif

    @Test func everyCoverMapsToAMainAppStyleWithTheSameBaseColour() {
        #expect(Set(CoverStyle.allCases.map(\.passportStyle)).count == CoverStyle.allCases.count)
    }

    @Test func coversAreInCarouselOrderWithTheSpecColours() {
        #expect(CoverStyle.allCases == [.clay, .forest, .midnight, .harbor, .rosewood])
        #expect(CoverStyle.default == .harbor)
        #expect(CoverStyle.available(plusEnabled: false) == [.clay, .forest, .harbor])
        #expect(CoverStyle.harbor.colors.base == 0x4D7396 && CoverStyle.rosewood.colors.deep == 0x834550)
    }
}

struct FormattingTests {
    private let date = Date(timeIntervalSince1970: 1_792_972_800) // 2026-10-26 00:00 UTC
    private let utc = TimeZone(identifier: "UTC")!

    @Test func stampDateIsFormattedFromTheValueAndUppercased() {
        let gb = OnboardingFormat.stampDate(date, locale: Locale(identifier: "en_GB"), timeZone: utc)
        #expect(gb == "26 OCT 2026")
        let us = OnboardingFormat.stampDate(date, locale: Locale(identifier: "en_US"), timeZone: utc)
        #expect(us.contains("OCT") && us.contains("26") && us.contains("2026"))
    }

    @Test func priceIsFormattedFromAValue() {
        #expect(OnboardingFormat.price(Decimal(string: "39.99")!, currencyCode: "USD", locale: Locale(identifier: "en_US")) == "$39.99")
    }
}

struct DestinationTests {
    @Test func numbersAreFormattedWithPadding() {
        #expect(StampDestination.paris.numberLabel == "No. 01")
        #expect(StampDestination.kyoto.numberLabel == "No. 03")
        #expect(StampDestination.santorini.label == "SANTORINI")
    }

    @Test func destinationIdsMatchTheMainCatalog() throws {
        let catalog = try CatalogLoader.load()
        for destination in StampDestination.catalog {
            #expect(catalog.destination(id: destination.id) != nil, "\(destination.id) must exist in the bundled catalog")
        }
    }
}

struct ServiceMockTests {
    @MainActor @Test func unavailablePurchasesNeverEntitleOrSell() async {
        let service = UnavailablePurchaseService()
        #expect(!service.isPlusEntitled)
        await #expect(throws: PurchaseError.unavailable) { try await service.purchase(productID: "x") }
    }

    @MainActor @Test func mockPurchaseEntitlesOnlyOnSuccess() async throws {
        let service = MockPurchaseService(nextOutcome: .success(.cancelled))
        #expect(try await service.purchase(productID: "plus") == .cancelled)
        #expect(!service.isPlusEntitled)
        service.nextOutcome = .success(.purchased)
        _ = try await service.purchase(productID: "plus")
        #expect(service.isPlusEntitled)
    }

    @MainActor @Test func unavailableReminderServiceSchedulesNothing() async {
        let service = UnavailableReminderService()
        #expect(await !service.canDeliver())
        await #expect(throws: ReminderError.unavailable) { try await service.schedule(id: "a", at: .now, title: "t", body: "b") }
    }
}
