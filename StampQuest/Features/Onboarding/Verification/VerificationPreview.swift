import SwiftUI

/// The hero: the Paris stamp with, on its corner, either the "COLLECTED" postmark or the illustrative gold seal, and a
/// warm glow behind it when verified. It is an example; nothing here belongs to the person's real stamp.
struct VerificationPreview: View {
    let preview: VerificationViewModel.Preview
    let landingID: Int
    let verifiedCount: Int
    let date: String
    let reduceMotion: Bool
    let tilt: TiltParallax
    let postmarkShown: Bool
    let instant: Bool

    static let stampSize = CGSize(width: 132, height: 172)
    static let overlaySize: CGFloat = 100
    static let groupSize = CGSize(width: 236, height: 238)
    private static let stampOrigin = CGPoint(x: 30, y: 20)

    private var isVerified: Bool { preview == .verified }
    private var overlayOrigin: CGPoint {
        CGPoint(x: Self.stampOrigin.x + Self.stampSize.width - 56 + StampPostmark.labelClearance.width,
                y: Self.stampOrigin.y + Self.stampSize.height - 74 + StampPostmark.labelClearance.height)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            glow
            StarterStampCard(starter: .paris, size: Self.stampSize, showsNumber: false)
                .rotationEffect(.degrees(-2))
                .shadow(color: OnbColor.shadowSoft, radius: 8, y: 16)
                .modifier(HeroDipEffect(trigger: reduceMotion ? 0 : verifiedCount))
                .offset(x: Self.stampOrigin.x, y: Self.stampOrigin.y)
            overlay
        }
        .frame(width: Self.groupSize.width, height: Self.groupSize.height, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isVerified ? "onboarding.verification.a11y.hero.verified" : "onboarding.verification.a11y.hero.collected"))
        .accessibilityIdentifier(isVerified ? "verification.seal" : "verification.postmark")
    }

    private var glow: some View {
        Ellipse()
            .fill(RadialGradient(colors: [OnbColor.goldGlow, OnbColor.goldGlow.opacity(0)], center: .center, startRadius: 0, endRadius: 100))
            .frame(width: 190, height: 210)
            .offset(x: Self.groupSize.width / 2 - 95, y: Self.groupSize.height / 2 - 105 + 4)
            .opacity(isVerified ? 1 : 0)
            .animation(glowAnimation, value: isVerified)
            .accessibilityHidden(true)
    }

    private var glowAnimation: Animation {
        if reduceMotion { return .easeInOut(duration: 0.2) }
        return isVerified ? .easeOut(duration: 0.7).delay(0.35) : .easeOut(duration: 0.45)
    }

    // MARK: Overlay

    /// Both versions are keyed by `landingID`, so the latest switch always wins and one overlay is on screen once it settles.
    @ViewBuilder
    private var overlay: some View {
        Group {
            if isVerified {
                seal.id(landingID)
            } else if postmarkShown {
                postmark.id(landingID)
            }
        }
        .frame(width: Self.overlaySize, height: Self.overlaySize)
        .rotationEffect(.degrees(12))
        .offset(x: overlayOrigin.x, y: overlayOrigin.y)
    }

    private var seal: some View {
        let idleSheen = reduceMotion || tilt.tilt.x == 0 ? -1 : 0.5 + tilt.tilt.x * 0.5
        return ZStack {
            Circle().stroke(OnbColor.goldWordFill, lineWidth: 2)
                .modifier(GoldRingEffect(trigger: reduceMotion ? 0 : verifiedCount))
            GoldSeal(date: date, size: Self.overlaySize)
                .modifier(SealDropEffect(instant: reduceMotion || instant, idleSheen: idleSheen))
        }
        .transition(leave(.modifier(active: SealLeave(active: true), identity: SealLeave(active: false)), animation: .easeIn(duration: 0.3)))
    }

    private var postmark: some View {
        StampPostmark(top: String(localized: "onboarding.verification.postmark"), bottom: date, style: .collected,
                      size: Self.overlaySize, ink: OnbColor.postmark)
            .modifier(PostmarkThumpEffect(instant: reduceMotion || (instant && landingID == 0), delay: landingID == 0 ? 0 : VerificationTimeline.postmarkReturnDelay))
            .transition(leave(.modifier(active: PostmarkLeave(active: true), identity: PostmarkLeave(active: false)), animation: .easeOut(duration: 0.25)))
    }

    /// Reduce Motion cross-fades; otherwise a layer leaves with its own transition and appears with none.
    private func leave(_ leaving: AnyTransition, animation: Animation) -> AnyTransition {
        reduceMotion ? .opacity.animation(.easeInOut(duration: 0.2)) : .asymmetric(insertion: .identity, removal: leaving.animation(animation))
    }
}

/// The seal leaving: opacity to 0, scale .9, 14 pt up.
private struct SealLeave: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.scaleEffect(active ? 0.9 : 1).offset(y: active ? -14 : 0).opacity(active ? 0 : 1)
    }
}

/// The postmark leaving: opacity to 0, scale .85, 6 pt up.
private struct PostmarkLeave: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.scaleEffect(active ? 0.85 : 1).offset(y: active ? -6 : 0).opacity(active ? 0 : 1)
    }
}
