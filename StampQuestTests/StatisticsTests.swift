import Testing
import Foundation
@testable import StampQuest

struct StatisticsTests {
    let day = 86_400.0
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func stamp(_ dest: String, country: String, day d: Double, verified: Bool = false, favorite: Bool = false) -> CollectedStamp {
        CollectedStamp(stampID: "stamp.\(dest)", destinationID: dest, countryCode: country, title: dest,
                       collectedAt: t0.addingTimeInterval(d * day),
                       verifiedAt: verified ? t0.addingTimeInterval(d * day) : nil, isFavorite: favorite)
    }

    @Test func statisticsAreDerivedFromRecordsOnly() {
        let snapshot = PassportSnapshot(
            stamps: [stamp("a", country: "FR", day: 0, verified: true), stamp("b", country: "FR", day: 1), stamp("d", country: "JP", day: 2)],
            wishlist: [WishlistEntry(destinationID: "c", addedAt: t0), WishlistEntry(destinationID: "a", addedAt: t0)],
            memoryCount: 2, tripCount: 1)
        let stats = PassportStatistics.compute(from: snapshot, catalog: Fixture.catalog)
        #expect(stats.collectedStamps == 3)
        #expect(stats.verifiedVisits == 1)
        #expect(stats.countriesCollected == 2)
        #expect(stats.destinationsCollected == 3)
        #expect(stats.wishlistCount == 1, "A wishlist entry for an already collected place is not counted")
        #expect(stats.regionsExplored == 2)
        #expect(stats.memories == 2 && stats.trips == 1)
    }

    @Test func duplicateRecordsForOneDestinationCountOnce() {
        let snapshot = PassportSnapshot(stamps: [stamp("a", country: "FR", day: 3), stamp("a", country: "FR", day: 0)])
        #expect(snapshot.stamps.count == 1)
        #expect(snapshot.collectedStamp(forDestination: "a")?.collectedAt == t0, "The earliest record wins")
    }

    @Test func collectedStampWinsOverWishlistInState() {
        let snapshot = PassportSnapshot(stamps: [stamp("a", country: "FR", day: 0)],
                                        wishlist: [WishlistEntry(destinationID: "a", addedAt: t0), WishlistEntry(destinationID: "c", addedAt: t0)])
        #expect(snapshot.state(of: "a") == .collected)
        #expect(snapshot.state(of: "c") == .wishlisted)
        #expect(snapshot.state(of: "e") == .notCollected)
    }

    // MARK: Collections

    @Test func collectionCompletesOnlyWhenEveryMemberIsCollected() throws {
        let duo = try #require(Fixture.catalog.collection(id: "duo"))
        let partial = CollectionProgress.make(for: duo, snapshot: PassportSnapshot(stamps: [stamp("a", country: "FR", day: 0)]))
        #expect(partial.collected == 1 && partial.total == 2)
        #expect(!partial.isComplete && partial.completedAt == nil)
        #expect(partial.missingIDs == ["b"])

        let full = CollectionProgress.make(for: duo, snapshot: PassportSnapshot(stamps: [stamp("a", country: "FR", day: 0), stamp("b", country: "FR", day: 5)]))
        #expect(full.isComplete)
        #expect(full.completedAt == t0.addingTimeInterval(5 * day), "Completion date is when the last stamp was collected")
    }

    @Test func wishlistingDoesNotAdvanceCollectionProgress() throws {
        let duo = try #require(Fixture.catalog.collection(id: "duo"))
        let progress = CollectionProgress.make(for: duo, snapshot: PassportSnapshot(stamps: [], wishlist: [WishlistEntry(destinationID: "a", addedAt: t0)]))
        #expect(progress.collected == 0)
    }

    // MARK: Achievements

    @Test func achievementsUnlockFromRecordsAndCarryTheQualifyingDate() {
        let stamps = (0..<5).map { stamp(["a", "b", "c", "d", "e"][$0], country: ["FR", "FR", "IT", "JP", "US"][$0], day: Double($0)) }
        let snapshot = PassportSnapshot(stamps: stamps)
        let result = AchievementEvaluator.evaluate(snapshot: snapshot, catalog: Fixture.catalog)
        func get(_ k: Achievement.Kind) -> Achievement { result.first { $0.kind == k }! }

        #expect(get(.firstStamp).unlockedAt == t0)
        #expect(get(.fiveDestinations).unlockedAt == t0.addingTimeInterval(4 * day))
        #expect(get(.tenDestinations).unlockedAt == nil)
        #expect(get(.tenDestinations).current == 5)
        #expect(get(.threeCountries).unlockedAt == t0.addingTimeInterval(3 * day), "Third country (JP) arrived on day 3")
        #expect(get(.threeRegions).unlockedAt == t0.addingTimeInterval(4 * day), "Europe, Asia, then North America on day 4")
        #expect(get(.firstVerifiedVisit).unlockedAt == nil)
        #expect(get(.firstMemory).unlockedAt == nil)
    }

    @Test func achievementsAreNotAwardedForWishlistOrDuplicates() {
        let snapshot = PassportSnapshot(stamps: [stamp("a", country: "FR", day: 0), stamp("a", country: "FR", day: 1)],
                                        wishlist: (0..<10).map { WishlistEntry(destinationID: "w\($0)", addedAt: t0) })
        let result = AchievementEvaluator.evaluate(snapshot: snapshot, catalog: Fixture.catalog)
        #expect(result.first { $0.kind == .fiveDestinations }?.unlockedAt == nil)
        #expect(result.filter(\.isUnlocked).count == 1)
    }

    @Test func removingTheQualifyingRecordRevokesTheAchievement() {
        let with = PassportSnapshot(stamps: [stamp("a", country: "FR", day: 0)])
        #expect(AchievementEvaluator.evaluate(snapshot: with, catalog: Fixture.catalog).first { $0.kind == .firstStamp }?.isUnlocked == true)
        let without = PassportSnapshot(stamps: [])
        #expect(AchievementEvaluator.evaluate(snapshot: without, catalog: Fixture.catalog).first { $0.kind == .firstStamp }?.isUnlocked == false)
    }

    // MARK: Query

    @Test func sortingAndFilteringChangeTheDataSet() {
        let stamps = [
            stamp("a", country: "FR", day: 0, verified: true), stamp("c", country: "IT", day: 1, favorite: true),
            stamp("d", country: "JP", day: 2), stamp("b", country: "FR", day: 3),
        ]
        var query = PassportQuery()
        #expect(query.apply(to: stamps, catalog: Fixture.catalog).map(\.destinationID) == ["b", "d", "c", "a"])

        query.sort = .alphabetical
        #expect(query.apply(to: stamps, catalog: Fixture.catalog).map(\.destinationID) == ["a", "b", "c", "d"])

        query.sort = .verifiedFirst
        #expect(query.apply(to: stamps, catalog: Fixture.catalog).first?.destinationID == "a")

        query.sort = .favoritesFirst
        #expect(query.apply(to: stamps, catalog: Fixture.catalog).first?.destinationID == "c")

        query = PassportQuery(onlyVerified: true)
        #expect(query.apply(to: stamps, catalog: Fixture.catalog).map(\.destinationID) == ["a"])
        #expect(query.activeFilterCount == 1)

        query = PassportQuery(countryCodes: ["FR"])
        #expect(Set(query.apply(to: stamps, catalog: Fixture.catalog).map(\.destinationID)) == ["a", "b"])

        query = PassportQuery(collectionIDs: ["trio"])
        #expect(Set(query.apply(to: stamps, catalog: Fixture.catalog).map(\.destinationID)) == ["a", "c", "d"])

        query = PassportQuery(searchText: "charlie")
        #expect(query.apply(to: stamps, catalog: Fixture.catalog).map(\.destinationID) == ["c"])
    }

    @Test func groupingProducesLabelledSections() {
        let stamps = [stamp("a", country: "FR", day: 0), stamp("b", country: "FR", day: 1), stamp("d", country: "JP", day: 2)]
        let byCountry = PassportGrouping.country.sections(for: stamps, catalog: Fixture.catalog) { _ in nil }
        #expect(byCountry.count == 2)
        #expect(byCountry.map(\.stamps.count).sorted() == [1, 2])
        let byCollection = PassportGrouping.collection.sections(for: stamps, catalog: Fixture.catalog) { _ in nil }
        #expect(byCollection.map(\.id) == ["duo", "trio"])
    }
}

struct DestinationFilterTests {
    let catalog = Fixture.catalog

    func matches(_ filter: DestinationFilter, _ id: String, state: StampState = .notCollected) -> Bool {
        filter.matches(catalog.destination(id: id)!, state: state, catalog: catalog)
    }

    @Test func emptyFilterMatchesEverything() {
        let filter = DestinationFilter()
        #expect(!filter.isActive && filter.activeCount == 0)
        #expect(catalog.destinations.allSatisfy { filter.matches($0, state: .notCollected, catalog: catalog) })
    }

    @Test func filtersCombineAsAnd() {
        let filter = DestinationFilter(categories: [.city], regions: [.europe])
        #expect(matches(filter, "c"))
        #expect(!matches(filter, "a"), "a is a landmark")
        #expect(!matches(DestinationFilter(categories: [.city], regions: [.asia]), "c"))
        #expect(filter.activeCount == 2)
    }

    @Test func stateAndCollectionAndCountryFiltersWork() {
        #expect(matches(DestinationFilter(states: [.collected, .verified]), "a", state: .verified))
        #expect(!matches(DestinationFilter(states: [.collected, .verified]), "a", state: .wishlisted))
        #expect(matches(DestinationFilter(collectionID: "duo"), "b"))
        #expect(!matches(DestinationFilter(collectionID: "duo"), "d"))
        #expect(matches(DestinationFilter(countryCodes: ["JP"]), "d"))
        #expect(!matches(DestinationFilter(countryCodes: ["JP"]), "a"))
    }

    @Test func regionGroupingMakesOnePagePerRegionInCatalogOrder() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        func stamp(_ id: String, _ country: String) -> CollectedStamp {
            CollectedStamp(stampID: "stamp.\(id)", destinationID: id, countryCode: country, title: id, collectedAt: t0)
        }
        let sections = PassportGrouping.region.sections(for: [stamp("d", "JP"), stamp("a", "FR"), stamp("b", "FR"), stamp("ghost", "ZZ")], catalog: catalog) { _ in nil }
        #expect(sections.map(\.id) == ["europe", "asia", "archived"])
        #expect(sections.first?.stamps.count == 2)
        #expect(sections.last?.stamps.map(\.destinationID) == ["ghost"], "Stamps whose destination left the catalogue still get a page")
    }
}
