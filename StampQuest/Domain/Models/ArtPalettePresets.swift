import Foundation

/// Curated palettes for stamp artwork. Catalog entries refer to these by name so
/// the whole collection keeps a coherent tonal range.
///
/// Rules every preset follows: the subject must read against `skyBottom`; `tint`
/// (the stamp border) is a confident, slightly muted hue; the sun is distinct from
/// the lower sky.
nonisolated enum ArtPalettePresets {
    static let all: [String: ArtworkPalette] = [
        "goldenHour": .init(skyTop: "#E9A268", skyBottom: "#FBE2B5", sun: "#F29A4E", subject: "#4A4F55", ground: "#6E7F52", tint: "#E0974F"),
        "dusk": .init(skyTop: "#5B5F9A", skyBottom: "#F2A98C", sun: "#FFD9A0", subject: "#2E3150", ground: "#3F4466", tint: "#8F78B8"),
        "night": .init(skyTop: "#0F1633", skyBottom: "#2B3A6B", sun: "#F4EFD8", subject: "#C9B58A", ground: "#162040", tint: "#2F4C8F"),
        "oceanDay": .init(skyTop: "#5EA7D6", skyBottom: "#D3EBF6", sun: "#FFF1B8", subject: "#5C7A99", ground: "#3E86A8", tint: "#4F9AC4"),
        "desert": .init(skyTop: "#E9B26F", skyBottom: "#F7DDB1", sun: "#FCE8B0", subject: "#C98B55", ground: "#D9A86C", tint: "#D9884E"),
        "jungle": .init(skyTop: "#7FB9A0", skyBottom: "#E4F0D0", sun: "#FFF0A8", subject: "#5E6F4B", ground: "#3F6B45", tint: "#4E9A6A"),
        "alpine": .init(skyTop: "#6FA8D8", skyBottom: "#E6F1F8", sun: "#FFF4C8", subject: "#6E7F93", ground: "#5E8460", tint: "#6AA0C8"),
        "rose": .init(skyTop: "#D77A8F", skyBottom: "#FBD3B4", sun: "#FFE6B0", subject: "#5B3F52", ground: "#7A4D63", tint: "#C98F91"),
        "haze": .init(skyTop: "#9FB4C4", skyBottom: "#E9EEF0", sun: "#FFF9E6", subject: "#55616B", ground: "#6B7B73", tint: "#84A9C5"),
        "terracotta": .init(skyTop: "#E7B58A", skyBottom: "#F8E4CC", sun: "#F4C27A", subject: "#A9623F", ground: "#8E5A3F", tint: "#B96F4A"),
        "emerald": .init(skyTop: "#6BAF9C", skyBottom: "#D8EEDF", sun: "#FFE9A0", subject: "#3F5E4C", ground: "#2F6A58", tint: "#526D5B"),
        "ochre": .init(skyTop: "#E3B450", skyBottom: "#FBEBC0", sun: "#FFF2C0", subject: "#8A6A3A", ground: "#A98A4E", tint: "#D7AA50"),
        "aurora": .init(skyTop: "#08122E", skyBottom: "#1E3A5F", sun: "#EFF6E0", subject: "#CFC7B5", ground: "#1B2A44", tint: "#3C8F7A"),
        "coral": .init(skyTop: "#F28F7B", skyBottom: "#FFE0C2", sun: "#FFD27A", subject: "#8A4B4B", ground: "#3FA3A3", tint: "#E8776A"),
        "lagoon": .init(skyTop: "#5CC0D0", skyBottom: "#E8F7F2", sun: "#FFF3B0", subject: "#3F7F6E", ground: "#38B2BE", tint: "#3FB0BD"),
        "blueHour": .init(skyTop: "#44587E", skyBottom: "#A8B8CE", sun: "#E8E0D0", subject: "#2C3A55", ground: "#4A5E7A", tint: "#5C74A8"),
        "vermilionDusk": .init(skyTop: "#5F6BA8", skyBottom: "#F3B6A0", sun: "#FFD9A0", subject: "#D64B2E", ground: "#3A3F66", tint: "#D64B2E"),
        "vermilion": .init(skyTop: "#8FB5A4", skyBottom: "#EAF0DA", sun: "#FFE7A0", subject: "#C4452F", ground: "#5F7F52", tint: "#C4452F"),
    ]

    static func palette(named name: String) -> ArtworkPalette? { all[name] }
}

nonisolated extension ArtworkSpec {
    /// Convenience for building a spec from a preset (used by tooling and tests).
    static func preset(_ motif: ArtMotif, palette name: String = "goldenHour", variant: Int = 0) -> ArtworkSpec {
        ArtworkSpec(motif: motif, paletteName: name,
                    palette: ArtPalettePresets.all[name] ?? ArtPalettePresets.all["goldenHour"]!,
                    sunX: nil, sunY: nil, sunRadius: nil, night: false, aurora: false,
                    clouds: 0.4, variant: variant, assetName: nil)
    }
}
