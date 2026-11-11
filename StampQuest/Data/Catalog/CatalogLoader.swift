import Foundation

nonisolated enum CatalogError: Error, LocalizedError, Equatable {
    case missingResource(String)
    case unreadable(String)
    case unsupportedSchema(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): "The catalog file “\(name)” is missing from the app."
        case .unreadable(let detail): "The catalog could not be read. \(detail)"
        case .unsupportedSchema(let v): "The catalog uses an unsupported format (version \(v))."
        case .empty: "The catalog contains no valid destinations."
        }
    }
}

// MARK: - Raw JSON shapes

nonisolated struct CatalogMetaDTO: Decodable, Sendable {
    let schemaVersion: Int
    let version: String
    let destinationFiles: [String]
    let collections: [CollectionDTO]
}

nonisolated struct CollectionDTO: Decodable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let summary: String
    let symbol: String
    let cover: String
    let destinations: [String]
}

nonisolated struct DestinationFileDTO: Decodable, Sendable {
    let destinations: [DestinationDTO]
}

nonisolated struct DestinationDTO: Decodable, Sendable {
    let id: String
    let name: String
    let landmark: String
    let country: String
    let region: String
    let category: String
    let lat: Double
    let lon: Double
    let verificationRadius: Double?
    let featured: Bool?
    let summary: String
    let story: String
    let keywords: [String]?
    let altNames: [String]?
    let stamp: StampDTO
}

nonisolated struct StampDTO: Decodable, Sendable {
    let motif: String
    let palette: String
    let tint: String?
    let sun: [Double]?
    let night: Bool?
    let aurora: Bool?
    let clouds: Double?
    let variant: Int?
    let assetName: String?
    let alt: String
    let edition: String?
    let title: String?
}

// MARK: - Loader

/// Reads and validates the bundled catalogue. Bad records are dropped and
/// reported as `CatalogIssue`s; a bad file never prevents the app from launching
/// with the records that are valid.
nonisolated enum CatalogLoader {
    static let supportedSchema = 1

    static func load(bundle: Bundle = .main) throws -> Catalog {
        guard let metaURL = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CatalogError.missingResource("catalog.json")
        }
        let metaData: Data
        do { metaData = try Data(contentsOf: metaURL) } catch { throw CatalogError.unreadable(error.localizedDescription) }
        let meta = try decode(CatalogMetaDTO.self, from: metaData, name: "catalog.json")

        var files: [Data] = []
        for name in meta.destinationFiles {
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                throw CatalogError.missingResource("\(name).json")
            }
            do { files.append(try Data(contentsOf: url)) } catch { throw CatalogError.unreadable(error.localizedDescription) }
        }
        return try build(metaData: metaData, destinationFiles: files)
    }

    /// Builds a validated catalogue from raw JSON. Exposed for tests.
    static func build(metaData: Data, destinationFiles: [Data]) throws -> Catalog {
        let meta = try decode(CatalogMetaDTO.self, from: metaData, name: "catalog.json")
        guard meta.schemaVersion == supportedSchema else { throw CatalogError.unsupportedSchema(meta.schemaVersion) }

        var issues: [CatalogIssue] = []
        var destinations: [Destination] = []
        var stamps: [StampDesign] = []
        var seen = Set<String>()

        for (index, data) in destinationFiles.enumerated() {
            let file = try decode(DestinationFileDTO.self, from: data, name: "destinations file \(index + 1)")
            for dto in file.destinations {
                switch validate(dto, seen: &seen) {
                case .success(let (destination, stamp)):
                    destinations.append(destination)
                    stamps.append(stamp)
                case .failure(let issue):
                    issues.append(issue)
                }
            }
        }
        guard !destinations.isEmpty else { throw CatalogError.empty }

        let validIDs = Set(destinations.map(\.id))
        var collections: [StampCollection] = []
        var collectionIDs = Set<String>()
        for (order, dto) in meta.collections.enumerated() {
            guard collectionIDs.insert(dto.id).inserted else {
                issues.append(.init(recordID: dto.id, message: "Duplicate collection id."))
                continue
            }
            let members = dto.destinations.filter { validIDs.contains($0) }
            for missing in dto.destinations where !validIDs.contains(missing) {
                issues.append(.init(recordID: dto.id, message: "Collection references unknown destination “\(missing)”."))
            }
            guard !members.isEmpty else {
                issues.append(.init(recordID: dto.id, message: "Collection has no valid destinations and was dropped."))
                continue
            }
            let cover = validIDs.contains(dto.cover) ? dto.cover : members[0]
            collections.append(StampCollection(id: dto.id, title: dto.title, subtitle: dto.subtitle, summary: dto.summary,
                                               symbolName: dto.symbol, destinationIDs: members,
                                               coverDestinationID: cover, order: order))
        }
        return Catalog(version: meta.version, destinations: destinations, stamps: stamps,
                       collections: collections, issues: issues)
    }

    // MARK: Validation

    private static func validate(_ dto: DestinationDTO, seen: inout Set<String>) -> Result<(Destination, StampDesign), CatalogIssue> {
        func fail(_ message: String) -> Result<(Destination, StampDesign), CatalogIssue> {
            .failure(CatalogIssue(recordID: dto.id.isEmpty ? "(missing id)" : dto.id, message: message))
        }
        let id = dto.id.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return fail("Destination has no id.") }
        guard seen.insert(id).inserted else { return fail("Duplicate destination id.") }
        guard !dto.name.trimmingCharacters(in: .whitespaces).isEmpty,
              !dto.landmark.trimmingCharacters(in: .whitespaces).isEmpty else { return fail("Name or landmark is empty.") }
        guard CountryInfo.isValid(dto.country) else { return fail("“\(dto.country)” is not a valid ISO country code.") }
        guard let region = Region(rawValue: dto.region) else { return fail("Unknown region “\(dto.region)”.") }
        guard let category = DestinationCategory(rawValue: dto.category) else { return fail("Unknown category “\(dto.category)”.") }
        guard (-90...90).contains(dto.lat), (-180...180).contains(dto.lon), !(dto.lat == 0 && dto.lon == 0) else {
            return fail("Coordinates are out of range.")
        }
        if let radius = dto.verificationRadius, !(50...100_000).contains(radius) {
            return fail("Verification radius must be between 50 m and 100 km.")
        }
        guard dto.summary.count >= 10, dto.story.count >= 30 else { return fail("Description is missing or too short.") }
        guard let motif = ArtMotif(rawValue: dto.stamp.motif) else { return fail("Unknown artwork motif “\(dto.stamp.motif)”.") }
        guard var palette = ArtPalettePresets.palette(named: dto.stamp.palette) else {
            return fail("Unknown palette “\(dto.stamp.palette)”.")
        }
        if let tint = dto.stamp.tint {
            guard RGB(hexString: tint) != nil else { return fail("Invalid tint colour “\(tint)”.") }
            palette.tint = tint
        }
        guard ArtColors(palette: palette) != nil else { return fail("Palette contains an invalid colour.") }
        guard !dto.stamp.alt.isEmpty else { return fail("Stamp is missing an accessibility description.") }

        var sun: (Double?, Double?, Double?) = (nil, nil, nil)
        if let s = dto.stamp.sun {
            guard s.count == 3, (0...100).contains(s[0]), (0...130).contains(s[1]), (2...30).contains(s[2]) else {
                return fail("Sun must be [x, y, radius] within the art area.")
            }
            sun = (s[0], s[1], s[2])
        }
        let artwork = ArtworkSpec(motif: motif, paletteName: dto.stamp.palette, palette: palette,
                                  sunX: sun.0, sunY: sun.1, sunRadius: sun.2,
                                  night: dto.stamp.night ?? false, aurora: dto.stamp.aurora ?? false,
                                  clouds: min(max(dto.stamp.clouds ?? 0.4, 0), 1), variant: dto.stamp.variant ?? 0,
                                  assetName: dto.stamp.assetName)

        let destination = Destination(id: id, name: dto.name, landmark: dto.landmark, countryCode: dto.country,
                                      region: region, category: category, latitude: dto.lat, longitude: dto.lon,
                                      verificationRadiusOverride: dto.verificationRadius,
                                      summary: dto.summary, story: dto.story,
                                      keywords: dto.keywords ?? [], alternativeNames: dto.altNames ?? [],
                                      isFeatured: dto.featured ?? false)
        let stamp = StampDesign(id: StampID.make(for: id), destinationID: id,
                                title: dto.stamp.title ?? dto.name, edition: dto.stamp.edition ?? "Series I",
                                artwork: artwork, accessibilityDescription: dto.stamp.alt)
        return .success((destination, stamp))
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, name: String) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw CatalogError.unreadable("\(name): \(error.localizedDescription)") }
    }
}
