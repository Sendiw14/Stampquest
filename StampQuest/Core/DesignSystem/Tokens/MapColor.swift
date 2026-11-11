import SwiftUI
import UIKit

/// Colour roles of the Map (M3 Cover Frame) that Home and Passport tokens do not already cover. Page, card, ink, sub, cta
/// and label come from `HomeColor`; line, tint and quiet from `PassportColor`.
enum MapColor {
    /// Halo behind a selected marker.
    static let halo = alpha(light: (162, 90, 56, 0.17), dark: (240, 169, 130, 0.22))
    /// The 2 pt rim of the map window.
    static let windowBorder = alpha(light: (255, 249, 241, 0.92), dark: (246, 240, 229, 0.20))
    /// Ring around a cluster, and the translucent ring outside it.
    static let clusterFill = Color(light: 0x211E1A, dark: 0xF6F0E5)
    static let clusterRing = Color(light: 0xFBF7EE, dark: 0x2B2927)
    static let clusterText = Color(light: 0xFBF7EE, dark: 0x211E1A)
    static let clusterHalo = alpha(light: (33, 30, 26, 0.18), dark: (246, 240, 229, 0.22))
    /// Cream of the cover text.
    static let onCover = Color(hex: 0xFFF9F1)
    /// The map's own paper, used for the halo of marker labels so they read on any map.
    static let labelHalo = Color(light: 0xF6F1E7, dark: 0x1C1B19)
    /// The user's own position.
    static let you = Color(hex: 0x2F7DF6)

    /// `nonisolated`: UIKit resolves a dynamic colour on any thread, so its closure must not be main-actor isolated.
    private nonisolated static func alpha(light: (Int, Int, Int, Double), dark: (Int, Int, Int, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            let boost = traits.accessibilityContrast == .high ? 1.6 : 1
            return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: min(1, c.3 * boost))
        })
    }
}
