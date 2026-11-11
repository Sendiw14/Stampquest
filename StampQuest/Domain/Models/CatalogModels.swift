import Foundation

// MARK: - Taxonomy

nonisolated enum Region: String, Codable, CaseIterable, Identifiable, Sendable {
    case europe, asia, africa, northAmerica, southAmerica, oceania

    var id: String { rawValue }

    var title: String {
        switch self {
        case .europe: String(localized: "Europe")
        case .asia: String(localized: "Asia")
        case .africa: String(localized: "Africa")
        case .northAmerica: String(localized: "North America")
        case .southAmerica: String(localized: "South America")
        case .oceania: String(localized: "Oceania")
        }
    }
}

nonisolated enum DestinationCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case city, landmark, architecture, nature, nationalPark, island, beach, foodCulture, museum, hiddenGem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .city: String(localized: "Cities")
        case .landmark: String(localized: "Historic Landmarks")
        case .architecture: String(localized: "Architecture")
        case .nature: String(localized: "Nature")
        case .nationalPark: String(localized: "National Parks")
        case .island: String(localized: "Islands")
        case .beach: String(localized: "Beaches")
        case .foodCulture: String(localized: "Food & Culture")
        case .museum: String(localized: "Museums")
        case .hiddenGem: String(localized: "Hidden Gems")
        }
    }

    var singularTitle: String {
        switch self {
        case .city: String(localized: "City")
        case .landmark: String(localized: "Historic landmark")
        case .architecture: String(localized: "Architecture")
        case .nature: String(localized: "Nature")
        case .nationalPark: String(localized: "National park")
        case .island: String(localized: "Island")
        case .beach: String(localized: "Beach")
        case .foodCulture: String(localized: "Food & culture")
        case .museum: String(localized: "Museum")
        case .hiddenGem: String(localized: "Hidden gem")
        }
    }

    var symbolName: String {
        switch self {
        case .city: "building.2"
        case .landmark: "building.columns"
        case .architecture: "square.split.bottomrightquarter"
        case .nature: "leaf"
        case .nationalPark: "tree"
        case .island: "water.waves"
        case .beach: "sun.max"
        case .foodCulture: "fork.knife"
        case .museum: "paintpalette"
        case .hiddenGem: "sparkle"
        }
    }

    /// Default verification radius. Geography differs wildly between a single
    /// monument and a national park, so one global radius would be dishonest.
    var defaultVerificationRadius: Double {
        switch self {
        case .landmark, .architecture, .museum: 600
        case .city, .foodCulture, .hiddenGem: 2_500
        case .beach: 2_000
        case .island: 8_000
        case .nature: 6_000
        case .nationalPark: 15_000
        }
    }
}

// MARK: - Destination & stamp

nonisolated struct Destination: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// The specific place the stamp depicts, e.g. "Eiffel Tower".
    let landmark: String
    /// ISO 3166-1 alpha-2.
    let countryCode: String
    let region: Region
    let category: DestinationCategory
    let latitude: Double
    let longitude: Double
    /// Explicit verification radius from the catalog, if the place needs one.
    let verificationRadiusOverride: Double?
    let summary: String
    let story: String
    let keywords: [String]
    let alternativeNames: [String]
    let isFeatured: Bool

    var stampID: String { StampID.make(for: id) }

    var verificationRadius: Double {
        verificationRadiusOverride ?? category.defaultVerificationRadius
    }

    var countryName: String { CountryInfo.name(for: countryCode) }

    /// "Eiffel Tower" when it adds information beyond the name, else the country.
    var subtitle: String {
        landmark.caseInsensitiveCompare(name) == .orderedSame ? countryName : landmark
    }

    var locationLine: String { "\(name), \(countryName)" }
}

nonisolated enum StampID {
    static let prefix = "stamp."
    static func make(for destinationID: String) -> String { prefix + destinationID }
    static func destinationID(from stampID: String) -> String? {
        stampID.hasPrefix(prefix) ? String(stampID.dropFirst(prefix.count)) : nil
    }
}

nonisolated struct StampDesign: Identifiable, Hashable, Sendable {
    let id: String
    let destinationID: String
    let title: String
    let edition: String
    let artwork: ArtworkSpec
    let accessibilityDescription: String
}

// MARK: - Collections

nonisolated struct StampCollection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let summary: String
    let symbolName: String
    /// Destination identifiers that make up the collection, in display order.
    let destinationIDs: [String]
    /// The stamp artwork used as the collection cover.
    let coverDestinationID: String
    let order: Int
}

// MARK: - Countries

nonisolated struct Country: Identifiable, Hashable, Sendable {
    var id: String { code }
    let code: String
    let name: String
    let region: Region
    let destinationIDs: [String]

    var flag: String { CountryInfo.flag(for: code) }
}

nonisolated enum CountryInfo {
    static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// Regional-indicator flag emoji for an ISO country code.
    static func flag(for code: String) -> String {
        let base: UInt32 = 127_397
        return code.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value) }
            .map { String($0) }
            .joined()
    }

    static func isValid(_ code: String) -> Bool {
        code.count == 2 && Locale.Region.isoRegions.contains { $0.identifier == code }
    }
}
