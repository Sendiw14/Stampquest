import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import StampQuest

// MARK: - Export privacy

@MainActor
struct ExportTests {
    let container: ModelContainer
    let store: PassportStore

    init() throws {
        container = try Fixture.container()
        store = PassportStore(context: container.mainContext, catalog: Fixture.catalog)
        try store.collect(destinationID: "a")
        try store.setCaption(destinationID: "a", "SECRET CAPTION")
        let trip = try store.saveTrip(TripDraft(title: "Holiday", notes: "SECRET TRIP NOTE", destinationIDs: ["a"]))
        try store.saveMemory(MemoryDraft(title: "Diary", text: "SECRET MEMORY TEXT", destinationID: "a", tripID: trip.id, photoFilenames: ["p.jpg"]))
        try store.addToWishlist(destinationID: "b")
    }

    private func export(_ options: ExportOptions) throws -> (PassportExport, String) {
        let c = container.mainContext
        let export = PassportExporter.make(stamps: try c.fetch(FetchDescriptor<UserStamp>()), wishlist: try c.fetch(FetchDescriptor<WishlistItem>()),
                                           trips: try c.fetch(FetchDescriptor<Trip>()), memories: try c.fetch(FetchDescriptor<MemoryEntry>()),
                                           catalogVersion: "test", options: options)
        return (export, String(bytes: try PassportExporter.encode(export), encoding: .utf8) ?? "")
    }

    @Test func privateContentIsExcludedByDefault() throws {
        let (export, json) = try export(ExportOptions())
        #expect(!json.contains("SECRET"), "No caption, memory text or trip note may leak by default")
        #expect(!json.contains("Diary"))
        #expect(!json.contains("p.jpg"))
        #expect(export.memories == nil && export.memoryCount == 1)
        #expect(export.stamps.count == 1 && export.wishlist.count == 1 && export.trips.count == 1)
        #expect(!export.includesPrivateNotes)
    }

    @Test func privateNotesAreIncludedOnlyOnRequestAndPhotosNever() throws {
        let (export, json) = try export(ExportOptions(includePrivateNotes: true))
        #expect(json.contains("SECRET CAPTION") && json.contains("SECRET TRIP NOTE") && json.contains("SECRET MEMORY TEXT"))
        #expect(!json.contains("p.jpg"), "Photo file names and data are never exported")
        #expect(export.memories?.first?.photoCount == 1)
    }

    @Test func exportRoundTripsThroughJSON() throws {
        let (original, _) = try export(ExportOptions(includePrivateNotes: true))
        let data = try PassportExporter.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PassportExport.self, from: data)
        #expect(decoded.stamps.map(\.destinationID) == original.stamps.map(\.destinationID))
        #expect(decoded.format == "stampquest.passport")
    }
}

// MARK: - Routing

@MainActor
struct RouterTests {
    let router = AppRouter()
    let catalog = Fixture.catalog

    @Test func deepLinksOpenTheRightPlace() {
        #expect(router.open(URL(string: "stampquest://destination/a")!, catalog: catalog))
        #expect(router.selectedTab == .discover && router.path(for: .discover) == [.destination("a")])

        #expect(router.open(URL(string: "stampquest://passport")!, catalog: catalog))
        #expect(router.selectedTab == .passport)

        #expect(router.open(URL(string: "stampquest://collection/duo")!, catalog: catalog))
        #expect(router.path(for: .discover) == [.collection("duo")])

        #expect(router.open(URL(string: "stampquest://stamp/stamp.a")!, catalog: catalog))
        #expect(router.path(for: .passport) == [.stamp("a")])
    }

    @Test func unknownOrMalformedLinksAreRejected() {
        #expect(!router.open(URL(string: "stampquest://destination/ghost")!, catalog: catalog))
        #expect(!router.open(URL(string: "stampquest://nowhere")!, catalog: catalog))
        #expect(!router.open(URL(string: "https://example.com/destination/a")!, catalog: catalog))
        #expect(!router.open(URL(string: "stampquest://collection")!, catalog: catalog))
    }

    @Test func reselectingATabPopsItToRoot() {
        router.push(.destination("a"), on: .discover)
        #expect(router.selectedTab == .discover && !router.path(for: .discover).isEmpty)
        router.select(.discover)
        #expect(router.path(for: .discover).isEmpty)
    }

    @Test func tabsKeepIndependentStacks() {
        router.push(.destination("a"), on: .discover)
        router.push(.statistics, on: .passport)
        router.select(.discover)
        #expect(router.path(for: .passport) == [.statistics])
    }
}

// MARK: - Preferences

@MainActor
struct PreferencesTests {
    func makeDefaults() -> UserDefaults {
        let suite = "sq-prefs-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func defaultsAreSensibleAndChangesPersist() {
        let defaults = makeDefaults()
        let prefs = PreferencesStore(defaults: defaults)
        #expect(prefs.appearance == .system && prefs.hapticsEnabled && prefs.locationVerificationEnabled && !prefs.hasCompletedOnboarding)
        prefs.appearance = .dark
        prefs.hapticsEnabled = false
        prefs.passportStyle = .forest
        prefs.hasCompletedOnboarding = true

        let reloaded = PreferencesStore(defaults: defaults)
        #expect(reloaded.appearance == .dark && !reloaded.hapticsEnabled && reloaded.passportStyle == .forest && reloaded.hasCompletedOnboarding)
    }

    @Test func recentlyViewedIsDeduplicatedOrderedAndCapped() {
        let prefs = PreferencesStore(defaults: makeDefaults())
        for i in 0..<20 { prefs.noteViewed("d\(i)") }
        prefs.noteViewed("d5")
        #expect(prefs.recentlyViewed.count == PreferencesStore.recentLimit)
        #expect(prefs.recentlyViewed.first == "d5")
        #expect(Set(prefs.recentlyViewed).count == prefs.recentlyViewed.count)
    }

    @Test func resetRestoresDefaultsButKeepsOnboardingState() {
        let prefs = PreferencesStore(defaults: makeDefaults())
        prefs.hasCompletedOnboarding = true
        prefs.appearance = .light
        prefs.noteViewed("x")
        prefs.resetToDefaults()
        #expect(prefs.appearance == .system && prefs.recentlyViewed.isEmpty && prefs.hasCompletedOnboarding)
    }
}

// MARK: - Timeline

struct TimelineTests {
    @Test func monthlyCountsIncludeEmptyMonthsAndEndAtThisMonth() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        func stamp(_ y: Int, _ m: Int, _ d: Int, _ id: String) -> CollectedStamp {
            CollectedStamp(stampID: id, destinationID: id, countryCode: "FR", title: id, collectedAt: cal.date(from: DateComponents(year: y, month: m, day: d))!)
        }
        let counts = ActivityTimeline.monthlyCounts(of: [stamp(2026, 10, 1, "a"), stamp(2026, 10, 20, "b"), stamp(2026, 8, 3, "c"), stamp(2024, 1, 1, "old")],
                                                    months: 4, now: now, calendar: cal)
        #expect(counts.count == 4)
        #expect(counts.map(\.stamps) == [0, 1, 0, 2], "Jul, Aug, Sep, Oct; stamps outside the window are ignored")
    }
}

// MARK: - Visual building blocks

@MainActor
struct StampRenderingTests {
    @Test func everyCatalogStampRendersToAnImage() throws {
        let catalog = try CatalogLoader.load()
        for design in catalog.stamps {
            let renderer = ImageRenderer(content: PerforatedStampView(design: design).frame(width: 160))
            renderer.scale = 1
            #expect(renderer.uiImage != nil, "\(design.id) failed to render")
        }
    }

    @Test func everyMotifRendersInEveryVariantWithoutCrashing() {
        for motif in ArtMotif.allCases {
            for variant in 0..<3 {
                let design = StampDesign(id: "t.\(motif.rawValue).\(variant)", destinationID: "t", title: "T", edition: "E",
                                         artwork: .preset(motif, variant: variant), accessibilityDescription: "t")
                let renderer = ImageRenderer(content: PerforatedStampView(design: design).frame(width: 120))
                renderer.scale = 1
                #expect(renderer.uiImage != nil, "\(motif) v\(variant)")
            }
        }
    }

    @Test func rendersAreDeterministic() throws {
        let catalog = try CatalogLoader.load()
        let design = try #require(catalog.stamps.first)
        func png() -> Data? {
            let r = ImageRenderer(content: PerforatedStampView(design: design).frame(width: 140))
            r.scale = 1
            return r.uiImage?.pngData()
        }
        #expect(png() == png(), "Seeded artwork must render identically every time")
    }

    @Test func perforatedShapeFillsItsRectAndIsClosed() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 250)
        let path = PerforatedStampShape().path(in: rect)
        #expect(path.boundingRect.width.isApproximately(200) && path.boundingRect.height.isApproximately(250))
        #expect(PerforatedStampShape().path(in: .zero).isEmpty)
        // 10 notches across the width and 12-13 down the height, each made of two Bézier curves.
        var curves = 0
        path.forEach { if case .curve = $0 { curves += 1 } }
        #expect(curves >= 2 * 2 * (10 + 12))
    }

    @Test func stampAspectRatioIsConsistent() {
        #expect(StampMetrics.aspectRatio == 0.8)
    }
}

private extension CGFloat {
    func isApproximately(_ other: CGFloat, tolerance: CGFloat = 0.5) -> Bool { abs(self - other) <= tolerance }
}

// MARK: - Colour & contrast

struct ColorContrastTests {
    @Test func brandPaletteTextPairsMeetWCAGAA() {
        func contrast(_ a: UInt32, _ b: UInt32) -> Double {
            let la = RGB(hexString: String(format: "%06X", a))!.luminance
            let lb = RGB(hexString: String(format: "%06X", b))!.luminance
            return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
        }
        // Light appearance
        #expect(contrast(0x252724, 0xF7F2E8) >= 7, "Primary text on paper")
        #expect(contrast(0x5C5B54, 0xF7F2E8) >= 4.5, "Secondary text on paper")
        #expect(contrast(0x5C5B54, 0xEDE3D2) >= 4.5, "Secondary text on cream")
        #expect(contrast(0x6B685F, 0xF7F2E8) >= 4.5, "Tertiary text on paper")
        #expect(contrast(0x934B2B, 0xF7F2E8) >= 4.5, "Accent text on paper")
        #expect(contrast(0xFBF7EE, 0xA05A38) >= 4.5, "Button label on accent fill")
        // Dark appearance
        #expect(contrast(0xF2EDE2, 0x1B1C1A) >= 7, "Primary text on dark paper")
        #expect(contrast(0xBDB8AC, 0x1B1C1A) >= 4.5, "Secondary text on dark paper")
        #expect(contrast(0x9E9A8F, 0x1B1C1A) >= 4.5, "Tertiary text on dark paper")
        #expect(contrast(0xE3A07E, 0x1B1C1A) >= 4.5, "Accent text on dark paper")
        #expect(contrast(0x1B1C1A, 0xD98B66) >= 4.5, "Button label on dark accent fill")
        // Status colours used as text
        #expect(contrast(0x3A6B4B, 0xF7F2E8) >= 4.5, "Success on paper")
        #expect(contrast(0xB03A2A, 0xF7F2E8) >= 4.5, "Error on paper")
        #expect(contrast(0x86BB98, 0x1B1C1A) >= 4.5, "Success on dark")
        #expect(contrast(0xF28C7A, 0x1B1C1A) >= 4.5, "Error on dark")
    }
}
