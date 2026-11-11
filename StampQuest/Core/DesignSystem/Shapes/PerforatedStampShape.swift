import SwiftUI

/// Geometry shared by every stamp rendering in the app (grid, detail, reveal,
/// passport pages, exports, widgets).
nonisolated enum StampMetrics {
    /// Width ÷ height of a stamp.
    static let aspectRatio: CGFloat = 0.8
    /// Margin between the stamp edge and the artwork, as a fraction of width.
    static let insetRatio: CGFloat = 0.085
    /// Perforation pitch as a fraction of width (holes across the short edge).
    static let perforationsAcrossWidth: Int = 10
}

/// A postage-stamp outline: straight corners and semicircular perforation
/// notches cut into every edge.
///
/// The notch pitch is derived from the shape's own size, so the same shape looks
/// identical from a 40-pt widget thumbnail to a full-screen reveal. Notches are
/// built from Bézier arcs (not repeated circles), so edges stay crisp and the
/// path is a single closed outline that can be filled, stroked, clipped and
/// shadowed like any other shape.
nonisolated struct PerforatedStampShape: Shape {
    var perforationsAcrossWidth: Int = StampMetrics.perforationsAcrossWidth
    /// Notch radius as a fraction of the pitch.
    var notchRatio: CGFloat = 0.30

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        let pitchTarget = rect.width / CGFloat(max(perforationsAcrossWidth, 3))
        let nx = max(3, Int((rect.width / pitchTarget).rounded()))
        let ny = max(3, Int((rect.height / pitchTarget).rounded()))
        let px = rect.width / CGFloat(nx)
        let py = rect.height / CGFloat(ny)
        let r = min(px, py) * notchRatio

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top edge, left to right (notches bulge downward, into the stamp).
        edge(&path, from: CGPoint(x: rect.minX, y: rect.minY), direction: CGVector(dx: 1, dy: 0),
             inward: CGVector(dx: 0, dy: 1), count: nx, pitch: px, radius: r)
        // Right edge, top to bottom.
        edge(&path, from: CGPoint(x: rect.maxX, y: rect.minY), direction: CGVector(dx: 0, dy: 1),
             inward: CGVector(dx: -1, dy: 0), count: ny, pitch: py, radius: r)
        // Bottom edge, right to left.
        edge(&path, from: CGPoint(x: rect.maxX, y: rect.maxY), direction: CGVector(dx: -1, dy: 0),
             inward: CGVector(dx: 0, dy: -1), count: nx, pitch: px, radius: r)
        // Left edge, bottom to top.
        edge(&path, from: CGPoint(x: rect.minX, y: rect.maxY), direction: CGVector(dx: 0, dy: -1),
             inward: CGVector(dx: 1, dy: 0), count: ny, pitch: py, radius: r)

        path.closeSubpath()
        return path
    }

    private func edge(_ path: inout Path, from start: CGPoint, direction d: CGVector, inward n: CGVector,
                      count: Int, pitch: CGFloat, radius r: CGFloat) {
        let k: CGFloat = 0.5523  // Bézier circle constant
        for i in 0..<count {
            let t = (CGFloat(i) + 0.5) * pitch
            let c = CGPoint(x: start.x + d.dx * t, y: start.y + d.dy * t)
            let a = CGPoint(x: c.x - d.dx * r, y: c.y - d.dy * r)
            let peak = CGPoint(x: c.x + n.dx * r, y: c.y + n.dy * r)
            let b = CGPoint(x: c.x + d.dx * r, y: c.y + d.dy * r)
            path.addLine(to: a)
            path.addCurve(to: peak,
                          control1: CGPoint(x: a.x + n.dx * r * k, y: a.y + n.dy * r * k),
                          control2: CGPoint(x: peak.x - d.dx * r * k, y: peak.y - d.dy * r * k))
            path.addCurve(to: b,
                          control1: CGPoint(x: peak.x + d.dx * r * k, y: peak.y + d.dy * r * k),
                          control2: CGPoint(x: b.x + n.dx * r * k, y: b.y + n.dy * r * k))
        }
        path.addLine(to: CGPoint(x: start.x + d.dx * pitch * CGFloat(count), y: start.y + d.dy * pitch * CGFloat(count)))
    }
}

/// A perforated outline whose notches keep a fixed pitch in points whatever the shape's width, for frames that are
/// sized by their content (a stamp-word on the Welcome headline).
nonisolated struct FixedPitchPerforatedShape: Shape {
    var pitch: CGFloat
    var notchRatio: CGFloat = 0.30

    func path(in rect: CGRect) -> Path {
        let across = max(3, Int((rect.width / max(pitch, 1)).rounded()))
        return PerforatedStampShape(perforationsAcrossWidth: across, notchRatio: notchRatio).path(in: rect)
    }
}
