import SwiftUI

/// Text laid out along a circular arc (spec 5.6). The layout is a pure function so it can be unit tested;
/// `draw` resolves each glyph with `GraphicsContext` and places it.
nonisolated enum ArcText {
    enum Placement: Sendable {
        /// Centred at 12 o'clock, reads left to right, glyph tops point outward.
        case top
        /// Centred at 6 o'clock, reads left to right, glyph tops point toward the centre.
        case bottom
    }

    struct Glyph: Equatable, Sendable {
        let character: Character
        /// Position of the glyph's baseline centre, relative to the arc centre.
        let position: CGPoint
        /// Rotation in radians to apply about that point.
        let angle: CGFloat
    }

    /// `advances[i]` is the measured width of `characters[i]`; `tracking` is extra space between glyphs.
    static func layout(characters: [Character], advances: [CGFloat], radius: CGFloat, tracking: CGFloat,
                       placement: Placement) -> [Glyph] {
        precondition(characters.count == advances.count, "one advance per character")
        guard radius > 0, !characters.isEmpty else { return [] }
        let total = advances.reduce(0, +) + tracking * CGFloat(characters.count - 1)
        var cursor = -total / 2
        var glyphs: [Glyph] = []
        for (character, advance) in zip(characters, advances) {
            let arc = cursor + advance / 2
            let delta = arc / radius
            let theta: CGFloat
            let angle: CGFloat
            switch placement {
            case .top:
                theta = -.pi / 2 + delta
                angle = delta
            case .bottom:
                theta = .pi / 2 - delta
                angle = -delta
            }
            glyphs.append(Glyph(character: character, position: CGPoint(x: radius * cos(theta), y: radius * sin(theta)), angle: angle))
            cursor += advance + tracking
        }
        return glyphs
    }

    /// Draws `text` on an arc centred at `center`. `font` and `color` apply to every glyph.
    static func draw(_ text: String, in ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, tracking: CGFloat,
                     placement: Placement, font: Font, color: Color) {
        let characters = Array(text)
        let resolved = characters.map { ctx.resolve(Text(String($0)).font(font).foregroundColor(color)) }
        let advances = resolved.map { $0.measure(in: CGSize(width: 1000, height: 1000)).width }
        for (glyph, run) in zip(layout(characters: characters, advances: advances, radius: radius, tracking: tracking, placement: placement), resolved) {
            var c = ctx
            c.translateBy(x: center.x + glyph.position.x, y: center.y + glyph.position.y)
            c.rotate(by: .radians(glyph.angle))
            c.draw(run, at: .zero, anchor: .bottom)
        }
    }
}
