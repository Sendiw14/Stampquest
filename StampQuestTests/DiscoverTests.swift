import Testing
import Foundation
import SwiftData
@testable import StampQuest

/// Catalogs built from raw JSON with exactly the fields these tests care about.
enum DiscoverFixture {
    struct Place {
        var id: String
        var name: String
        var landmark: String?
        var country = "FR"
        var region = "europe"
        var category = "landmark"
        var keywords: [String] = []
        var alt: [String] = []
        var featured = false
    }

    static func json(_ p: Place) -> String {
        let list: ([String]) -> String = { "[" + $0.map { "\"\($0)\"" }.joined(separator: ",") + "]" }
        return """
        {"id":"\(p.id)","name":"\(p.name)","landmark":"\(p.landmark ?? p.name)","country":"\(p.country)","region":"\(p.region)",
         "category":"\(p.category)","lat":10.0,"lon":10.0,"featured":\(p.featured),
         "summary":"A summary that is long enough.","story":"A story that is definitely long enough to pass validation.",
         "keywords":\(list(p.keywords)),"altNames":\(list(p.alt)),
         "stamp":{"motif":"eiffel","palette":"goldenHour","alt":"Illustration of \(p.name)."}}
        """
    }

    static func catalog(_ places: [Place], collections: [(id: String, title: String, ids: [String])] = [], version: String = "test.1") -> Catalog {
        let cols = collections.map { c in
            """
            {"id":"\(c.id)","title":"\(c.title)","subtitle":"s","summary":"summary","symbol":"star","cover":"\(c.ids.first ?? "x")",
             "destinations":[\(c.ids.map { "\"\($0)\"" }.joined(separator: ","))]}
            """
        }.joined(separator: ",")
        let meta = "{\"schemaVersion\":1,\"version\":\"\(version)\",\"destinationFiles\":[],\"collections\":[\(cols)]}"
        // swiftlint:disable:next force_try
        return try! CatalogLoader.build(metaData: Data(meta.utf8), destinationFiles: [Fixture.filesJSON(places.map(json))])
    }

    /// Kyoto, Tokyo, Paris, Lima, Cusco: two countries share a region, one place is featured.
    static let world: Catalog = catalog([
        Place(id: "kyoto", name: "Kyoto", landmark: "Fushimi Inari", country: "JP", region: "asia", category: "foodCulture", keywords: ["temples"], alt: ["Kioto"]),
        Place(id: "tokyo", name: "Tokyo", landmark: "Tokyo Tower", country: "JP", region: "asia", category: "city", keywords: ["neon"]),
        Place(id: "paris", name: "Paris", landmark: "Eiffel Tower", country: "FR", category: "city", keywords: ["eiffel"], featured: true),
        Place(id: "machu", name: "Machu Picchu", landmark: "Inca Citadel", country: "PE", region: "southAmerica", category: "landmark", keywords: ["inca"], alt: ["Machu Pikchu"]),
        Place(id: "cusco", name: "Cusco", landmark: "Plaza de Armas", country: "PE", region: "southAmerica", category: "city", keywords: ["inca"]),
        Place(id: "lisbon", name: "Lisbon", landmark: "Belém Tower", country: "PT", category: "city", keywords: ["tram"]),
    ], collections: [
        (id: "icons", title: "World Icons", ids: ["paris", "machu", "kyoto"]),
        (id: "japan", title: "Japan, slowly", ids: ["kyoto", "tokyo"]),
    ])
}

@MainActor
struct DiscoverDerivedTests {
    let container: ModelContainer
    let store: PassportStore
    let catalog = DiscoverFixture.world

    init() throws {
        container = try Fixture.container()
        let clock = TickingClock()
        store = PassportStore(context: container.mainContext, catalog: catalog, now: { clock() })
    }

    private func derived(picks: Set<Interest> = []) -> DiscoverDerived {
        DiscoverDerived.make(catalog: catalog, snapshot: store.snapshot(), recentIDs: [], picks: picks)
    }

    @Test func placesToCollectWishlistAndCollectionCountsFollowTheRecords() throws {
        #expect(derived().placesToCollect.count == 6)
        #expect(derived().collections.first { $0.id == "icons" }?.collectedCount == 0)

        try store.collect(destinationID: "paris")
        try store.collect(destinationID: "kyoto")
        #expect(derived().placesToCollect.count == 4)
        #expect(derived().placesToCollect.contains { $0.id == "paris" } == false)
        #expect(derived().collections.first { $0.id == "icons" }?.collectedCount == 2)
        #expect(derived().collections.first { $0.id == "japan" }?.collectedCount == 1)
        #expect(derived().collections.first { $0.id == "japan" }?.memberCount == 2)

        _ = try store.removeStamp(destinationID: "paris")
        #expect(derived().placesToCollect.count == 5)
        #expect(derived().collections.first { $0.id == "icons" }?.collectedCount == 1)
    }

    @Test func aCollectedPlaceLeavesTheWishlistCount() throws {
        try store.addToWishlist(destinationID: "lisbon")
        try store.addToWishlist(destinationID: "cusco")
        #expect(derived().wishlist.count == 2)
        try store.collect(destinationID: "cusco")
        #expect(derived().wishlist.map(\.destinationID) == ["lisbon"], "Collected wins over saved; a saved place is never counted as collected")
        try store.removeFromWishlist(destinationID: "lisbon")
        #expect(derived().wishlist.isEmpty)
    }

    @Test func wishlistIsNewestSavedFirstAndSavingTwiceDoesNothing() throws {
        #expect(try store.addToWishlist(destinationID: "lisbon"))
        #expect(try store.addToWishlist(destinationID: "cusco"))
        #expect(try store.addToWishlist(destinationID: "cusco") == false)
        #expect(derived().wishlist.map(\.destinationID) == ["cusco", "lisbon"])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<WishlistItem>()) == 2)
    }

    @Test func unsaveThenUndoRestoresTheOriginalSavedDate() throws {
        try store.addToWishlist(destinationID: "lisbon")
        let saved = try #require(store.wishlistDate("lisbon"))
        try store.removeFromWishlist(destinationID: "lisbon")
        #expect(store.wishlistDate("lisbon") == nil)
        #expect(try store.restoreWishlistItem(destinationID: "lisbon", addedAt: saved))
        #expect(store.wishlistDate("lisbon") == saved)
        #expect(try store.restoreWishlistItem(destinationID: "lisbon", addedAt: saved) == false, "Undo twice does nothing")
    }

    @Test func undoNeverShadowsACollectedStamp() throws {
        try store.addToWishlist(destinationID: "lisbon")
        let saved = try #require(store.wishlistDate("lisbon"))
        try store.removeFromWishlist(destinationID: "lisbon")
        try store.collect(destinationID: "lisbon")
        #expect(try store.restoreWishlistItem(destinationID: "lisbon", addedAt: saved) == false)
        #expect(store.state(of: "lisbon") == .collected)
    }

    @Test func aDuplicateCollectCreatesNoSecondRecord() throws {
        try store.collect(destinationID: "paris")
        try store.collect(destinationID: "paris")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<UserStamp>()) == 1)
    }

    @Test func aVerifiedPlaceReadsAsCollectedHere() throws {
        try store.recordVerification(destinationID: "paris", verification: Fixture.verification())
        #expect(StampState.verified.discoverSpoken == StampState.collected.discoverSpoken, "Verification belongs to Passport; Discover never shows it")
        #expect(StampState.wishlisted.discoverSpoken != StampState.collected.discoverSpoken)
    }

    @Test func interestsPutOnboardingPicksFirstThenCatalogOrder() {
        let plain = derived().interests.map(\.category)
        #expect(plain == [.landmark, .city, .foodCulture].sorted { DestinationCategory.allCases.firstIndex(of: $0)! < DestinationCategory.allCases.firstIndex(of: $1)! })
        let picked = derived(picks: [.food]).interests
        #expect(picked.first?.category == .foodCulture && picked.first?.isPick == true)
        #expect(picked.dropFirst().allSatisfy { !$0.isPick })
        #expect(picked.map(\.count).reduce(0, +) == catalog.destinations.count, "Every place belongs to exactly one interest")
    }

    @Test func theEditorsPickIsOneFeaturedPlaceAndStableForTheCatalogVersion() {
        #expect(derived().editorsPick?.id == "paris")
        #expect(derived().fanIDs == ["paris"], "Only one featured place, so the fan has one stamp")
        let none = DiscoverFixture.catalog([.init(id: "a", name: "Alpha")])
        let empty = DiscoverDerived.make(catalog: none, snapshot: .empty, recentIDs: [], picks: [])
        #expect(empty.editorsPick == nil && empty.fanIDs.isEmpty)
    }

    @Test func recentsKeepOnlyKnownPlacesAndShowThree() {
        let d = DiscoverDerived.make(catalog: catalog, snapshot: .empty, recentIDs: ["gone", "paris", "kyoto", "tokyo", "lisbon"], picks: [])
        #expect(d.recents == ["paris", "kyoto", "tokyo"])
    }
}

struct DiscoverSearchTests {
    let index = DiscoverSearchIndex(catalog: DiscoverFixture.world)

    private func placeIDs(_ query: String) -> [String] { index.search(query).places.map(\.destinationID) }

    @Test func normalizationIgnoresCaseDiacriticsSpacesAndHyphens() {
        let machu = ["machu"]
        for query in ["machu picchu", "MACHU PICCHU", "Machu-Picchu", "machu   picchu", "machú picchu", "  machu picchu  "] {
            #expect(placeIDs(query) == machu, "\(query)")
        }
    }

    @Test func alternativeNamesCountriesCategoriesAndKeywordsMatch() {
        #expect(placeIDs("kioto") == ["kyoto"])
        #expect(placeIDs("Machu Pikchu") == ["machu"])
        #expect(Set(placeIDs("japan")) == ["kyoto", "tokyo"])
        #expect(placeIDs("Food & Culture") == ["kyoto"])
        #expect(Set(placeIDs("inca")) == ["machu", "cusco"])
    }

    @Test func landmarksAreSearchedAndPointAtTheirPlace() {
        let hits = index.search("fushimi").landmarks
        #expect(hits.map(\.destinationID) == ["kyoto"] && hits.first?.landmark == "Fushimi Inari")
        #expect(index.search("belem").landmarks.map(\.destinationID) == ["lisbon"])
        #expect(index.search("kyoto").landmarks.isEmpty, "A landmark that only repeats the place name is not a separate result")
    }

    @Test func collectionsMatchByTitleAndByMemberName() {
        let byTitle = index.search("world icons").collections
        #expect(byTitle == [.init(collectionID: "icons", memberName: nil)])
        let byMember = index.search("tokyo").collections
        #expect(byMember == [.init(collectionID: "japan", memberName: "Tokyo")])
    }

    @Test func rankingGoesExactThenPrefixThenWordPrefixThenContainsThenOtherFields() {
        let places = [
            DiscoverFixture.Place(id: "contains", name: "Sunrise Bay Cape"),
            .init(id: "word", name: "Old Bay Harbour"),
            .init(id: "prefix", name: "Bayside"),
            .init(id: "exact", name: "Bay"),
            .init(id: "keyword", name: "Zed", keywords: ["bay"]),
            .init(id: "tie-b", name: "Bayou B"),
            .init(id: "tie-a", name: "Bayou A"),
        ]
        let ranked = DiscoverSearchIndex(catalog: DiscoverFixture.catalog(places)).search("bay").places.map(\.destinationID)
        #expect(ranked.first == "exact")
        #expect(ranked.firstIndex(of: "prefix")! < ranked.firstIndex(of: "word")!)
        #expect(ranked.firstIndex(of: "word")! < ranked.firstIndex(of: "keyword")!)
        #expect(ranked.firstIndex(of: "tie-a")! < ranked.firstIndex(of: "tie-b")!, "Ties break alphabetically")
        #expect(ranked.last == "keyword" || ranked.last == "contains")
    }

    @Test func featuredPlacesGetNoRankingBoost() {
        let places = [
            DiscoverFixture.Place(id: "a-plain", name: "Alpha Cove"),
            .init(id: "b-featured", name: "Beta Cove", featured: true),
        ]
        let ranked = DiscoverSearchIndex(catalog: DiscoverFixture.catalog(places)).search("cove").places.map(\.destinationID)
        #expect(ranked == ["a-plain", "b-featured"], "Alphabetical, with no popularity or featured term")
    }

    @Test func aQueryWithNoMatchReturnsNothingAtAll() {
        #expect(index.search("zqx").isEmpty)
        #expect(index.search("   ").isEmpty)
    }

    @Test func everyIdeaReturnsAtLeastOneResult() {
        let ideas = DiscoverIdeas.make(catalog: DiscoverFixture.world, index: index)
        #expect(!ideas.isEmpty && ideas.count <= 6)
        for idea in ideas { #expect(!index.search(idea).isEmpty, "\(idea)") }
    }

    @Test func aLookupAcrossTwoThousandPlacesStaysUnderSixteenMilliseconds() {
        let words = ["Bay", "Peak", "Harbour", "Falls", "Island", "Temple", "Market", "Garden", "Bridge", "Tower"]
        let places = (0..<2_000).map { i in
            DiscoverFixture.Place(id: "p\(i)", name: "\(words[i % 10]) \(words[(i / 10) % 10]) \(i)", landmark: "\(words[(i / 7) % 10]) of \(i)",
                                  country: ["FR", "JP", "PE", "IT", "US"][i % 5], category: "city", keywords: ["kw\(i % 50)", words[(i / 3) % 10].lowercased()])
        }
        let big = DiscoverSearchIndex(catalog: DiscoverFixture.catalog(places))
        for query in ["b", "bay", "tem pl", "kw12", "japan", "harbour 19"] {
            let clock = ContinuousClock()
            var best = Duration.seconds(1)
            for _ in 0..<5 { best = min(best, clock.measure { _ = big.search(query) }) }
            #expect(best < .milliseconds(16), "\(query) took \(best)")
        }
    }
}

@MainActor
struct DiscoverSearchModelTests {
    private func model(debounce: Duration = .milliseconds(10), searcher: @escaping DiscoverSearchModel.Searcher = DiscoverSearchModel.backgroundSearch) -> DiscoverSearchModel {
        DiscoverSearchModel(catalog: DiscoverFixture.world, debounce: debounce, searcher: searcher, announce: { _ in })
    }

    @Test func typingShowsResultsAfterTheDebounce() async {
        let m = model()
        m.prepare()
        m.setText("kyo")
        #expect(m.phase == .idle, "Nothing runs before the debounce")
        await m.settle()
        guard case .results(let r) = m.phase else { Issue.record("expected results, got \(m.phase)"); return }
        #expect(r.places.map(\.destinationID) == ["kyoto", "tokyo"], "Prefix match first, then the place that only contains the text")
    }

    @Test func aStaleResultNeverReplacesANewerOne() async throws {
        // "slow" answers late, "fast" answers at once. The slow answer must be dropped.
        let searcher: DiscoverSearchModel.Searcher = { index, query in
            if query == "slow" { try? await Task.sleep(for: .milliseconds(250)) }
            return index.search(query == "slow" ? "paris" : "tokyo")
        }
        let m = model(searcher: searcher)
        m.prepare()
        m.setText("slow")
        try await Task.sleep(for: .milliseconds(60))
        m.setText("fast")
        await m.settle()
        try await Task.sleep(for: .milliseconds(400))
        guard case .results(let r) = m.phase else { Issue.record("expected results"); return }
        #expect(r.places.map(\.destinationID) == ["tokyo"])
        #expect(m.answeredQuery == "fast")
    }

    @Test func clearingTheFieldCancelsAPendingSearch() async throws {
        let m = model(debounce: .milliseconds(80))
        m.prepare()
        m.setText("kyoto")
        m.clear()
        try await Task.sleep(for: .milliseconds(200))
        #expect(m.phase == .idle)
    }

    @Test func noMatchIsItsOwnStateAndScopesFilterTheGroups() async {
        let m = model()
        m.prepare()
        m.run(term: "zqx")
        await m.settle()
        #expect(m.phase == .noResults)

        m.run(term: "tokyo")
        await m.settle()
        #expect(!m.results(in: .all).collections.isEmpty && !m.results(in: .places).places.isEmpty)
        #expect(m.results(in: .places).collections.isEmpty && m.results(in: .collections).places.isEmpty)
    }

    @Test func anIndexThatCannotBeOpenedIsAnErrorNeverAnEmptyList() async {
        var fail = true
        let m = DiscoverSearchModel(catalog: DiscoverFixture.world, makeIndex: {
            if fail { throw SearchIndexUnavailable() }
            return DiscoverSearchIndex(catalog: DiscoverFixture.world)
        }, announce: { _ in })
        m.prepare()
        #expect(m.phase == .unavailable)
        m.setText("kyoto")
        #expect(m.phase == .unavailable)
        fail = false
        m.prepare()
        await m.settle()
        guard case .results = m.phase else { Issue.record("Try again should recover, got \(m.phase)"); return }
    }

    @Test func insertingATermDoesNotSearch() async throws {
        let m = model()
        m.prepare()
        m.insert("kyoto")
        try await Task.sleep(for: .milliseconds(80))
        #expect(m.text == "kyoto" && m.phase == .idle)
    }
}

struct DiscoverFilterTests {
    let catalog = DiscoverFixture.world

    private func ids(_ filter: DiscoverFilter, states: [String: StampState] = [:]) -> [String] {
        DiscoverResults.matches(scope: .places, filter: filter, catalog: catalog, state: { states[$0] ?? .notCollected }).map(\.id)
    }

    @Test func groupsCombineWithAndAndValuesWithinAGroupWithOr() {
        #expect(Set(ids(DiscoverFilter(categories: [.city]))) == ["tokyo", "paris", "cusco", "lisbon"])
        #expect(Set(ids(DiscoverFilter(categories: [.city, .foodCulture]))) == ["tokyo", "paris", "cusco", "lisbon", "kyoto"])
        #expect(Set(ids(DiscoverFilter(categories: [.city], regions: [.asia]))) == ["tokyo"])
        #expect(Set(ids(DiscoverFilter(categories: [.city], countryCodes: ["JP", "PE"]))) == ["tokyo", "cusco"])
        #expect(ids(DiscoverFilter(categories: [.landmark], regions: [.asia])).isEmpty)
    }

    @Test func theShowChoices() {
        let states: [String: StampState] = ["paris": .collected, "kyoto": .verified, "lisbon": .wishlisted, "cusco": .wishlisted]
        #expect(ids(DiscoverFilter(show: .all), states: states).count == 6)
        #expect(Set(ids(DiscoverFilter(show: .collected), states: states)) == ["paris", "kyoto"])
        #expect(Set(ids(DiscoverFilter(show: .wishlist), states: states)) == ["lisbon", "cusco"])
        let toCollect = Set(ids(DiscoverFilter(show: .toCollect), states: states))
        #expect(toCollect == ["tokyo", "machu", "lisbon", "cusco"], "To collect includes wishlisted places and excludes anything in the passport")
    }

    @Test func theCountEqualsTheResultsListAndTheChips() {
        let filter = DiscoverFilter(categories: [.city, .landmark], regions: [.southAmerica], countryCodes: ["PE"], show: .toCollect)
        let list = DiscoverResults.matches(scope: .places, filter: filter, catalog: catalog, state: { _ in .notCollected })
        #expect(list.count == DiscoverResults.count(filter: filter, catalog: catalog, state: { _ in .notCollected }))
        #expect(filter.chips.count == filter.activeCount && filter.activeCount == 5)
        var removable = filter
        for chip in filter.chips { removable.remove(chip) }
        #expect(!removable.isActive)
    }

    @Test func resultsAreAToZAndCollectionOrderInsideACollection() {
        let all = DiscoverResults.matches(scope: .places, filter: DiscoverFilter(), catalog: catalog, state: { _ in .notCollected }).map(\.name)
        #expect(all == all.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        let icons = DiscoverResults.matches(scope: .collection("icons"), filter: DiscoverFilter(), catalog: catalog, state: { _ in .notCollected }).map(\.id)
        #expect(icons == ["paris", "machu", "kyoto"])
    }

    @Test func aFreshFilterIsEmptyAndNothingPersistsItsChoices() {
        #expect(!DiscoverFilter().isActive)
        let keys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.lowercased().contains("discover") }
        #expect(keys.isEmpty, "Filters are not persisted: Discover always opens unfiltered")
    }
}

@MainActor
struct DiscoverRecentsTests {
    private func prefs() -> PreferencesStore {
        let defaults = UserDefaults(suiteName: "discover-tests-\(UUID().uuidString)")!
        return PreferencesStore(defaults: defaults)
    }

    @Test func recentSearchesAreCaseInsensitiveNewestFirstAndCappedAtEight() {
        let p = prefs()
        for i in 0..<12 { p.noteSearch("term \(i)") }
        #expect(p.recentSearches.count == PreferencesStore.recentSearchLimit && PreferencesStore.recentSearchLimit == 8)
        p.noteSearch("TERM 9")
        p.noteSearch("  term 9  ")
        #expect(p.recentSearches.first == "term 9")
        #expect(p.recentSearches.filter { $0.lowercased() == "term 9" }.count == 1)
        p.noteSearch("   ")
        #expect(p.recentSearches.count == 8)
    }

    @Test func recentSearchesClearAndUndoRestoreTheSameOrder() {
        let p = prefs()
        ["a", "b", "c"].forEach(p.noteSearch)
        let before = p.recentSearches
        p.clearRecentSearches()
        #expect(p.recentSearches.isEmpty)
        p.restoreRecentSearches(before)
        #expect(p.recentSearches == before && before == ["c", "b", "a"])
    }

    @Test func recentlyViewedIsCappedAtTenAndClearUndoRestores() {
        let p = prefs()
        for i in 0..<15 { p.noteViewed("d\(i)") }
        p.noteViewed("d9")
        #expect(p.recentlyViewed.count == 10 && p.recentlyViewed.first == "d9")
        #expect(Set(p.recentlyViewed).count == 10)
        let before = p.recentlyViewed
        p.clearRecentlyViewed()
        p.restoreRecentlyViewed(before)
        #expect(p.recentlyViewed == before)
    }

    @Test func recentSearchesSurviveARelaunchButNotAReset() {
        let defaults = UserDefaults(suiteName: "discover-tests-\(UUID().uuidString)")!
        let p = PreferencesStore(defaults: defaults)
        p.noteSearch("kyoto")
        #expect(PreferencesStore(defaults: defaults).recentSearches == ["kyoto"])
        p.resetToDefaults()
        #expect(PreferencesStore(defaults: defaults).recentSearches.isEmpty)
    }
}

@MainActor
struct ToastCenterTests {
    @Test func oneToastAtATimeAndANewOneReplacesTheOld() {
        let center = ToastCenter()
        center.show("one")
        center.show("two")
        #expect(center.current?.message == "two")
    }

    @Test func undoRunsOnceAndRemovesTheToast() {
        let center = ToastCenter()
        var runs = 0
        center.show("Saved") { runs += 1 }
        center.undo()
        center.undo()
        #expect(runs == 1 && center.current == nil)
    }

    @Test func aToastGoesAwayByItself() async throws {
        let center = ToastCenter()
        center.duration = .milliseconds(40)
        center.show("Saved") {}
        try await Task.sleep(for: .milliseconds(150))
        #expect(center.current == nil)
    }
}

@MainActor
struct DiscoverViewModelTests {
    let env: AppEnvironment

    init() throws {
        env = AppEnvironment(catalog: DiscoverFixture.world, container: try Fixture.container(),
                             preferences: PreferencesStore(defaults: UserDefaults(suiteName: "discover-vm-\(UUID().uuidString)")!),
                             locationProvider: MockLocationProvider(), photos: PhotoStore())
    }

    @Test func savingTwiceSavesOnceAndShowsOneToastWithUndo() {
        let model = DiscoverViewModel(env: env)
        model.toggleWishlist("lisbon")
        #expect(env.store.state(of: "lisbon") == .wishlisted)
        #expect(env.toasts.current?.message == "Saved to wishlist")
        env.toasts.undo()
        #expect(env.store.state(of: "lisbon") == .notCollected)
    }

    @Test func removingAndUndoingKeepsTheOriginalSavedDate() throws {
        try env.store.addToWishlist(destinationID: "lisbon")
        let saved = try #require(env.store.wishlistDate("lisbon"))
        let model = DiscoverViewModel(env: env)
        model.removeFromWishlist("lisbon")
        #expect(env.store.state(of: "lisbon") == .notCollected && env.toasts.current?.message == "Removed from wishlist")
        env.toasts.undo()
        #expect(env.store.wishlistDate("lisbon") == saved)
    }

    @Test func aCollectedPlaceCannotBeSaved() throws {
        try env.store.collect(destinationID: "paris")
        let model = DiscoverViewModel(env: env)
        model.toggleWishlist("paris")
        #expect(env.store.state(of: "paris") == .collected && env.toasts.current == nil)
    }

    @Test func clearingRecentsShowsClearedAndUndoRestoresThem() {
        ["a", "b", "c"].forEach(env.preferences.noteViewed)
        let model = DiscoverViewModel(env: env)
        model.clearRecentlyViewed()
        #expect(env.preferences.recentlyViewed.isEmpty && env.toasts.current?.message == "Cleared")
        env.toasts.undo()
        #expect(env.preferences.recentlyViewed == ["c", "b", "a"])
    }

    @Test func collectingFromDiscoverSavesOnceAndLeavesTheRevealToTheCollectFlow() {
        let model = DiscoverViewModel(env: env)
        model.collect("paris")
        model.collect("paris")
        #expect(env.store.state(of: "paris") == .collected)
        #expect(env.router.reveal?.destinationID == "paris")
        #expect(env.router.reveal?.isVerified == false, "Collecting by hand is never verified")
    }
}
