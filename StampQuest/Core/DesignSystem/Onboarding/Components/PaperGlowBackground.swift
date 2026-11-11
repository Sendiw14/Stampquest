import SwiftUI

/// Paper colour, a soft glow behind the content and paper grain.
struct PaperGlowBackground: View {
    /// Height of the glow ellipse and the vertical position of its centre, as fractions of the screen.
    var glowHeight: CGFloat = 0.3
    var glowCenterY: CGFloat = 0.52

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                OnbColor.background
                glow(in: proxy.size)
                GrainTexture(lightOpacity: 0.07, darkOpacity: 0.05)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// An ellipse 80% of the width and `glowHeight` of the height, centred at 50% / `glowCenterY` of the screen, clear at 70% of
    /// its radius.
    private func glow(in size: CGSize) -> some View {
        let radius: CGFloat = 100
        return Rectangle()
            .fill(RadialGradient(stops: [.init(color: OnbColor.screenGlow, location: 0), .init(color: OnbColor.screenGlow.opacity(0), location: 0.7)],
                                 center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(x: size.width * 0.8 / radius, y: size.height * glowHeight / radius)
            .position(x: size.width * 0.5, y: size.height * glowCenterY)
    }
}
