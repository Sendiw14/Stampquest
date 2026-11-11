import Foundation

/// The vocabulary of illustrated subjects the stamp artwork engine can draw.
/// Each case maps to a hand-built vector composition in `Core/DesignSystem/Artwork`.
nonisolated enum ArtMotif: String, Codable, CaseIterable, Sendable {
    case eiffel, tokyoTower, towerBridge, colosseum, sagrada, hillTown, canals, stoneBridge
    case parthenon, towerFort, castleHill, fairyCastle, hallgrimskirkja, fjord, peaks, duomo
    case parliament, alpineVillage, meteora, cappadocia, maidenTower, torii, fuji, tajMahal
    case angkor, greatWall, marinaBay, pagoda, burj, petra, halong, hanokPalace, prang
    case sigiriya, lighthouseFort, pyramids, tableMountain, savanna, minaret, waterfall
    case statueOfLiberty, suspensionBridge, canyon, lakeReflection, mayanPyramid, geyser
    case balconyRow, palmBeach, machuPicchu, christRedeemer, operaHouse, monolith, louvre
}

/// A resolved set of six colours used to paint one stamp.
nonisolated struct ArtworkPalette: Codable, Hashable, Sendable {
    var skyTop: String
    var skyBottom: String
    var sun: String
    var subject: String
    var ground: String
    var tint: String
}

/// Everything the artwork engine needs to paint a stamp. Decoded from the catalog.
nonisolated struct ArtworkSpec: Hashable, Sendable {
    var motif: ArtMotif
    /// Name of a palette preset in the catalog.
    var paletteName: String
    /// Resolved palette (filled in by the catalog loader from `paletteName`).
    var palette: ArtworkPalette
    /// Optional override of the stamp's border tint.
    var sunX: Double?
    var sunY: Double?
    var sunRadius: Double?
    var night: Bool
    var aurora: Bool
    /// 0...1 cloud coverage.
    var clouds: Double
    /// Motif-specific variation (e.g. house colours, number of falls).
    var variant: Int
    /// Optional asset-catalog image name. When present and found, the bundled
    /// painted artwork takes precedence over the procedural illustration.
    var assetName: String?
}

/// Raw JSON shape of `ArtworkSpec` before palette resolution.
nonisolated struct ArtworkSpecDTO: Codable, Sendable {
    var motif: ArtMotif
    var palette: String
    var tint: String?
    var sun: [Double]?
    var night: Bool?
    var aurora: Bool?
    var clouds: Double?
    var variant: Int?
    var assetName: String?
}
