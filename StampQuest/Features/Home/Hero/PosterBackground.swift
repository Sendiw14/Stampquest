import SwiftUI

/// The terracotta (or charcoal) poster behind the hero: gradient, glow, faint contour waves and a scalloped bottom edge.
struct PosterBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScallopedBottomShape()
            .fill(LinearGradient(stops: [.init(color: HomeColor.posterTop, location: 0), .init(color: HomeColor.posterMid, location: scheme == .dark ? 0.7 : 0.52),
                                         .init(color: HomeColor.posterBottom, location: 1)], startPoint: .top, endPoint: .bottom))
            .overlay {
                GeometryReader { proxy in
                    RadialGradient(colors: [HomeColor.glow.opacity(scheme == .dark ? 0.26 : 0.20), .clear], center: .center, startRadius: 0, endRadius: 1)
                        .frame(width: 2, height: 2)
                        .scaleEffect(x: proxy.size.width * 0.4, y: proxy.size.height * 0.2)
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.62)
                }
            }
            .overlay(alignment: .bottom) { waves.frame(height: 130).clipped() }
            .clipShape(ScallopedBottomShape())
            .shadow(color: Color(hex: 0x3C1608).opacity(0.45), radius: 18, y: 22)
            .accessibilityHidden(true)
    }

    private var waves: some View {
        Canvas { context, size in
            for row in 0..<4 {
                var path = Path()
                let y = size.height - CGFloat(row) * 26 - 12
                path.move(to: CGPoint(x: 0, y: y))
                for x in stride(from: 0, through: size.width, by: 6) {
                    path.addLine(to: CGPoint(x: x, y: y + 5 * sin(x / 38 + CGFloat(row))))
                }
                context.stroke(path, with: .color(.white.opacity(0.10)), lineWidth: 1)
            }
        }
    }
}
