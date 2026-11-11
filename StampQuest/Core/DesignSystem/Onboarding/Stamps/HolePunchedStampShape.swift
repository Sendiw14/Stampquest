import SwiftUI

/// The stamp outline from the design: a 120 x 160 rectangle minus 56 circular holes of radius 3.5,
/// centred on the outline every 10 units starting at (0, 0), including the four corners.
/// Distinct from the main app's `PerforatedStampShape`, which cuts semicircular notches.
nonisolated struct HolePunchedStampShape: Shape {
    static let unitSize = CGSize(width: 120, height: 160)
    static let holeRadius: CGFloat = 3.5
    static let holeCount = 56

    /// Hole centres in unit space.
    static let holeCenters: [CGPoint] = {
        var points: [CGPoint] = []
        for x in stride(from: 0, through: 120, by: 10) {
            points.append(CGPoint(x: x, y: 0))
            points.append(CGPoint(x: x, y: 160))
        }
        for y in stride(from: 10, through: 150, by: 10) {
            points.append(CGPoint(x: 0, y: y))
            points.append(CGPoint(x: 120, y: y))
        }
        return points
    }()

    /// Built once: the boolean subtraction is the expensive part.
    static let unitPath: Path = {
        var holes = Path()
        for c in holeCenters {
            holes.addEllipse(in: CGRect(x: c.x - holeRadius, y: c.y - holeRadius, width: holeRadius * 2, height: holeRadius * 2))
        }
        return Path(CGRect(origin: .zero, size: unitSize)).subtracting(holes)
    }()

    func path(in rect: CGRect) -> Path {
        let s = rect.width / Self.unitSize.width
        return Self.unitPath.apply(scale: s, offset: rect.origin)
    }
}

extension Path {
    nonisolated func apply(scale: CGFloat, offset: CGPoint) -> Path {
        applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: offset.x, y: offset.y)))
    }
}
