import Testing
import Foundation
@testable import StampQuest

struct HomePhaseTests {
    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    private func phase(lat: Double = 0, lon: Double = 0, _ iso: String) -> DestinationPhase {
        DestinationPhaseCalculator.phase(latitude: lat, longitude: lon, at: date(iso))
    }

    @Test func equinoxAtTheEquatorAndPrimeMeridianRunsThroughTheDay() {
        #expect(phase("2026-03-20T00:00:00Z") == .night)
        #expect(phase("2026-03-20T06:00:00Z") == .firstLight)
        #expect(phase("2026-03-20T06:15:00Z") == .sunrise)
        #expect(phase("2026-03-20T09:07:00Z") == .morning)
        #expect(phase("2026-03-20T12:07:00Z") == .midday)
        #expect(phase("2026-03-20T15:07:00Z") == .afternoon)
        #expect(phase("2026-03-20T17:20:00Z") == .goldenHour)
        #expect(phase("2026-03-20T17:55:00Z") == .sunset)
        #expect(phase("2026-03-20T18:15:00Z") == .eveningLight)
    }

    @Test func noonAltitudeIsNearNinetyMinusLatitudeAtTheEquinox() {
        let sun = DestinationPhaseCalculator.solar(latitude: 35.7, longitude: 139.74, at: date("2026-03-20T03:00:00Z"))
        #expect(abs(sun.altitude - 54.3) < 1.5, "Tokyo near local noon")
    }

    @Test func longitudeMovesThePhase() {
        #expect(phase(lat: 35.7, lon: 139.74, "2026-03-20T03:00:00Z") == .midday)
        #expect(phase(lat: 35.7, lon: -74, "2026-03-20T03:00:00Z") == .night)
    }
}

struct HomeCopyTests {
    @Test func greetingBuckets() {
        #expect(HomeCopy.greetingKind(hour: 4, isFirstRun: false) == .hello)
        #expect(HomeCopy.greetingKind(hour: 5, isFirstRun: false) == .morning)
        #expect(HomeCopy.greetingKind(hour: 12, isFirstRun: false) == .afternoon)
        #expect(HomeCopy.greetingKind(hour: 17, isFirstRun: false) == .evening)
        #expect(HomeCopy.greetingKind(hour: 22, isFirstRun: false) == .hello)
        #expect(HomeCopy.greetingKind(hour: 9, isFirstRun: true) == .welcome)
    }

    @Test func chipRulesEveryBranch() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(HomeCopy.chip(isFirstRun: true, catalogCount: 61, verifiedCount: 0, firstStampDate: nil) == .places(60))
        #expect(HomeCopy.chip(isFirstRun: true, catalogCount: 19, verifiedCount: 0, firstStampDate: nil) == nil)
        #expect(HomeCopy.chip(isFirstRun: false, catalogCount: 61, verifiedCount: 2, firstStampDate: day) == .verified(2))
        #expect(HomeCopy.chip(isFirstRun: false, catalogCount: 61, verifiedCount: 0, firstStampDate: day) == .since(day))
        #expect(HomeCopy.chip(isFirstRun: false, catalogCount: 61, verifiedCount: 0, firstStampDate: nil) == nil)
    }

    @Test func numeralTextAndSize() {
        #expect(HomeCopy.numeralText(7) == "7" && HomeCopy.numeralText(999) == "999" && HomeCopy.numeralText(1000) == "999+")
        #expect(HomeCopy.numeralSize(unitWidth: 0.5) == 320, "one digit stays at 320")
        #expect(HomeCopy.numeralSize(unitWidth: 1.6) == 122.5, "three digits shrink to fit 196 pt")
        #expect(HomeCopy.numeralSize(unitWidth: 4) == 84, "never below 84")
    }
}

struct HomeSnapshotTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func stamp(_ id: String, country: String, verified: Bool = false, at offset: TimeInterval = 0) -> CollectedStamp {
        CollectedStamp(stampID: "stamp." + id, destinationID: id, countryCode: country, title: id,
                       collectedAt: now.addingTimeInterval(offset), verifiedAt: verified ? now : nil)
    }

    private func build(_ stamps: [CollectedStamp], wishlist: [WishlistEntry] = [], override: String? = nil,
                       install: String = "install-1", at date: Date? = nil) -> HomeSnapshot {
        HomeSnapshotBuilder.build(catalog: Fixture.catalog, snapshot: PassportSnapshot(stamps: stamps, wishlist: wishlist), memory: nil,
                                  nearby: nil, installID: install, now: date ?? now, calendar: calendar, dayOverride: override)
    }

    @Test func zeroStampsIsTheFirstRunWithNothingToHide() {
        let home = build([])
        #expect(home.isFirstRun && home.stampCount == 0 && home.sets.isEmpty && !home.showsAtlas)
        #expect(home.featuredID != nil && home.pickIDs.count == 3 && home.latestMemory == nil)
    }

    @Test func countsComeFromRecordsAndWishlistNeverCounts() {
        let home = build([stamp("a", country: "FR"), stamp("b", country: "FR", verified: true), stamp("c", country: "IT")],
                         wishlist: [WishlistEntry(destinationID: "d", addedAt: now)])
        #expect(home.stampCount == 3 && home.countryCount == 2 && home.verifiedCount == 1)
        #expect(home.litCountryCodes == ["FR", "IT"], "a wishlisted JP place does not light the atlas")
        #expect(home.verifiedDestinationIDs == ["b"] && home.showsAtlas)
    }

    @Test func onlyIncompleteStartedSetsAreShownAndCompleteOnesAreHidden() {
        let home = build([stamp("a", country: "FR"), stamp("b", country: "FR"), stamp("c", country: "IT", at: 10)])
        #expect(home.sets.map(\.progress.collection.id) == ["trio"], "duo is complete")
        #expect(home.sets.first?.shownIDs == ["c", "a"], "most recent first")
        #expect(home.sets.first?.extraCount == 0)
    }

    @Test func theFeaturedStampIsNeverAlreadyCollected() {
        for offset in 0..<20 {
            let home = build([stamp("a", country: "FR")], at: now.addingTimeInterval(Double(offset) * 86_400))
            #expect(home.featuredID != "a" && !home.pickIDs.contains("a") && home.sideID != "a")
        }
    }

    @Test func theSameInstallAndDayAlwaysGiveTheSamePicks() {
        let first = build([stamp("a", country: "FR")])
        #expect(first == build([stamp("a", country: "FR")]))
        #expect(first.featuredID != nil && first.sideID != nil && first.sideID != first.featuredID)
    }

    @Test func aNewDayReordersThePool() {
        let days = (0..<8).map { build([], at: now.addingTimeInterval(Double($0) * 86_400)).featuredID }
        #expect(Set(days).count > 1)
    }

    @Test func aDayOverrideSwapsFeaturedAndSideAndIgnoresCollectedChoices() {
        let base = build([])
        let side = try! #require(base.sideID)
        let swapped = build([], override: side)
        #expect(swapped.featuredID == side && swapped.sideID == base.featuredID)
        #expect(build([stamp("a", country: "FR")], override: "a").featuredID != "a")
    }

    @Test func firstRunDefaultsAreUsedWhenTheyExist() {
        let picks = HomeFeaturedPicker.picks(priority: ["x"], rest: [], firstRun: ["p", "k", "s", "r"], seed: 1)
        #expect(picks == HomeFeaturedPicks(featured: "p", side: "k", picks: ["k", "s", "r"]))
    }

    @Test func theSeedIsStableAcrossLaunches() {
        #expect(HomeFeaturedPicker.seed(installID: "abc", day: 1) == HomeFeaturedPicker.seed(installID: "abc", day: 1))
        #expect(HomeFeaturedPicker.seed(installID: "abc", day: 1) != HomeFeaturedPicker.seed(installID: "abc", day: 2))
    }
}

struct HomeNearbyTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func noPermissionOrRecentReadMeansNoRead() {
        #expect(!HomeNearbyFinder.mayRead(authorization: .notDetermined, servicesEnabled: true, lastRead: nil, now: now))
        #expect(!HomeNearbyFinder.mayRead(authorization: .denied, servicesEnabled: true, lastRead: nil, now: now))
        #expect(!HomeNearbyFinder.mayRead(authorization: .authorized, servicesEnabled: false, lastRead: nil, now: now))
        #expect(!HomeNearbyFinder.mayRead(authorization: .authorized, servicesEnabled: true, lastRead: now.addingTimeInterval(-599), now: now))
        #expect(HomeNearbyFinder.mayRead(authorization: .authorized, servicesEnabled: true, lastRead: now.addingTimeInterval(-600), now: now))
        #expect(HomeNearbyFinder.mayRead(authorization: .authorized, servicesEnabled: true, lastRead: nil, now: now))
    }

    @Test func onlyAFreshFixInsideAPlacesRadiusShowsIt() {
        let alpha = Fixture.catalog.destination(id: "a")!
        func reading(lat: Double, lon: Double, age: TimeInterval = 5, accuracy: Double = 20) -> LocationReading {
            LocationReading(latitude: lat, longitude: lon, horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(-age))
        }
        let near = HomeNearbyFinder.nearest(reading: reading(lat: alpha.latitude + 0.001, lon: alpha.longitude), catalog: Fixture.catalog,
                                            collectedIDs: [], now: now)
        #expect(near?.destinationID == "a" && near?.isCollected == false)
        #expect(HomeNearbyFinder.nearest(reading: reading(lat: alpha.latitude + 0.001, lon: alpha.longitude), catalog: Fixture.catalog,
                                         collectedIDs: ["a"], now: now)?.isCollected == true)
        #expect(HomeNearbyFinder.nearest(reading: reading(lat: 0, lon: -150), catalog: Fixture.catalog, collectedIDs: [], now: now) == nil, "out of range")
        #expect(HomeNearbyFinder.nearest(reading: reading(lat: alpha.latitude, lon: alpha.longitude, age: 500), catalog: Fixture.catalog,
                                         collectedIDs: [], now: now) == nil, "stale fix")
        #expect(HomeNearbyFinder.nearest(reading: reading(lat: alpha.latitude, lon: alpha.longitude, accuracy: -1), catalog: Fixture.catalog,
                                         collectedIDs: [], now: now) == nil, "invalid fix")
    }
}
