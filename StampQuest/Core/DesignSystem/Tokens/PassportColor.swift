import SwiftUI
import UIKit

/// Colour roles of the Passport screen (P1 Cover Stage) that Home's tokens do not cover. Shared roles (page, card, ink,
/// sub, cta, label, poster) come from `HomeColor`, whose values are the same.
enum PassportColor {
    /// Card line: warm brown at 18% in light, cream at 16% in dark.
    static let cardLine = alpha(light: (70, 42, 20, 0.18), dark: (246, 240, 229, 0.16))
    /// Fill of a selected chip.
    static let accentTint = alpha(light: (162, 90, 56, 0.10), dark: (219, 141, 102, 0.17))
    /// Quiet control fill (segment track, sort chip, filter button).
    static let quiet = alpha(light: (33, 30, 26, 0.07), dark: (246, 240, 229, 0.11))
    /// Border of an active filter chip.
    static let accentBorder = alpha(light: (162, 90, 56, 0.45), dark: (219, 141, 102, 0.55))
    /// Scrim behind a sheet.
    static let scrim = Color.black.opacity(0.46)
    /// Faint guilloche line on a passport page.
    static let guilloche = alpha(light: (110, 70, 40, 0.075), dark: (246, 240, 229, 0.05))

    /// `nonisolated`: UIKit resolves a dynamic colour on any thread, so its closure must not be main-actor isolated.
    private nonisolated static func alpha(light: (Int, Int, Int, Double), dark: (Int, Int, Int, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            let boost = traits.accessibilityContrast == .high ? 1.8 : 1
            return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: min(1, c.3 * boost))
        })
    }
}
