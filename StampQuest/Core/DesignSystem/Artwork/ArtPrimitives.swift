import SwiftUI

// The stamp illustration engine draws every destination from vector primitives in
// a 100 × 130 "art space". Everything here is `nonisolated` so rendering can run
// off the main actor (Canvas, ImageRenderer, widgets, exports).

// MARK: - Colour

nonisolated struct RGB: Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    /// Parses `#RRGGBB` / `RRGGBB`. Returns nil if malformed.
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(r: Double((v >> 16) & 0xFF) / 255,
                  g: Double((v >> 8) & 0xFF) / 255,
                  b: Double(v & 0xFF) / 255)
    }

    static let black = RGB(r: 0, g: 0, b: 0)
    static let white = RGB(r: 1, g: 1, b: 1)

    func mixed(_ other: RGB, _ t: Double) -> RGB {
        let t = min(max(t, 0), 1)
        return RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func darkened(_ t: Double) -> RGB { mixed(.black, t) }
    func lightened(_ t: Double) -> RGB { mixed(.white, t) }

    /// Relative luminance (WCAG).
    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    func color(opacity: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: opacity) }
}

/// The painted colours of one stamp, plus colours derived from them so every
/// illustration shares a consistent tonal structure.
nonisolated struct ArtColors: Sendable {
    let skyTop: RGB
    let skyBottom: RGB
    let sun: RGB
    let subject: RGB
    let ground: RGB
    let tint: RGB

    // Derived tones
    let shade: RGB       // subject in shadow
    let light: RGB       // subject catching light
    let deep: RGB        // very dark accent for openings and windows
    let hillFar: RGB
    let hillNear: RGB
    let haze: RGB

    init?(palette: ArtworkPalette) {
        guard let skyTop = RGB(hexString: palette.skyTop),
              let skyBottom = RGB(hexString: palette.skyBottom),
              let sun = RGB(hexString: palette.sun),
              let subject = RGB(hexString: palette.subject),
              let ground = RGB(hexString: palette.ground),
              let tint = RGB(hexString: palette.tint) else { return nil }
        self.skyTop = skyTop
        self.skyBottom = skyBottom
        self.sun = sun
        self.subject = subject
        self.ground = ground
        self.tint = tint
        self.shade = subject.darkened(0.32)
        self.light = subject.mixed(sun, 0.35).lightened(0.18)
        self.deep = subject.darkened(0.62)
        self.hillFar = skyBottom.mixed(subject, 0.20)
        self.hillNear = skyBottom.mixed(ground, 0.48).mixed(subject, 0.12)
        self.haze = skyBottom
    }
}

// MARK: - Randomness

/// Deterministic generator so the same destination always renders identically.
nonisolated struct ArtRandom: Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(unit() * Double(range.count))
    }
    mutating func chance(_ p: Double) -> Bool { unit() < p }

    static func seed(from string: String) -> UInt64 {
        // FNV-1a
        var h: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return h
    }
}

// MARK: - Pen

@inline(__always) nonisolated func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

/// A thin convenience layer over `GraphicsContext` working in art-space units.
nonisolated struct ArtPen {
    var ctx: GraphicsContext

    func fill(_ path: Path, _ color: RGB, opacity: Double = 1) {
        ctx.fill(path, with: .color(color.color(opacity: opacity)))
    }

    func poly(_ points: [(Double, Double)], _ color: RGB, opacity: Double = 1) {
        guard let first = points.first else { return }
        var p = Path()
        p.move(to: pt(first.0, first.1))
        for q in points.dropFirst() { p.addLine(to: pt(q.0, q.1)) }
        p.closeSubpath()
        fill(p, color, opacity: opacity)
    }

    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: RGB, opacity: Double = 1) {
        fill(Path(CGRect(x: x, y: y, width: w, height: h)), color, opacity: opacity)
    }

    func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ color: RGB, opacity: Double = 1) {
        fill(Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)), color, opacity: opacity)
    }

    func circle(_ cx: Double, _ cy: Double, _ r: Double, _ color: RGB, opacity: Double = 1) {
        ellipse(cx, cy, r, r, color, opacity: opacity)
    }

    func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, width: Double, _ color: RGB, opacity: Double = 1) {
        var p = Path()
        p.move(to: pt(x1, y1))
        p.addLine(to: pt(x2, y2))
        ctx.stroke(p, with: .color(color.color(opacity: opacity)),
                   style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }

    func stroke(_ path: Path, width: Double, _ color: RGB, opacity: Double = 1, cap: CGLineCap = .round) {
        ctx.stroke(path, with: .color(color.color(opacity: opacity)),
                   style: StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: .round))
    }

    /// Erases within the current layer (reveals what is behind the layer).
    func clear(_ path: Path) {
        var c = ctx
        c.blendMode = .clear
        c.fill(path, with: .color(.black))
    }

    func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        clear(Path(CGRect(x: x, y: y, width: w, height: h)))
    }

    /// A round-topped opening (door, window, arch) whose base sits at `y + h`.
    func archPath(cx: Double, y: Double, w: Double, h: Double) -> Path {
        var p = Path()
        let r = w / 2
        p.move(to: pt(cx - r, y + h))
        p.addLine(to: pt(cx - r, y + r))
        p.addQuadCurve(to: pt(cx, y), control: pt(cx - r, y))
        p.addQuadCurve(to: pt(cx + r, y + r), control: pt(cx + r, y))
        p.addLine(to: pt(cx + r, y + h))
        p.closeSubpath()
        return p
    }

    func clearArch(cx: Double, y: Double, w: Double, h: Double) {
        clear(archPath(cx: cx, y: y, w: w, h: h))
    }

    func fillArch(cx: Double, y: Double, w: Double, h: Double, _ color: RGB, opacity: Double = 1) {
        fill(archPath(cx: cx, y: y, w: w, h: h), color, opacity: opacity)
    }
}

// MARK: - Path helpers

extension Path {
    /// A closed smooth blob/hill: ridge points joined by gentle quadratic curves
    /// down to `baseY`.
    nonisolated static func ridge(points: [(Double, Double)], baseY: Double) -> Path {
        var p = Path()
        guard let first = points.first, let last = points.last else { return p }
        p.move(to: pt(first.0, baseY))
        p.addLine(to: pt(first.0, first.1))
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let mid = pt((a.0 + b.0) / 2, (a.1 + b.1) / 2)
            p.addQuadCurve(to: mid, control: pt(a.0, a.1))
            if i == points.count - 1 { p.addQuadCurve(to: pt(b.0, b.1), control: pt(b.0, b.1)) }
        }
        p.addLine(to: pt(last.0, baseY))
        p.closeSubpath()
        return p
    }
}
