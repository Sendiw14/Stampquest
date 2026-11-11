import UIKit

/// Resolves asset-catalog colours for one appearance and measures WCAG contrast, for the colour tests.
enum ColorKit {
    static func resolved(_ name: String, _ style: UIUserInterfaceStyle, contrast: UIAccessibilityContrast = .normal) -> [CGFloat] {
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: style), UITraitCollection(accessibilityContrast: contrast)])
        guard let color = UIColor(named: name, in: .main, compatibleWith: traits)?.resolvedColor(with: traits) else { return [] }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    /// `top` composited over an opaque `bottom`, at its own alpha scaled by `alpha`.
    static func over(_ top: [CGFloat], _ bottom: [CGFloat], alpha: CGFloat = 1) -> [CGFloat] {
        let a = top[3] * alpha
        return (0..<3).map { top[$0] * a + bottom[$0] * (1 - a) } + [1]
    }

    static func ratio(_ a: [CGFloat], _ b: [CGFloat]) -> Double {
        func luminance(_ c: [CGFloat]) -> Double {
            func lin(_ v: CGFloat) -> Double { v <= 0.03928 ? Double(v) / 12.92 : pow((Double(v) + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}
