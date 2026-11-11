import Testing
import Foundation
import SwiftData
import UIKit
@testable import StampQuest

private func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func calendar(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    c.locale = Locale(identifier: "en_US")
    return c
}

private func memory(_ title: String = "", text: String = "", on date: Date, created: Date? = nil, place: String? = nil, stamp: String? = nil,
                    tags: [String] = [], photos: Int = 0) -> MemoryItem {
    MemoryItem(title: title, text: text, eventDate: date, createdAt: created, destinationID: place, stampID: stamp, tags: tags,
               photoFilenames: (0..<photos).map { "p\($0)-\(UUID().uuidString).jpg" })
}

struct MemoryDerivedTests {
    @Test func memoriesSortNewestFirstWithTiesByCreationDate() {
        let older = memory("old", on: utc(2026, 5, 1))
        let tieEarly = memory("early", on: utc(2026, 6, 1), created: utc(2026, 6, 2))
        let tieLate = memory("late", on: utc(2026, 6, 1), created: utc(2026, 6, 3))
        let newest = memory("new", on: utc(2026, 7, 1))
        #expect(MemoryDerived.sorted([older, tieEarly, newest, tieLate]).map(\.title) == ["new", "late", "early", "old"])
        #expect(MemoryDerived.sorted([older, tieEarly, newest, tieLate], oldestFirst: true).map(\.title) == ["old", "early", "late", "new"])
    }

    @Test func monthsGroupByTheEffectiveDateInTheUsersTimeZoneAndAcrossYears() {
        let lateNewYearsEve = utc(2026, 12, 31, 23, 30)
        let items = MemoryDerived.sorted([memory("a", on: lateNewYearsEve), memory("b", on: utc(2026, 12, 15)), memory("c", on: utc(2026, 1, 5))])
        let la = MemoryDerived.sections(items, calendar: calendar("America/Los_Angeles"))
        #expect(la.map(\.id) == ["2026-12", "2026-01"] && la.map(\.count) == [2, 1])
        let tokyo = MemoryDerived.sections(items, calendar: calendar("Asia/Tokyo"))
        #expect(tokyo.map(\.id) == ["2027-01", "2026-12", "2026-01"], "The same instant is the next month in Tokyo")
    }

    @Test func entryShapeFollowsThePhotoCountAndNothingElse() {
        let day = utc(2026, 11, 5)
        #expect(memory(on: day, photos: 0).shape == .note)
        #expect(memory(on: day, photos: 1).shape == .row)
        #expect(memory(on: day, photos: 2).shape == .pair)
        #expect(memory(on: day, photos: 3).shape == .wide)
        #expect(memory(on: day, photos: 9).shape == .wide)
        #expect(memory("Long title", text: "Lots of text", on: day, photos: 2).shape == .pair)
    }

    @Test func theTitleFallsBackToTheFirstSentenceThenTheDate() {
        let cal = calendar("UTC"), day = utc(2026, 11, 5)
        #expect(memory("  Rooftop  ", on: day).displayTitle(calendar: cal, locale: Locale(identifier: "en_US")) == "Rooftop")
        #expect(memory(text: "We found the terrace by accident. Bread, wine.", on: day).displayTitle(calendar: cal, locale: Locale(identifier: "en_US")) == "We found the terrace by accident.")
        #expect(memory(text: "No full stop here", on: day).displayTitle(calendar: cal, locale: Locale(identifier: "en_US")) == "No full stop here")
        #expect(memory(on: day, photos: 1).displayTitle(calendar: cal, locale: Locale(identifier: "en_US")) == "5 November" || memory(on: day, photos: 1).displayTitle(calendar: cal, locale: Locale(identifier: "en_US")) == "November 5")
        #expect(!memory(on: day).displayTitle(calendar: cal).isEmpty, "Never an empty line and never \"Untitled\"")
    }

    @Test func countsAreDerivedFromTheRecords() {
        let day = utc(2026, 11, 5)
        let items = [memory("a", on: day, place: "a"), memory("b", on: day, place: "a"), memory("c", on: day, place: "gone"), memory("d", on: day)]
        #expect(MemoryDerived.memoryCount(items) == 4)
        #expect(MemoryDerived.placeCount(items) == 2, "Distinct places, including one that has left the catalog; no place does not count")
        #expect(MemoryDerived.placeCount([]) == 0)
        #expect(MemoryDerived.placeCount(Array(items.dropLast(3))) == 1)
    }

    @Test func tagsAreTrimmedDeduplicatedAndLimited() {
        #expect(MemoryTags.normalize(["  Food ", "food", "FOOD", "Sunset", ""]) == ["Food", "Sunset"], "First spelling wins, case-insensitive")
        #expect(MemoryTags.normalize(["x"]) == ["x"])
        #expect(MemoryTags.normalize([String(repeating: "a", count: 40)]).first?.count == 24)
        #expect(MemoryTags.normalize((0..<20).map { "tag\($0)" }).count == 8)
    }

    @Test func filterCountsAreOrderedByCountThenAlphabetically() {
        let day = utc(2026, 11, 5)
        let items = [memory(on: day, place: "d", tags: ["Zeta", "food"]), memory(on: day, place: "d", tags: ["Food"]), memory(on: day, place: "a", tags: ["alpha"]),
                     memory(on: day, place: "c", tags: ["Zeta"])]
        let tags = MemoryDerived.tagCounts(items)
        #expect(tags.map(\.tag) == ["food", "Zeta", "alpha"] && tags.map(\.count) == [2, 2, 1], "Food (2) and Zeta (2) tie and go alphabetically; one spelling is kept")
        let places = MemoryDerived.placeCounts(items, catalog: Fixture.catalog)
        #expect(places.map(\.id) == ["d", "a", "c"] && places.first?.count == 2)
    }

    @Test func thePrintsPairTheNewestPhotoWithADifferentPlace() {
        let a = memory("a", on: utc(2026, 11, 5), place: "a", photos: 1)
        let b = memory("b", on: utc(2026, 11, 4), place: "a", photos: 1)
        let c = memory("c", on: utc(2026, 11, 3), place: "b", photos: 1)
        let noPhoto = memory("n", on: utc(2026, 11, 6), photos: 0)
        #expect(MemoryDerived.prints([a, b, c, noPhoto]) == [a.photoFilenames[0], c.photoFilenames[0]])
        #expect(MemoryDerived.prints([a, b]) == [a.photoFilenames[0], b.photoFilenames[0]], "No other place: the next newest with photos")
        #expect(MemoryDerived.prints([a]) == [a.photoFilenames[0]])
        #expect(MemoryDerived.prints([noPhoto]).isEmpty)
    }
}

@MainActor
struct MemoryRecordsTests {
    let container: ModelContainer
    let store: PassportStore
    let photos = RecordingPhotoDeleter()

    init() throws {
        container = try Fixture.container()
        let clock = TickingClock()
        store = PassportStore(context: container.mainContext, catalog: Fixture.catalog, photoFiles: photos, now: { clock() })
    }

    private func draft(_ title: String, place: String? = nil, stamp: String? = nil, photos: [String] = []) -> MemoryDraft {
        var d = MemoryDraft()
        d.title = title
        d.destinationID = place
        d.stampID = stamp
        d.photoFilenames = photos
        return d
    }

    @Test func deletingAMemoryLeavesStampsDestinationsAndTripsAlone() throws {
        try store.collect(destinationID: "a")
        let trip = try store.saveTrip(TripDraft(title: "Spring", destinationIDs: ["a"]))
        var d = draft("Rooftop", place: "a", stamp: StampID.make(for: "a"), photos: ["one.jpg", "two.jpg"])
        d.tripID = trip.id
        let entry = try store.saveMemory(d)
        try store.deleteMemory(entry)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<MemoryEntry>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<UserStamp>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Trip>()) == 1)
        #expect(Fixture.catalog.destination(id: "a") != nil)
        #expect(photos.deleted.sorted() == ["one.jpg", "two.jpg"], "Only this memory's private photo copies are removed")
    }

    @Test func savingOrEditingAMemoryNeverCollectsOrChangesAStamp() throws {
        let entry = try store.saveMemory(draft("At the tower", place: "a", stamp: StampID.make(for: "a")))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<UserStamp>()) == 0, "A memory about a place does not collect it")
        try store.collect(destinationID: "a")
        let before = store.stamp(forDestination: "a")?.collectedAt
        var edited = draft("Other place", place: "b")
        edited.stampID = nil
        try store.saveMemory(edited, replacing: entry)
        #expect(store.stamp(forDestination: "a")?.collectedAt == before)
        #expect(store.state(of: "a") == .collected && store.stamp(forDestination: "a")?.isVerified == false)
        #expect(store.stamp(forDestination: "b") == nil)
    }

    @Test func removedPhotosAreDeletedOnlyAfterTheEditCommits() throws {
        let entry = try store.saveMemory(draft("Photos", photos: ["keep.jpg", "drop.jpg"]))
        try store.saveMemory(draft("Photos", photos: ["keep.jpg"]), replacing: entry)
        #expect(photos.deleted == ["drop.jpg"])
    }

    @Test func aPlaceThatLeftTheCatalogKeepsItsMemoriesReadableAndEditable() throws {
        // A memory written when the place existed; the catalog has since dropped it.
        let stored = MemoryEntry(title: "From a removed place", text: "Still mine.", createdAt: utc(2026, 5, 1), eventDate: utc(2026, 5, 1), destinationID: "no-longer-here")
        container.mainContext.insert(stored)
        try container.mainContext.save()
        let item = MemoryItem(stored)
        #expect(MemoryDerived.placeState(of: item, catalog: Fixture.catalog, snapshot: store.snapshot()) == .removedFromCatalog)
        #expect(item.displayTitle() == "From a removed place")
        #expect(MemoryDerived.memories(forDestination: "no-longer-here", in: [item]).count == 1)

        var edit = draft("Edited title", place: "no-longer-here")
        edit.text = "Still mine."
        try store.saveMemory(edit, replacing: stored)
        #expect(stored.title == "Edited title" && stored.destinationID == "no-longer-here", "Editing keeps the place that left the catalog")
        #expect(throws: PassportError.self) { try store.saveMemory(draft("New", place: "also-gone")) }
        edit.destinationID = nil
        try store.saveMemory(edit, replacing: stored)
        #expect(stored.destinationID == nil, "The place can be cleared")
    }

    @Test func placeStateFollowsTheStampAndOnlyAVerifiedVisitIsVerified() throws {
        let note = memory("n", on: utc(2026, 11, 5), place: "a", stamp: StampID.make(for: "a"))
        func state() -> MemoryPlaceState { MemoryDerived.placeState(of: note, catalog: Fixture.catalog, snapshot: store.snapshot()) }
        #expect(state() == .notInPassport)
        try store.collect(destinationID: "a")
        #expect(state() == .collected, "Collecting by hand is never verified")
        try store.recordVerification(destinationID: "a", verification: Fixture.verification())
        #expect(state() == .verified)
        #expect(MemoryDerived.placeState(of: memory("x", on: utc(2026, 11, 5)), catalog: Fixture.catalog, snapshot: store.snapshot()) == .noPlace)
    }

    @Test func linkedToAStampNeedsTheStampToBeInThePassport() throws {
        let linked = memory("n", on: utc(2026, 11, 5), place: "a", stamp: StampID.make(for: "a"))
        #expect(!MemoryDerived.isLinkedToStamp(linked, snapshot: store.snapshot()))
        try store.collect(destinationID: "a")
        #expect(MemoryDerived.isLinkedToStamp(linked, snapshot: store.snapshot()))
        #expect(!MemoryDerived.isLinkedToStamp(memory("x", on: utc(2026, 11, 5), place: "a"), snapshot: store.snapshot()), "No stamp association")
    }

    @Test func memoriesForADestinationAndAStampAreNewestFirst() {
        let a = memory("a", on: utc(2026, 5, 1), place: "a", stamp: "stamp.a")
        let b = memory("b", on: utc(2026, 6, 1), place: "a", stamp: "stamp.a")
        let c = memory("c", on: utc(2026, 7, 1), place: "b")
        #expect(MemoryDerived.memories(forDestination: "a", in: [a, b, c]).map(\.title) == ["b", "a"])
        #expect(MemoryDerived.memories(forStamp: "stamp.a", in: [a, b, c]).map(\.title) == ["b", "a"])
    }
}

struct MemorySearchTests {
    private func index(_ items: [MemoryItem]) -> MemorySearchIndex { MemorySearchIndex(items: items, catalog: Fixture.catalog, calendar: calendar("UTC"), locale: Locale(identifier: "en_US")) }

    @Test func searchIgnoresCaseDiacriticsSpacesAndHyphens() {
        let m = memory("Café — Crème brûlée", text: "Sweet  evening", on: utc(2026, 11, 5), tags: ["night-out"])
        let idx = index([m])
        for q in ["cafe", "CAFÉ creme", "brulee", "sweet evening", "night out", "night-out", "NIGHT"] { #expect(idx.search(q) == [m.id], "\(q)") }
        #expect(idx.search("zzz").isEmpty && idx.search("   ").isEmpty)
    }

    @Test func rankingIsTitleThenPlaceThenTagThenTextNewestFirstWithinATier() {
        let day = utc(2026, 11, 5)
        let text = memory("Nothing", text: "We walked through alpha lane", on: utc(2026, 11, 9))
        let tag = memory("Other", on: utc(2026, 11, 8), tags: ["Alpha"])
        let place = memory("Third", on: utc(2026, 11, 7), place: "a")
        let titleOld = memory("Alpha morning", on: utc(2026, 1, 1))
        let titleNew = memory("Alpha evening", on: day)
        let ranked = index([text, tag, place, titleOld, titleNew]).search("alpha")
        #expect(ranked == [titleNew.id, titleOld.id, place.id, tag.id, text.id])
    }

    @Test func placeNamesAlternativeNamesAndCountriesAreSearchable() {
        let a = memory("x", on: utc(2026, 11, 5), place: "a")
        let d = memory("y", on: utc(2026, 11, 4), place: "d")
        let idx = index([a, d])
        #expect(idx.search("alpha") == [a.id])
        #expect(idx.search("france") == [a.id])
        #expect(idx.search("japan") == [d.id])
    }

    @Test func aLookupAcrossTwoThousandMemoriesStaysUnderSixteenMilliseconds() {
        let words = ["morning", "river", "market", "train", "island", "temple", "bread", "walk", "rain", "light"]
        let items = (0..<2_000).map { i in
            memory("\(words[i % 10]) \(words[(i / 10) % 10]) \(i)", text: "\(words[(i / 3) % 10]) and \(words[(i / 7) % 10]) near the \(words[(i / 11) % 10])",
                   on: utc(2020 + i % 7, 1 + i % 12, 1 + i % 27), place: ["a", "b", "c", "d"][i % 4], tags: ["tag\(i % 30)", words[i % 10]])
        }
        let idx = index(items)
        for q in ["r", "river", "tem pl", "tag12", "france", "walk 19"] {
            let clock = ContinuousClock()
            var best = Duration.seconds(1)
            for _ in 0..<5 { best = min(best, clock.measure { _ = idx.search(q) }) }
            #expect(best < .milliseconds(16), "\(q) took \(best)")
        }
    }
}

@MainActor
struct MemorySearchModelTests {
    private func model(debounce: Duration = .milliseconds(10), searcher: @escaping MemorySearchModel.Searcher = MemorySearchModel.backgroundSearch,
                       items: [MemoryItem]) -> MemorySearchModel {
        MemorySearchModel(index: MemorySearchIndex(items: items, catalog: Fixture.catalog), debounce: debounce, searcher: searcher, announce: { _ in })
    }

    @Test func typingShowsResultsAfterTheDebounce() async {
        let m = memory("Rooftop", on: utc(2026, 11, 5))
        let model = model(items: [m])
        model.setText("roof")
        #expect(model.phase == .idle, "Nothing runs before the debounce")
        await model.settle()
        #expect(model.phase == .results([m.id]))
    }

    @Test func aStaleResultNeverReplacesANewerOne() async throws {
        let slow = memory("slow one", on: utc(2026, 11, 5)), fast = memory("fast one", on: utc(2026, 11, 4))
        let searcher: MemorySearchModel.Searcher = { index, query in
            if query == "slow" { try? await Task.sleep(for: .milliseconds(250)) }
            return index.search(query)
        }
        let model = model(searcher: searcher, items: [slow, fast])
        model.setText("slow")
        try await Task.sleep(for: .milliseconds(60))
        model.setText("fast")
        await model.settle()
        try await Task.sleep(for: .milliseconds(400))
        #expect(model.phase == .results([fast.id]) && model.answeredQuery == "fast")
    }

    @Test func clearingCancelsAPendingSearchAndNoMatchIsItsOwnState() async throws {
        let model = model(debounce: .milliseconds(80), items: [memory("Rooftop", on: utc(2026, 11, 5))])
        model.setText("roof")
        model.clear()
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.phase == .idle)
        model.run(term: "zqx")
        await model.settle()
        #expect(model.phase == .noResults)
        model.insert("roof")
        try await Task.sleep(for: .milliseconds(60))
        #expect(model.text == "roof" && model.phase == .idle, "Inserting a term does not search")
    }
}

struct MemoryFilterTests {
    let snapshot = PassportSnapshot.empty
    let day = utc(2026, 11, 5)

    private var items: [MemoryItem] {
        [memory("rome-photo", on: day, place: "a", tags: ["Food"], photos: 1), memory("rome-note", on: utc(2026, 11, 4), place: "a", tags: ["Walks"]),
         memory("kyoto-photo", on: utc(2026, 11, 3), place: "d", tags: ["Food", "Early"], photos: 2), memory("loose", on: utc(2026, 11, 2), tags: ["Walks"])]
    }

    @Test func groupsCombineWithAndAndValuesWithinAGroupWithOr() {
        func titles(_ f: MemoryFilter) -> [String] { f.apply(to: items, snapshot: snapshot).map(\.title) }
        #expect(titles(MemoryFilter(placeIDs: ["a"])) == ["rome-photo", "rome-note"])
        #expect(titles(MemoryFilter(placeIDs: ["a", "d"])).count == 3, "OR within a group")
        #expect(titles(MemoryFilter(placeIDs: ["a", "d"], tagKeys: [MemoryTags.key("food")])) == ["rome-photo", "kyoto-photo"], "AND across groups; tag keys are case-insensitive")
        #expect(titles(MemoryFilter(placeIDs: ["a"], hasPhotos: true)) == ["rome-photo"])
        #expect(titles(MemoryFilter(tagKeys: [MemoryTags.key("Walks")], hasPhotos: true)).isEmpty)
        #expect(titles(MemoryFilter()).count == 4)
    }

    @Test func linkedToAStampNeedsAStampInThePassport() {
        let linked = [memory("linked", on: day, place: "a", stamp: StampID.make(for: "a")), memory("plain", on: day, place: "a")]
        #expect(MemoryFilter(linkedToStamp: true).apply(to: linked, snapshot: snapshot).isEmpty, "The stamp is not in the passport")
    }

    @Test func sortIsNotAFilterAndOldestFirstReverses() {
        var filter = MemoryFilter()
        filter.sort = .oldest
        #expect(!filter.isActive && filter.chips.isEmpty && !filter.isDefault)
        #expect(filter.apply(to: items, snapshot: snapshot).map(\.title).first == "loose")
        #expect(MemoryFilter().isDefault)
    }

    @Test func theCountTheButtonPromisesEqualsTheListAndChipsRemoveWholeGroups() {
        var filter = MemoryFilter(placeIDs: ["a"], tagKeys: [MemoryTags.key("Food")], hasPhotos: true, linkedToStamp: false)
        #expect(filter.apply(to: items, snapshot: snapshot).count == 1)
        #expect(filter.chips == [.places, .tags, .photos])
        filter.remove(.tags)
        #expect(filter.tagKeys.isEmpty && filter.chips == [.places, .photos])
        filter.clearFilters()
        #expect(!filter.isActive)
    }

    @Test func filtersAreNotPersisted() {
        #expect(!MemoryFilter().isActive)
        let keys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.lowercased().contains("memoryfilter") || $0.lowercased().contains("memory.filter") }
        #expect(keys.isEmpty)
    }
}

@MainActor
struct MemoryPhotoPipelineTests {
    private func tempStore() -> (PhotoStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("memory-photos-\(UUID().uuidString)")
        return (PhotoStore(directory: dir), dir)
    }

    private func jpeg(width: Int, height: Int) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
            .jpegData(withCompressionQuality: 0.8) { ctx in UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height)) }
    }

    @Test func importedPhotosAreDownsampledTo2048AndStoredInTheContainer() async throws {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let name = try await store.importPhoto(data: jpeg(width: 4_000, height: 3_000))
        #expect(store.exists(name))
        let source = try #require(CGImageSourceCreateWithURL(store.url(for: name) as CFURL, nil))
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0, h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        #expect(max(w, h) == 2_048)
    }

    @Test func anUnreadablePhotoFailsAndLeavesNoFile() async throws {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        await #expect(throws: PhotoStoreError.self) { _ = try await store.importPhoto(data: Data("not an image".utf8)) }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        #expect(files.isEmpty)
    }

    @Test func aMissingPhotoYieldsNothingInsteadOfCrashing() async {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(await store.thumbnail(for: "missing.jpg", maxPixel: 200) == nil)
    }

    @Test func thumbnailsAreDecodedAtDisplaySizeNotFullSize() async throws {
        let (store, dir) = tempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let name = try await store.importPhoto(data: jpeg(width: 3_000, height: 2_000))
        let thumb = try #require(await store.thumbnail(for: name, maxPixel: 200))
        #expect(max(thumb.size.width * thumb.scale, thumb.size.height * thumb.scale) <= 200)
    }
}

@MainActor
struct MemoriesViewModelTests {
    let env: AppEnvironment
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("memories-vm-\(UUID().uuidString)")

    init() throws {
        env = AppEnvironment(catalog: Fixture.catalog, container: try Fixture.container(),
                             preferences: PreferencesStore(defaults: UserDefaults(suiteName: "memories-vm-\(UUID().uuidString)")!),
                             locationProvider: MockLocationProvider(), photos: PhotoStore(directory: dir))
    }

    @Test func deletingRemovesOnlyTheMemoryAndShowsAToast() throws {
        try env.store.collect(destinationID: "a")
        var d = MemoryDraft(); d.title = "Goodbye"; d.destinationID = "a"
        let entry = try env.store.saveMemory(d)
        let model = MemoriesViewModel(env: env)
        #expect(model.delete(entry.id))
        #expect(model.entry(entry.id) == nil && env.toasts.current?.message == "Memory deleted")
        #expect(env.toasts.current?.undo == nil, "No Undo: the confirmation stated the scope")
        #expect(env.store.state(of: "a") == .collected)
    }

    @Test func recentMemorySearchesAreCaseInsensitiveNewestFirstCappedAndClearUndoRestores() {
        let model = MemoriesViewModel(env: env)
        for term in ["a", "b", "c", "d", "e", "f"] { model.noteSearch(term) }
        model.noteSearch("  D ")
        #expect(env.preferences.recentMemorySearches == ["D", "f", "e", "c", "b"], "Newest first, one spelling per term, capped at 5")
        let before = env.preferences.recentMemorySearches
        model.clearRecentSearches()
        #expect(env.preferences.recentMemorySearches.isEmpty && env.toasts.current?.message == "Cleared")
        env.toasts.undo()
        #expect(env.preferences.recentMemorySearches == before)
    }

    @Test func memoriesSurviveARelaunchOfTheStore() throws {
        var d = MemoryDraft(); d.title = "Still here"; d.photoFilenames = ["x.jpg"]
        _ = try env.store.saveMemory(d)
        let fresh = PassportStore(context: env.container.mainContext, catalog: Fixture.catalog)
        let entries = try fresh.context.fetch(FetchDescriptor<MemoryEntry>())
        #expect(entries.map(\.title) == ["Still here"] && entries.first?.photoFilenames == ["x.jpg"])
    }
}
