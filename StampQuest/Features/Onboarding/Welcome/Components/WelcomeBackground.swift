import SwiftUI

/// The terracotta poster (light) or charcoal (dark), with a soft glow behind the stamp fan.
struct WelcomeBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    stops: [.init(color: WelcomeColor.bgTop, location: 0), .init(color: WelcomeColor.bgMid, location: 0.52),
                            .init(color: WelcomeColor.bgBottom, location: 1)],
                    startPoint: UnitPoint(x: 0.41, y: 0.005), endPoint: UnitPoint(x: 0.59, y: 0.995))
                glow(in: proxy.size)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// An ellipse 80% of the width and 32% of the height, centred at 50% / 66% of the screen.
    private func glow(in size: CGSize) -> some View {
        let radius: CGFloat = 100
        return Rectangle()
            .fill(RadialGradient(colors: [WelcomeColor.glow, WelcomeColor.glow.opacity(0)], center: .center, startRadius: 0,
                                 endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(x: size.width * 0.8 / radius, y: size.height * 0.32 / radius)
            .position(x: size.width * 0.5, y: size.height * 0.66)
    }
}
