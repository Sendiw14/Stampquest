import SwiftUI

/// The shared 8-point star (spec 5.9), drawn in a 30 x 30 box and scaled into the shape's rect.
nonisolated struct StarShape: Shape {
    static let box: CGFloat = 30

    static let unitPath: Path = SVGPath.path(
        "M0 -15 L1.61 -3.88 L10.61 -10.61 L3.88 -1.61 L15 0 L3.88 1.61 L10.61 10.61 L1.61 3.88 L0 15 "
        + "L-1.61 3.88 L-10.61 10.61 L-3.88 1.61 L-15 0 L-3.88 -1.61 L-10.61 -10.61 L-1.61 -3.88 Z")

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / Self.box
        let t = CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: rect.midX, y: rect.midY))
        return Self.unitPath.applying(t)
    }
}
