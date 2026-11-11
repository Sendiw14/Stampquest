import SwiftUI
import UIKit

/// Semantic colour tokens. Views never use literal hex values; they ask for a role.
///
/// Every token resolves per appearance (light / dark) and, where text legibility
/// depends on it, per accessibility contrast. Light values start from the brand
/// palette (Paper, Cream, Ink, Terracotta, Forest, Sky, Ochre, Rose, Stone); dark
/// values are re-derived for a dark paper surface rather than inverted.
enum SQColor {
    // MARK: Surfaces
    static let background = Color(light: 0xF7F2E8, dark: 0x1B1C1A)
    static let backgroundSecondary = Color(light: 0xEDE3D2, dark: 0x252724)
    static let surface = Color(light: 0xFCF9F2, dark: 0x2B2D2A)
    static let surfaceSunken = Color(light: 0xE9E0CF, dark: 0x161715)

    // MARK: Text
    static let textPrimary = Color(light: 0x252724, dark: 0xF2EDE2, lightHC: 0x111210, darkHC: 0xFFFFFF)
    static let textSecondary = Color(light: 0x5C5B54, dark: 0xBDB8AC, lightHC: 0x403F3A, darkHC: 0xDAD6CB)
    static let textTertiary = Color(light: 0x6B685F, dark: 0x9E9A8F, lightHC: 0x4E4C45, darkHC: 0xC4C0B4)

    // MARK: Accent
    /// Decorative terracotta. Do not use for small text on paper (fails 4.5:1).
    static let accent = Color(light: 0xB96F4A, dark: 0xD98B66)
    /// Fill for primary actions; pairs with `onAccent`.
    static let accentStrong = Color(light: 0xA05A38, dark: 0xD98B66)
    static let onAccent = Color(light: 0xFBF7EE, dark: 0x1B1C1A)
    /// Accent for text and glyphs on paper surfaces; meets 4.5:1.
    static let accentText = Color(light: 0x934B2B, dark: 0xE3A07E, lightHC: 0x7A3A1E, darkHC: 0xF0B596)

    // MARK: Lines
    static let border = Color(light: 0xC9C4BB, dark: 0x3C3E3A)
    static let separator = Color(light: 0xDAD4C8, dark: 0x30322F)

    // MARK: Status
    static let success = Color(light: 0x3A6B4B, dark: 0x86BB98)
    static let warning = Color(light: 0x7F5C0C, dark: 0xE2B960)
    static let error = Color(light: 0xB03A2A, dark: 0xF28C7A)
    static let verified = Color(light: 0x3A6B4B, dark: 0x86BB98)
    static let manual = Color(light: 0x934B2B, dark: 0xE3A07E)
    static let wishlist = Color(light: 0xA8505C, dark: 0xE7A5AB)
    static let disabled = Color(light: 0xA9A59B, dark: 0x5C5A52)

    // MARK: Brand palette (decorative; never carries meaning alone)
    static let ochre = Color(light: 0xD7AA50, dark: 0xD7AA50)
    static let forest = Color(light: 0x526D5B, dark: 0x7C9D87)
    static let sky = Color(light: 0x84A9C5, dark: 0x84A9C5)
    static let rose = Color(light: 0xC98F91, dark: 0xC98F91)
    static let stone = Color(light: 0xC9C4BB, dark: 0x4A4C47)
    /// Warm ink used for postmarks and engraved details.
    static let ink = Color(light: 0x252724, dark: 0xE8E2D4)
    /// The paper colour of a stamp's margin. Does not darken in dark mode so
    /// stamps keep their physical identity.
    static let stampPaper = Color(light: 0xFBF6EA, dark: 0xF3EBDA)
}

extension Color {
    /// Dynamic colour from 24-bit RGB hex values for each appearance. UIKit calls the provider on any thread, so this
    /// is nonisolated.
    nonisolated init(light: UInt32, dark: UInt32, lightHC: UInt32? = nil, darkHC: UInt32? = nil) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let highContrast = traits.accessibilityContrast == .high
            switch (isDark, highContrast) {
            case (false, true): return UIColor(hex: lightHC ?? light)
            case (true, true): return UIColor(hex: darkHC ?? dark)
            case (false, false): return UIColor(hex: light)
            case (true, false): return UIColor(hex: dark)
            }
        })
    }

    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
