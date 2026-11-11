import Testing
import Foundation
import SwiftData
import MapKit
@testable import StampQuest

@MainActor
enum MapFixture {
    /// Three places in Europe, two in Japan, one in Peru: Europe is the densest region.
    static let catalog: Catalog = {
        @MainActor func place(_ id: String, _ country: String, _ region: String, _ lat: Double, _ lon: Double) -> String {
            Fixture.destinationJSON(id: id, name: id.capitalized, country: country, region: region, lat: lat, lon: lon)
        }
        let places = [
            place("paris", "FR", "europe", 48.85, 2.35), place("rome", "IT", "europe", 41.90, 12.50), place("lisbon", "PT", "europe", 38.72, -9.14),
            place("kyoto", "JP", "asia", 35.01, 135.77), place("tokyo", "JP", "asia", 35.68, 139.69), place("cusco", "PE", "southAmerica", -13.53, -71.97),
        ]
        // swiftlint:disable:next force_try
        return try! CatalogLoader.build(metaData: Data(Fixture.metaJSON(collections: "").utf8), destinationFiles: [Fixture.filesJSON(places)])
    }()

    static func environment(location: MockLocationProvider = MockLocationProvider()) throws -> AppEnvironment {
        AppEnvironment(catalog: catalog, container: try Fixture.container(),
                       preferences: PreferencesStore(defaults: UserDefaults(suiteName: "map-\(UUID().uuidString)")!),
                       locationProvider: location, photos: PhotoStore())
    }

    static func derived(_ env: AppEnvironment) -> MapDerived { MapDerived(catalog: env.catalog, snapshot: env.store.snapshot()) }
}

@MainActor
struct MapDerivedTests {
    let env: AppEnvironment

    init() throws { env = try MapFixture.environment() }

    private var derived: MapDerived { MapFixture.derived(env) }

    @Test func stateFollowsVerifiedOverCollectedOverSavedOverAvailable() throws {
        #expect(derived.state(for: "paris") == .notCollected)
        try env.store.addToWishlist(destinationID: "paris")
        #expect(derived.state(for: "paris") == .wishlisted)
        try env.store.collect(destinationID: "paris")
        #expect(derived.state(for: "paris") == .collected, "A collected place that is also wishlisted is collected, never saved")
        try env.store.recordVerification(destinationID: "paris", verification: Fixture.verification())
        #expect(derived.state(for: "paris") == .verified)
    }

    @Test func manualCollectionIsNeverVerified() throws {
        try env.store.collect(destinationID: "rome")
        #expect(derived.state(for: "rome") == .collected)
        #expect(derived.counts.verified == 0)
    }

    @Test func countsAndTheLineDeriveFromRecords() throws {
        #expect(derived.counts == MapCounts() && derived.counts.line == "Nothing collected yet")
        try env.store.collect(destinationID: "paris")
        try env.store.collect(destinationID: "rome")
        try env.store.recordVerification(destinationID: "rome", verification: Fixture.verification())
        try env.store.addToWishlist(destinationID: "kyoto")
        try env.store.addToWishlist(destinationID: "lisbon")
        #expect(derived.counts == MapCounts(collected: 2, verified: 1, saved: 2))
        #expect(derived.counts.line == "2 collected · 1 verified · 2 saved")

        try env.store.collect(destinationID: "kyoto")
        #expect(derived.counts == MapCounts(collected: 3, verified: 1, saved: 1), "A collected place leaves the Saved count")

        _ = try env.store.removeStamp(destinationID: "paris")
        try env.store.removeFromWishlist(destinationID: "lisbon")
        #expect(derived.counts == MapCounts(collected: 2, verified: 1, saved: 0))
    }

    @Test func countsAreTotalsAcrossTheWholeCatalogNotJustTheLayer() throws {
        try env.store.collect(destinationID: "paris")
        try env.store.addToWishlist(destinationID: "tokyo")
        let d = derived
        #expect(d.visiblePlaces(.saved).count == 1 && d.counts.collected == 1 && d.counts.saved == 1)
    }

    @Test func visiblePlacesFollowEachLayerAndTheListUsesTheSameSet() throws {
        try env.store.collect(destinationID: "paris")
        try env.store.recordVerification(destinationID: "rome", verification: Fixture.verification())
        try env.store.addToWishlist(destinationID: "kyoto")
        let d = derived
        #expect(Set(d.visiblePlaces(.all).map(\.id)).count == 6)
        #expect(Set(d.visiblePlaces(.collected).map(\.id)) == ["paris", "rome"])
        #expect(d.visiblePlaces(.verified).map(\.id) == ["rome"])
        #expect(d.visiblePlaces(.saved).map(\.id) == ["kyoto"])
        for layer in MapLayer.allCases {
            #expect(Set(d.visibleDestinations(layer).map(\.id)) == Set(d.visiblePlaces(layer).map(\.id)), "Map and list show the same places for \(layer)")
        }
    }

    @Test func aPlaceWithoutCoordinatesIsOnTheListButNotOnTheMap() {
        func destination(_ id: String, lat: Double, lon: Double) -> Destination {
            Destination(id: id, name: id, landmark: id, countryCode: "FR", region: .europe, category: .city, latitude: lat, longitude: lon,
                        verificationRadiusOverride: nil, summary: "", story: "", keywords: [], alternativeNames: [], isFeatured: false)
        }
        #expect(destination("a", lat: 48, lon: 2).hasMapCoordinate)
        #expect(!destination("b", lat: 0, lon: 0).hasMapCoordinate)
        #expect(!destination("c", lat: 91, lon: 2).hasMapCoordinate)
        #expect(!destination("d", lat: .nan, lon: 2).hasMapCoordinate)
        let catalog = Catalog(version: "t", destinations: [destination("a", lat: 48, lon: 2), destination("b", lat: 0, lon: 0)], stamps: [], collections: [])
        let d = MapDerived(catalog: catalog, snapshot: .empty)
        #expect(d.places.map(\.id) == ["a"])
        #expect(d.visibleDestinations(.all).map(\.id) == ["a", "b"])
    }

    @Test func savingAndCollectingTwiceCreatesOneRecord() throws {
        #expect(try env.store.addToWishlist(destinationID: "paris"))
        #expect(try env.store.addToWishlist(destinationID: "paris") == false)
        try env.store.collect(destinationID: "paris")
        try env.store.collect(destinationID: "paris")
        #expect(try env.container.mainContext.fetchCount(FetchDescriptor<UserStamp>()) == 1)
        #expect(try env.container.mainContext.fetchCount(FetchDescriptor<WishlistItem>()) == 0)
    }
}

@MainActor
struct MapPerformanceTests {
    @Test func derivingTwoThousandPlacesStaysWellUnderAFrame() throws {
        let places = (0..<2_000).map { i in
            Fixture.destinationJSON(id: "p\(i)", name: "Place \(i)", lat: Double(i % 150) - 70, lon: Double(i % 340) - 170.5)
        }
        let catalog = try CatalogLoader.build(metaData: Data(Fixture.metaJSON(collections: "").utf8), destinationFiles: [Fixture.filesJSON(places)])
        #expect(catalog.destinations.count == 2_000)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            let d = MapDerived(catalog: catalog, snapshot: .empty)
            #expect(d.visiblePlaces(.all).count == 2_000)
            _ = MapInitialCamera.rect(places: d.places, derived: d)
        }
        print("MAPPERF derive+visible+initial camera for 2000 places:", elapsed)
        #expect(elapsed < .milliseconds(250), "Debug build on the simulator; Release is far faster")
    }
}

@MainActor
struct MapViewModelTests {
    let location = MockLocationProvider()
    let env: AppEnvironment
    let model: MapViewModel

    init() throws {
        env = try MapFixture.environment(location: location)
        model = MapViewModel(env: env)
    }

    private var derived: MapDerived { MapFixture.derived(env) }

    @Test func theMapOpensOnAll() { #expect(model.layer == .all && model.selectedID == nil) }

    @Test func selectionIsKeptWhenThePlaceIsInTheNewLayerAndClearedWhenItIsNot() throws {
        try env.store.collect(destinationID: "paris")
        model.select("paris", derived: derived)
        model.setLayer(.collected, derived: derived)
        #expect(model.selectedID == "paris")
        model.setLayer(.verified, derived: derived)
        #expect(model.selectedID == nil, "Verified hides a manually collected place, so the card goes")
    }

    @Test func tappingTheSelectedMarkerAgainOrTheEmptyMapClearsIt() {
        model.tapPlace("rome", derived: derived)
        #expect(model.selectedID == "rome")
        model.tapPlace("rome", derived: derived)
        #expect(model.selectedID == nil)
        model.tapPlace("rome", derived: derived)
        model.clearSelection()
        #expect(model.selectedID == nil)
    }

    @Test func theCardFollowsAStateChangeMadeElsewhere() throws {
        model.select("rome", derived: derived)
        #expect(derived.state(for: model.selectedID ?? "") == .notCollected)
        try env.store.collect(destinationID: "rome")
        #expect(model.selectedID == "rome" && derived.state(for: "rome") == .collected)
    }

    @Test func aSearchResultSwitchesToAllWhenTheLayerWouldHideIt() throws {
        try env.store.collect(destinationID: "paris")
        model.setLayer(.collected, derived: derived)
        model.showPlace("kyoto", derived: derived)
        #expect(model.layer == .all && model.selectedID == "kyoto")
    }

    @Test func selectingAPlaceAsksTheCameraToFocusOnIt() throws {
        model.select("lisbon", derived: derived)
        guard case .focus(let c)? = model.camera?.target else { Issue.record("expected a focus move"); return }
        #expect(abs(c.latitude - 38.72) < 0.001)
    }

    @Test func savingShowsOneToastAndUndoRestoresTheOriginalDate() throws {
        model.toggleSave("paris")
        #expect(env.store.state(of: "paris") == .wishlisted && env.toasts.current?.message == "Saved to wishlist")
        let saved = try #require(env.store.wishlistDate("paris"))
        model.toggleSave("paris")
        #expect(env.toasts.current?.message == "Removed from wishlist")
        env.toasts.undo()
        #expect(env.store.wishlistDate("paris") == saved)
    }

    @Test func collectingFromTheCardTwiceCreatesNoSecondRecord() throws {
        model.collect("rome")
        model.collect("rome")
        #expect(try env.container.mainContext.fetchCount(FetchDescriptor<UserStamp>()) == 1)
    }

    // MARK: Locate

    @Test func nothingAsksForLocationUntilLocateIsTapped() {
        location.status = .notDetermined
        #expect(location.promptCount == 0 && location.readingRequests == 0 && !model.showsExplainer)
        model.select("paris", derived: derived)
        model.setLayer(.collected, derived: derived)
        #expect(location.promptCount == 0 && location.readingRequests == 0)
    }

    @Test func locateWithPermissionNeverAskedShowsTheExplainerAndNotNowAsksNothing() {
        location.status = .notDetermined
        model.tapLocate()
        #expect(model.showsExplainer && location.promptCount == 0)
        model.dismissExplainer()
        #expect(!model.showsExplainer && location.promptCount == 0 && location.readingRequests == 0 && !model.isLocateOn)
    }

    @Test func continueAsksForWhenInUseThenFixesOnce() async throws {
        location.status = .notDetermined
        location.statusAfterPrompt = .authorized
        location.result = .success(LocationReading(latitude: 41.9, longitude: 12.5, horizontalAccuracy: 20, timestamp: .now))
        model.tapLocate()
        model.continueFromExplainer()
        try await waitUntil { model.isLocateOn }
        #expect(location.promptCount == 1 && location.readingRequests == 1)
        guard case .local(_, let meters)? = model.camera?.target else { Issue.record("expected a local move"); return }
        #expect(meters == 25_000)
    }

    @Test func locateWithPermissionTakesOneFixAndTurnsOffOnTheSecondTap() async throws {
        location.result = .success(LocationReading(latitude: 41.9, longitude: 12.5, horizontalAccuracy: 20, timestamp: .now))
        model.tapLocate()
        try await waitUntil { model.isLocateOn }
        #expect(location.readingRequests == 1 && model.userCoordinate != nil)
        model.tapLocate()
        #expect(!model.isLocateOn && model.userCoordinate == nil && location.readingRequests == 1)
    }

    @Test func thePositionTurnsOffWhenTheTabOrAppIsLeft() async throws {
        location.result = .success(LocationReading(latitude: 41.9, longitude: 12.5, horizontalAccuracy: 20, timestamp: .now))
        model.tapLocate()
        try await waitUntil { model.isLocateOn }
        model.turnLocateOff()
        #expect(!model.isLocateOn && model.userCoordinate == nil)
    }

    @Test func locateWhenRefusedShowsTheBannerAndAsksNothing() {
        for status in [LocationAuthorization.denied, .restricted] {
            location.status = status
            model.tapLocate()
            #expect(model.showsLocationOffBanner && !model.showsExplainer && location.promptCount == 0 && location.readingRequests == 0)
            model.dismissLocationOffBanner()
        }
    }

    @Test func aFailedFixTurnsNothingOnAndSaysSo() async throws {
        location.result = .failure(.timeout)
        model.tapLocate()
        try await waitUntil { env.toasts.current != nil }
        #expect(!model.isLocateOn && model.userCoordinate == nil)
    }

    @Test func theBannerGoesWhenPermissionIsGrantedInSettings() {
        location.status = .denied
        model.tapLocate()
        #expect(model.showsLocationOffBanner)
        location.status = .authorized
        model.authorizationMayHaveChanged()
        #expect(!model.showsLocationOffBanner)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        #expect(condition())
    }
}

@MainActor
struct MapCameraTests {
    private let size = CGSize(width: 378, height: 626)

    @Test func theFreeBandSitsBetweenTheChipsAndTheCard() {
        #expect(MapGeometry.freeBandTop == 66)
        #expect(MapGeometry.freeBandCenterY(windowHeight: 626) == CGFloat(272))
    }

    @Test func aFocusedPlaceLandsAtTheCentreOfTheFreeBand() {
        let rome = CLLocationCoordinate2D(latitude: 41.9, longitude: 12.5)
        let current = MKMapRect(x: MKMapPoint(rome).x - 3_000_000, y: MKMapPoint(rome).y - 5_000_000, width: 6_000_000, height: 10_000_000)
        let rect = MapGeometry.focusRect(on: rome, current: current, size: size)
        #expect(rect.width == current.width, "The zoom is kept at a regional level")
        let perPoint = rect.width / Double(size.width)
        let place = MKMapPoint(rome)
        let screenY = (place.y - rect.minY) / perPoint
        #expect(abs(screenY - Double(MapGeometry.freeBandCenterY(windowHeight: size.height))) < 0.5)
        #expect(abs((place.x - rect.minX) / perPoint - Double(size.width) / 2) < 0.5)
    }

    @Test func aMapZoomedOutPastRegionalLevelZoomsInToIt() {
        let world = MKMapRect(x: 0, y: 0, width: MKMapSize.world.width, height: MKMapSize.world.height)
        let rect = MapGeometry.focusRect(on: CLLocationCoordinate2D(latitude: 10, longitude: 10), current: world, size: size)
        #expect(abs(rect.width - MapGeometry.regionalWidth) < 1)
    }

    @Test func clustersAreSizedByCount() {
        #expect(MapClusterStyle.diameter(count: 4) == 34 && MapClusterStyle.diameter(count: 5) == 40)
        #expect(MapClusterStyle.diameter(count: 12) == 40 && MapClusterStyle.diameter(count: 13) == 46)
        #expect(MapClusterStyle.countFontSize(count: 12) == 15 && MapClusterStyle.countFontSize(count: 13) == 17)
    }

    @Test func theInitialCameraOpensOnCollectedPlacesThenTheDensestRegionAndNeverOnTheUser() throws {
        let env = try MapFixture.environment()
        let fresh = MapFixture.derived(env)
        let europe = try #require(MapInitialCamera.rect(places: fresh.places, derived: fresh))
        let paris = MKMapPoint(CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35))
        let kyoto = MKMapPoint(CLLocationCoordinate2D(latitude: 35.01, longitude: 135.77))
        #expect(europe.contains(paris) && !europe.contains(kyoto), "Nothing collected: the densest region, Europe")

        try env.store.collect(destinationID: "kyoto")
        try env.store.collect(destinationID: "tokyo")
        let mine = MapFixture.derived(env)
        let japan = try #require(MapInitialCamera.rect(places: mine.places, derived: mine))
        #expect(japan.contains(kyoto) && !japan.contains(paris), "Collected places win over the densest region")
    }

    @Test func theDensestRegionIgnoresPlacesFarAway() throws {
        let places = MapFixture.catalog.destinations.map { MapPlace(destination: $0, design: nil) }
        #expect(Set(MapInitialCamera.densest(places).map(\.id)) == ["paris", "rome", "lisbon"])
    }
}
