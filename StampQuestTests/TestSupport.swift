import Foundation
import SwiftData
@testable import StampQuest

/// Deterministic fixtures shared by the unit tests.
enum Fixture {
    static func destinationJSON(
        id: String, name: String = "Place", country: String = "FR", region: String = "europe",
        category: String = "landmark", lat: Double = 48.85, lon: Double = 2.29,
        motif: String = "eiffel", palette: String = "goldenHour", radius: String = "", keywords: String = "\"test\""
    ) -> String {
        """
        {"id":"\(id)","name":"\(name)","landmark":"\(name) Landmark","country":"\(country)","region":"\(region)",
         "category":"\(category)","lat":\(lat),"lon":\(lon),\(radius)
         "summary":"A summary that is long enough.","story":"A story that is definitely long enough to pass validation.",
         "keywords":[\(keywords)],"altNames":[],
         "stamp":{"motif":"\(motif)","palette":"\(palette)","alt":"Illustration of \(name)."}}
        """
    }

    static func metaJSON(collections: String, schema: Int = 1) -> String {
        """
        {"schemaVersion":\(schema),"version":"test.1","destinationFiles":[],"collections":[\(collections)]}
        """
    }

    static func collectionJSON(id: String, destinations: [String], cover: String? = nil) -> String {
        let list = destinations.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"id":"\(id)","title":"\(id.capitalized)","subtitle":"s","summary":"summary","symbol":"star",
         "cover":"\(cover ?? destinations.first ?? "x")","destinations":[\(list)]}
        """
    }

    static func filesJSON(_ destinations: [String]) -> Data {
        Data("{\"destinations\":[\(destinations.joined(separator: ","))]}".utf8)
    }

    /// Six destinations in five countries and two collections.
    static let catalog: Catalog = {
        let dests = [
            destinationJSON(id: "a", name: "Alpha", country: "FR", lat: 48.85, lon: 2.29, keywords: "\"tower\""),
            destinationJSON(id: "b", name: "Bravo", country: "FR", lat: 43.29, lon: 5.37),
            destinationJSON(id: "c", name: "Charlie", country: "IT", category: "city", lat: 41.89, lon: 12.49),
            destinationJSON(id: "d", name: "Delta", country: "JP", region: "asia", lat: 35.65, lon: 139.74),
            destinationJSON(id: "e", name: "Echo", country: "US", region: "northAmerica", lat: 40.68, lon: -74.04),
            destinationJSON(id: "f", name: "Foxtrot", country: "AU", region: "oceania", lat: -33.85, lon: 151.21),
        ]
        let meta = metaJSON(collections: [
            collectionJSON(id: "duo", destinations: ["a", "b"]),
            collectionJSON(id: "trio", destinations: ["a", "c", "d"]),
        ].joined(separator: ","))
        // swiftlint:disable:next force_try
        return try! CatalogLoader.build(metaData: Data(meta.utf8), destinationFiles: [filesJSON(dests)])
    }()

    static func container() throws -> ModelContainer {
        try PersistenceController.makeContainer(inMemory: true)
    }

    static func verification(at date: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> VisitVerification {
        VisitVerification(id: UUID(), verifiedAt: date, distanceMeters: 42, horizontalAccuracyMeters: 12,
                          radiusMeters: 600, policyVersion: 1)
    }
}

/// A clock that advances by one day each time it is read.
final class TickingClock {
    private var current = Date(timeIntervalSince1970: 1_700_000_000)
    func callAsFunction() -> Date {
        defer { current = current.addingTimeInterval(86_400) }
        return current
    }
}

final class RecordingPhotoDeleter: PhotoFileDeleting {
    var deleted: [String] = []
    func deletePhotos(named filenames: [String]) { deleted.append(contentsOf: filenames) }
}
