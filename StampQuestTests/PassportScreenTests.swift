import Testing
import Foundation
import SwiftData
@testable import StampQuest

/// The Passport screen's derived data: the four metrics, sorts, filters, pages, dates and the share export.
struct PassportScreenTests {
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    let day = 86_400.0
    let catalog = Fixture.catalog

    func stamp(_ dest: String, country: String, day d: Double, verified: Bool = false, favorite: Bool = false) -> CollectedStamp {
        CollectedStamp(stampID: "stamp.\(dest)", destinationID: dest, countryCode: country, title: dest, collectedAt: t0.addingTimeInterval(d * day),
                       verifiedAt: verified ? t0.addingTimeInterval(d * day) : nil, isFavorite: favorite)
    }

    var sample: [CollectedStamp] {
        [stamp("a", country: "FR", day: 0, verified: true), stamp("b", country: "FR", day: 3), stamp("c", country: "IT", day: 1, favorite: true),
         stamp("d", country: "JP", day: 2)]
    }

    func ids(_ query: PassportQuery) -> [String] { query.apply(to: sample, catalog: catalog).map(\.destinationID) }

    // MARK: Metrics

    @Test func metricsDescribeTheWholePassport() {
        let m = PassportMetrics.compute(snapshot: PassportSnapshot(stamps: sample), catalog: catalog)
        #expect(m == PassportMetrics(collected: 4, verified: 1, countries: 3, sets: 2))
    }

    @Test func setsCountCollectionsStartedNotCompleted() {
        let one = PassportMetrics.compute(snapshot: PassportSnapshot(stamps: [stamp("b", country: "FR", day: 0)]), catalog: catalog)
        #expect(one.sets == 1, "One stamp of Duo starts it")
        let none = PassportMetrics.compute(snapshot: PassportSnapshot(stamps: [stamp("e", country: "US", day: 0)]), catalog: catalog)
        #expect(none.sets == 0, "A stamp in no collection starts none")
    }

    @Test func aHandCollectedStampIsNeverVerifiedAndFiltersDoNotChangeMetrics() {
        let snapshot = PassportSnapshot(stamps: sample)
        let all = PassportDerived.make(snapshot: snapshot, catalog: catalog, query: PassportQuery())
        let filtered = PassportDerived.make(snapshot: snapshot, catalog: catalog, query: PassportQuery(onlyVerified: true))
        #expect(all.metrics == filtered.metrics)
        #expect(filtered.visible.count == 1 && filtered.hiddenCount == 3)
        #expect(all.all.filter(\.isVerified).count == all.metrics.verified)
    }

    @Test func emptyPassportIsEmptyNotZeroTicket() {
        let derived = PassportDerived.make(snapshot: .empty, catalog: catalog, query: PassportQuery())
        #expect(derived.isEmpty && derived.visible.isEmpty)
    }

    @Test func removingAVerifiedStampLowersTheNumbers() {
        let before = PassportMetrics.compute(snapshot: PassportSnapshot(stamps: sample), catalog: catalog)
        let after = PassportMetrics.compute(snapshot: PassportSnapshot(stamps: sample.filter { $0.destinationID != "d" }), catalog: catalog)
        #expect(after.collected == before.collected - 1)
        #expect(after.countries == before.countries - 1, "Japan's only stamp")
        #expect(after.sets == before.sets, "Trio is still held through a and c")
        let noA = PassportMetrics.compute(snapshot: PassportSnapshot(stamps: sample.filter { $0.destinationID != "a" }), catalog: catalog)
        #expect(noA.verified == 0 && noA.collected == 3)
    }

    // MARK: Sorts

    @Test func eachSortOrdersWithItsTieBreak() {
        #expect(ids(PassportQuery()) == ["b", "d", "c", "a"])
        #expect(ids(PassportQuery(sort: .alphabetical)) == ["a", "b", "c", "d"])
        #expect(ids(PassportQuery(sort: .country)) == ["a", "b", "c", "d"], "France (Alpha, Bravo), Italy, Japan")
        #expect(ids(PassportQuery(sort: .collection)) == ["a", "b", "c", "d"], "Duo first (a, b), then Trio (c, d) by name")
        #expect(ids(PassportQuery(sort: .verifiedFirst)) == ["a", "b", "d", "c"], "Verified first, then newest")
        #expect(ids(PassportQuery(sort: .favoritesFirst)) == ["c", "b", "d", "a"], "Favorites first, then newest")
    }

    // MARK: Filters

    @Test func filtersAndAcrossGroupsAndOrWithinOne() {
        #expect(Set(ids(PassportQuery(countryCodes: ["FR", "JP"]))) == ["a", "b", "d"], "OR within countries")
        #expect(Set(ids(PassportQuery(countryCodes: ["FR", "JP"], collectionIDs: ["trio"]))) == ["a", "d"], "AND across groups")
        #expect(Set(ids(PassportQuery(collectionIDs: ["duo", "trio"]))) == ["a", "b", "c", "d"], "OR within collections")
        #expect(ids(PassportQuery(onlyVerified: true, onlyFavorites: true)).isEmpty, "Verified AND favorite")
        #expect(PassportQuery(onlyVerified: true, countryCodes: ["FR", "IT"]).activeFilterCount == 2, "Groups, not values")
    }

    @Test func chipsListOnePerValueAndRemovalClearsJustThatValue() {
        var query = PassportQuery(onlyVerified: true, countryCodes: ["JP", "FR"], collectionIDs: ["trio"])
        let chips = query.chips(catalog: catalog)
        #expect(chips.map(\.id) == ["verified", "country.FR", "country.JP", "collection.trio"])
        query.remove(.country("FR"))
        #expect(query.countryCodes == ["JP"] && query.onlyVerified)
        query.clearFilters()
        #expect(!query.hasActiveFilters)
    }

    @Test func clearingFiltersKeepsTheSortAndResetRestoresDefaults() {
        var query = PassportQuery(sort: .country, onlyFavorites: true)
        query.clearFilters()
        #expect(query.sort == .country && !query.hasActiveFilters && !query.isDefault)
        #expect(PassportQuery().isDefault)
    }

    @Test func filterListsOnlyShowWhatTheCollectionHolds() {
        let derived = PassportDerived.make(snapshot: PassportSnapshot(stamps: [stamp("b", country: "FR", day: 0), stamp("d", country: "JP", day: 1)]),
                                           catalog: catalog, query: PassportQuery())
        #expect(PassportDerived.countries(in: derived.all).map(\.code) == ["FR", "JP"])
        #expect(PassportDerived.collections(in: derived.all, catalog: catalog).map(\.id) == ["duo", "trio"])
    }

    // MARK: Pages, dates, tilt

    @Test func pagesHoldFourAndAlwaysEndWithAnOpenSlot() {
        func entries(_ n: Int) -> [PassportEntry] {
            (0..<n).map { PassportEntry(stamp: stamp("s\($0)", country: "FR", day: Double($0)), destination: nil, design: nil) }
        }
        #expect(PassportPaging.pages(entries(5)).map(\.count) == [4, 1])
        #expect(PassportPaging.pages(entries(4)).map(\.count) == [4, 0], "A full last page is followed by an empty one")
        #expect(PassportPaging.pages([]).map(\.count) == [0])
    }

    @Test func datesUseTheCurrentYearRuleAndTiltIsByPosition() {
        let locale = Locale(identifier: "en_GB")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(PassportDateText.short(now, now: now, calendar: calendar, locale: locale) == "14 Nov")
        #expect(PassportDateText.short(now.addingTimeInterval(-400 * day), now: now, calendar: calendar, locale: locale).hasSuffix("2022"))
        #expect(PassportTilt.grid(0) == -1.5 && PassportTilt.grid(8) == -1.5 && PassportTilt.grid(2) == -1.0)
    }

    // MARK: Export

    @Test func theShareExportCarriesOnlyStampsCountsAndTheName() {
        let entries = PassportDerived.make(snapshot: PassportSnapshot(stamps: sample), catalog: catalog, query: PassportQuery()).all
        let export = PassportExportModel.make(entries: entries, metrics: PassportMetrics(collected: 4, verified: 1, countries: 3, sets: 2), ownerName: "  Sam ")
        #expect(export.ownerName == "Sam" && export.stampCount == 4 && export.countryCount == 3 && export.items.count == 4)
        let fields = Set(Mirror(reflecting: export).children.compactMap(\.label) + Mirror(reflecting: export.items[0]).children.compactMap(\.label))
        #expect(fields == ["ownerName", "stampCount", "countryCount", "items", "design", "name", "date", "isVerified"], "No note, caption, memory or photo field exists")
    }

    // MARK: Remove and Undo

    @MainActor @Test func removeThenUndoRestoresTheSameRecord() throws {
        let container = try Fixture.container()
        let store = PassportStore(context: container.mainContext, catalog: catalog)
        try store.collect(destinationID: "a")
        try store.setFavorite(destinationID: "a", true)
        let original = try #require(store.stamp(forDestination: "a"))
        let date = original.collectedAt
        let backup = try #require(try store.removeStamp(destinationID: "a"))
        #expect(store.stamp(forDestination: "a") == nil)
        try store.restoreStamp(backup)
        let restored = try #require(store.stamp(forDestination: "a"))
        #expect(restored.collectedAt == date && restored.isFavorite && restored.verification == nil)
    }
}
