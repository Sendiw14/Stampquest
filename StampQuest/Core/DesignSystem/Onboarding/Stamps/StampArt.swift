import SwiftUI

/// Original stamp artwork for Paris, Kyoto and Santorini, ported 1:1 from the design coordinates
/// (spec appendix A). Panel space is 102 x 122 units; the caller clips and positions the panel.
nonisolated enum StampArt {
    static let panel = CGSize(width: 102, height: 122)
    static var panelRect: CGRect { CGRect(origin: .zero, size: panel) }

    static func draw(_ style: StampArtStyle, in ctx: inout GraphicsContext) {
        switch style {
        case .paris: drawParis(&ctx)
        case .kyoto: drawKyoto(&ctx)
        case .santorini: drawSantorini(&ctx)
        }
    }

    /// Border colour of the perforated frame.
    static func borderColor(_ style: StampArtStyle) -> Color {
        switch style {
        case .paris: ink(0xF2C27C)
        case .kyoto: ink(0xEBA3A9)
        case .santorini: ink(0x9BC9F0)
        }
    }

    // MARK: Helpers

    static func ink(_ hex: UInt32, _ alpha: Double = 1) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }

    private static func vertical(_ stops: [(UInt32, CGFloat)], from y0: CGFloat, to y1: CGFloat) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: stops.map { .init(color: ink($0.0), location: $0.1) }),
                        startPoint: CGPoint(x: 0, y: y0), endPoint: CGPoint(x: 0, y: y1))
    }

    private static func fill(_ ctx: inout GraphicsContext, _ path: Path, _ hex: UInt32, _ alpha: Double = 1) {
        ctx.fill(path, with: .color(ink(hex, alpha)))
    }

    private static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    // MARK: Paris

    private static func drawParis(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(panelRect), with: vertical([(0xF3C6A5, 0), (0xEFB398, 0.55), (0xE99C88, 1)], from: 0, to: 122))
        fill(&ctx, circle(73, 56, 15), 0xFFF1D8)
        fill(&ctx, Path(roundedRect: CGRect(x: 9, y: 28, width: 24, height: 3.4), cornerRadius: 1.7), 0xFFFFFF, 0.5)
        fill(&ctx, Path(roundedRect: CGRect(x: 62, y: 22, width: 26, height: 3.4), cornerRadius: 1.7), 0xFFFFFF, 0.4)
        fill(&ctx, SVGPath.path("M0 90 C12 83 26 86 40 88 C56 82 78 84 102 89 V104 H0 Z"), 0xD9857A, 0.5)
        ctx.fill(rect(0, 100, 102, 22), with: vertical([(0x8AA878, 0), (0x5C7F61, 1)], from: 100, to: 122))
        fill(&ctx, SVGPath.path("M44 100 H58 L74 122 H28 Z"), 0xEAD2B2, 0.9)
        fill(&ctx, ellipse(13, 101, 10, 7.5), 0x4A6E55)
        fill(&ctx, ellipse(91, 102, 11, 8), 0x4A6E55)

        let tower: [Path] = [
            SVGPath.path("M50.4 10 H51.6 L52.3 30 H49.7 Z"),
            SVGPath.path("M48.6 30 H53.4 L56.2 56 H45.8 Z"),
            rect(43.6, 56, 14.8, 2.6),
            SVGPath.path("M45.2 58.6 H56.8 L64.4 80 H37.6 Z"),
            rect(35.2, 80, 31.6, 3.2),
            SVGPath.path("M36.6 83.2 H65.4 L78 100 H67 C66.4 91.4 60 87.2 51 87.2 C42 87.2 35.6 91.4 35 100 H24 Z"),
        ]
        for part in tower { fill(&ctx, part, 0x2C3441) }

        let lattice = SVGPath.path("M47.6 36 L54.4 50 M54.4 36 L47.6 50 M45.5 63 L56.5 77 M56.5 63 L45.5 77")
        ctx.stroke(lattice, with: .color(ink(0xEFB398, 0.7)), lineWidth: 0.8)
    }

    // MARK: Kyoto

    private static func drawKyoto(_ ctx: inout GraphicsContext) {
        fill(&ctx, Path(panelRect), 0x2B4535)
        // Glow: radial centred (51,66), radius 46.
        let glow = Gradient(stops: [
            .init(color: ink(0xFCE8B8), location: 0),
            .init(color: ink(0xF2C98A, 0.55), location: 0.55),
            .init(color: ink(0xF2C98A, 0), location: 1),
        ])
        ctx.fill(Path(panelRect), with: .radialGradient(glow, center: CGPoint(x: 51, y: 66), startRadius: 0, endRadius: 46))
        fill(&ctx, SVGPath.path("M47 66 H55 L100 122 H2 Z"), 0x7A5C43)
        fill(&ctx, SVGPath.path("M49.5 66 H52.5 L62 122 H40 Z"), 0x9A7A5C, 0.6)

        // Four torii about (51,66), small to large.
        for (scale, tint) in [(0.26, 0xF0C193), (0.41, 0xE69A6B), (0.64, 0xDB6F46), (1.0, 0xC9452A)] as [(CGFloat, UInt32)] {
            var c = ctx
            c.translateBy(x: 51, y: 66)
            c.scaleBy(x: scale, y: scale)
            c.translateBy(x: -51, y: -66)
            drawTorii(&c, tint: tint)
        }
    }

    private static func drawTorii(_ c: inout GraphicsContext, tint: UInt32) {
        fill(&c, SVGPath.path("M-3 15 L105 15 Q100 25 94 25 H8 Q2 25 -3 15 Z"), tint)
        fill(&c, rect(-3, 15, 108, 3.6), 0x1E231F)
        fill(&c, rect(10, 40, 82, 6), tint)
        fill(&c, rect(17, 25, 9, 97), tint)
        fill(&c, rect(76, 25, 9, 97), tint)
        fill(&c, rect(17, 110, 9, 12), 0x1E231F)
        fill(&c, rect(76, 110, 9, 12), 0x1E231F)
    }

    // MARK: Santorini

    private static func drawSantorini(_ ctx: inout GraphicsContext) {
        ctx.fill(Path(panelRect), with: vertical([(0x8CC3E8, 0), (0xE2F0F8, 1)], from: 0, to: 122))
        fill(&ctx, circle(82, 24, 9), 0xFFF4CF)
        ctx.fill(rect(0, 84, 102, 38), with: vertical([(0x3279B0, 0), (0x1F5C8E, 1)], from: 84, to: 122))
        let waves = SVGPath.path("M60 96 H72 M74 106 H92 M58 112 H68 M80 116 H96")
        ctx.stroke(waves, with: .color(ink(0xFFFFFF, 0.4)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        fill(&ctx, SVGPath.path("M0 44 L40 54 L64 78 L80 122 H0 Z"), 0xD7C7B4)

        // Bell tower.
        fill(&ctx, rect(30, 26, 9, 22), 0xFBFAF6)
        fill(&ctx, SVGPath.path("M28.5 26 A6 6 0 0 1 40.5 26 Z"), 0x2F67B0)
        ctx.stroke(SVGPath.path("M34.5 15 V20 M32.6 16.8 H36.4"), with: .color(ink(0xFBFAF6)),
                   style: StrokeStyle(lineWidth: 0.9, lineCap: .round))

        // Houses (x, y, w, h, fill).
        let houses: [(CGFloat, CGFloat, CGFloat, CGFloat, UInt32)] = [
            (2, 34, 14, 11, 0xFBFAF6), (15, 38, 13, 12, 0xF3F0E8), (27, 44, 14, 12, 0xFBFAF6), (40, 54, 12, 12, 0xF3F0E8),
            (51, 64, 12, 11, 0xFBFAF6), (6, 50, 13, 11, 0xF3F0E8), (18, 56, 14, 12, 0xFBFAF6), (32, 64, 14, 12, 0xF3F0E8),
            (46, 74, 14, 11, 0xFBFAF6), (14, 70, 13, 11, 0xFBFAF6), (2, 66, 12, 10, 0xF3F0E8),
        ]
        for h in houses { fill(&ctx, rect(h.0, h.1, h.2, h.3), h.4) }
        fill(&ctx, SVGPath.path("M40 54 A6 6 0 0 1 52 54 Z"), 0x2F67B0)
        for door in [(8.0, 53.0), (21, 60), (36, 68), (49, 78), (19, 74)] as [(CGFloat, CGFloat)] {
            fill(&ctx, rect(door.0, door.1, 3, 4.5), 0x2F67B0)
        }
    }
}
