import SwiftUI
import UIKit
import CoreText

/// The outline of a numeral string as a SwiftUI path, built once per (text, size) from CoreText glyphs.
@MainActor
enum GlyphPath {
    private static var cache: [String: Path] = [:]
    static let tracking: CGFloat = -0.06

    /// The path with its left edge at x = 0 and its vertical middle at y = 0.
    static func path(for text: String, size: CGFloat) -> Path {
        let key = "\(text)|\(size)"
        if let hit = cache[key] { return hit }
        let font = CTFontCreateWithName(UIFont.systemFont(ofSize: size, weight: .heavy).fontName as CFString, size, nil)
        var path = Path()
        var x: CGFloat = 0
        for character in text.utf16 {
            var unit = character
            var glyph = CGGlyph()
            guard CTFontGetGlyphsForCharacters(font, &unit, &glyph, 1) else { continue }
            if let outline = CTFontCreatePathForGlyph(font, glyph, nil) {
                let placed = Path(outline).applying(CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: x, y: 0))
                path.addPath(placed)
            }
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
            x += advance.width + tracking * size
        }
        let box = path.boundingRect
        let result = path.applying(CGAffineTransform(translationX: -box.minX, y: -box.midY))
        cache[key] = result
        return result
    }

    /// Width of the run at 1 pt, used by `HomeCopy.numeralSize`.
    static func unitWidth(for text: String) -> Double { Double(path(for: text, size: 100).boundingRect.width) / 100 }
}
