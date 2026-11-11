import SwiftUI

/// A rectangle whose bottom edge is bitten by semicircles (radius 8, pitch 22), like a stamp sheet torn off.
nonisolated struct ScallopedBottomShape: Shape {
    var radius: CGFloat = 8
    var pitch: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        let count = max(1, Int(rect.width / pitch))
        let step = rect.width / CGFloat(count)
        for index in stride(from: count - 1, through: 0, by: -1) {
            let centre = rect.minX + (CGFloat(index) + 0.5) * step
            path.addLine(to: CGPoint(x: centre + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: centre, y: rect.maxY), radius: radius, startAngle: .zero, endAngle: .degrees(180), clockwise: true)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
