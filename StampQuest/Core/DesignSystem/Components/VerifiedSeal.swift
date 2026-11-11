import SwiftUI

/// The gold seal of a verified visit: a scalloped disc with a map pin. Gold appears nowhere else on the Passport screen,
/// so this is the only place that draws it. Decorative to VoiceOver; callers say "Verified visit" in words.
struct VerifiedSeal: View {
    var size: CGFloat = 26

    private static let gradient = Gradient(stops: [
        .init(color: StampArt.ink(0xFDF1C6), location: 0), .init(color: HomeColor.verifiedGold, location: 0.34),
        .init(color: StampArt.ink(0xC99432), location: 0.7), .init(color: StampArt.ink(0x8A5A12), location: 1),
    ])

    var body: some View {
        ZStack {
            ScallopedCircle().fill(RadialGradient(gradient: Self.gradient, center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: size * 0.95))
            Circle().strokeBorder(.white.opacity(0.5), lineWidth: max(0.5, size * 0.024)).padding(size * 0.2)
            Image(systemName: "mappin").font(.system(size: size * 0.4, weight: .heavy)).foregroundStyle(OnbColor.sealInk)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 70 / 255, green: 42 / 255, blue: 0, opacity: 0.35), radius: size * 0.08, y: size * 0.12)
        .accessibilityHidden(true)
    }
}
