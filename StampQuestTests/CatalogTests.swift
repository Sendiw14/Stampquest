import Testing
import Foundation
@testable import StampQuest

struct CatalogLoaderTests {
    func build(_ dests: [String], collections: String = "") throws -> Catalog {
        try CatalogLoader.build(metaData: Data(Fixture.metaJSON(collections: collections).utf8),
                                destinationFiles: [Fixture.filesJSON(dests)])
    }

    @Test func invalidRecordsAreDroppedWithoutLosingTheRest() throws {
        let catalog = try build([
            Fixture.destinationJSON(id: "ok"),
            Fixture.destinationJSON(id: "badlat", lat: 123),
            Fixture.destinationJSON(id: "null-island", lat: 0, lon: 0),
            Fixture.destinationJSON(id: "badcountry", country: "ZZZ"),
            Fixture.destinationJSON(id: "badpalette", palette: "nope"),
            Fixture.destinationJSON(id: "badmotif", motif: "spaceship"),
            Fixture.destinationJSON(id: "badregion", region: "atlantis"),
            Fixture.destinationJSON(id: "badradius", radius: "\"verificationRadius\": 5,"),
            Fixture.destinationJSON(id: "ok"),
        ])
        #expect(catalog.destinations.map(\.id) == ["ok"])
        #expect(catalog.issues.count == 8)
        #expect(catalog.issues.contains { $0.recordID == "ok" && $0.message.contains("Duplicate") })
    }

    @Test func collectionReferencesToMissingDestinationsAreDropped() throws {
        let catalog = try build([Fixture.destinationJSON(id: "a"), Fixture.destinationJSON(id: "b")], collections: [
            Fixture.collectionJSON(id: "mixed", destinations: ["a", "ghost", "b"]),
            Fixture.collectionJSON(id: "empty", destinations: ["ghost"]),
        ].joined(separator: ","))
        #expect(catalog.collections.map(\.id) == ["mixed"])
        #expect(catalog.collection(id: "mixed")?.destinationIDs == ["a", "b"])
        // One unknown reference in "mixed", plus an unknown reference and a dropped-collection notice for "empty".
        #expect(catalog.issues.count == 3)
    }

    @Test func emptyOrUnsupportedCatalogsThrow() {
        #expect(throws: CatalogError.empty) { try build([Fixture.destinationJSON(id: "x", lat: 999)]) }
        #expect(throws: CatalogError.unsupportedSchema(9)) {
            try CatalogLoader.build(metaData: Data(Fixture.metaJSON(collections: "", schema: 9).utf8), destinationFiles: [])
        }
        #expect(throws: CatalogError.self) {
            try CatalogLoader.build(metaData: Data("not json".utf8), destinationFiles: [])
        }
    }

    @Test func derivedCountriesAreUniqueAndSorted() {
        let countries = Fixture.catalog.countries
        #expect(countries.count == 5)
        #expect(countries.first { $0.code == "FR" }?.destinationIDs.sorted() == ["a", "b"])
    }
}

struct BundledCatalogTests {
    @Test func theShippedCatalogLoadsCleanly() throws {
        let catalog = try CatalogLoader.load()
        #expect(catalog.issues.isEmpty, "Issues: \(catalog.issues.map(\.message))")
        #expect(catalog.destinations.count >= 50)
        #expect(catalog.collections.count >= 8)
        #expect(Set(catalog.destinations.map(\.id)).count == catalog.destinations.count)
        #expect(catalog.stamps.count == catalog.destinations.count)
    }

    @Test func everyDestinationIsWellFormed() throws {
        let catalog = try CatalogLoader.load()
        for d in catalog.destinations {
            #expect(CountryInfo.isValid(d.countryCode), "\(d.id) country")
            #expect((-90...90).contains(d.latitude) && (-180...180).contains(d.longitude), "\(d.id) coordinates")
            #expect(d.summary.count >= 20 && d.story.count >= 80, "\(d.id) copy")
            let stamp = try #require(catalog.stamp(forDestination: d.id), "\(d.id) has no stamp")
            #expect(stamp.id == d.stampID)
            #expect(!stamp.accessibilityDescription.isEmpty)
            #expect(ArtColors(palette: stamp.artwork.palette) != nil, "\(d.id) palette")
        }
    }

    @Test func catalogCoversAllRegionsAndMostCategories() throws {
        let catalog = try CatalogLoader.load()
        #expect(Set(catalog.destinations.map(\.region)) == Set(Region.allCases))
        #expect(Set(catalog.destinations.map(\.category)).count >= 9)
    }

    @Test func everyCollectionMemberExists() throws {
        let catalog = try CatalogLoader.load()
        for c in catalog.collections {
            #expect(c.destinationIDs.count >= 2)
            for id in c.destinationIDs { #expect(catalog.destination(id: id) != nil, "\(c.id) → \(id)") }
        }
    }

    @Test func verificationRadiiAreSensiblePerPlace() throws {
        let catalog = try CatalogLoader.load()
        let park = try #require(catalog.destination(id: "grand-canyon"))
        let tower = try #require(catalog.destination(id: "paris-eiffel-tower"))
        #expect(park.verificationRadius > tower.verificationRadius * 10, "A national park needs a far wider radius than a single monument")
    }
}

struct CatalogSearchTests {
    let catalog: Catalog

    init() throws { catalog = try CatalogLoader.load() }

    func ids(_ q: String) -> [String] { catalog.search(q).map(\.id) }

    @Test func emptyQueryReturnsEverything() { #expect(ids("").count == catalog.destinations.count && ids("   ").count == catalog.destinations.count) }

    @Test func findsByNameLandmarkAndAlternativeName() {
        #expect(ids("paris").prefix(2).allSatisfy { $0.hasPrefix("paris") })
        #expect(ids("eiffel").first == "paris-eiffel-tower")
        #expect(ids("Kız Kulesi").first == "istanbul-maidens-tower")
        #expect(ids("sagrada familia").first == "barcelona-sagrada-familia")
    }

    @Test func ignoresCaseAccentsAndPunctuation() {
        #expect(ids("reykjavik").first == "reykjavik-hallgrimskirkja")
        #expect(ids("REYKJAVÍK!").first == "reykjavik-hallgrimskirkja")
        #expect(ids("chichen itza").first == "chichen-itza")
        #expect(ids("iguazu").first == "iguazu-falls")
    }

    @Test func findsByCountryRegionCategoryAndKeyword() {
        #expect(ids("japan").contains("kyoto-fushimi-inari"))
        #expect(Set(ids("japan")).isSuperset(of: ["tokyo-tower", "mount-fuji"]))
        #expect(ids("oceania").contains("sydney-opera-house"))
        #expect(ids("waterfall").contains("victoria-falls"))
        #expect(ids("national park").contains("grand-canyon"))
    }

    @Test func multipleWordsNarrowTheResults() {
        let both = ids("japan shrine")
        #expect(both.first == "kyoto-fushimi-inari")
        #expect(!both.contains("sydney-opera-house"))
    }

    @Test func nonsenseFindsNothing() { #expect(ids("zzzzqqq").isEmpty) }

    @Test func exactNameOutranksIncidentalMentions() {
        #expect(ids("rome").first == "rome-colosseum")
    }
}
