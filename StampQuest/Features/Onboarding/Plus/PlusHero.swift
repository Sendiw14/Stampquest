import SwiftUI

/// The decorative hero: the Midnight passport (engraved with the holder's name, if there is one), the Santorini and Kyoto stamps behind it
/// and the Plus seal on its corner. Purely visual, so it is hidden from VoiceOver. Everything is a cached bitmap; only transforms,
/// opacity and the sheen move.
struct PlusHero: View {
    let holderName: String
    let entrance: BeatPlayer<PlusTimeline.Beat>
    let reduceMotion: Bool
    /// Counts successful purchases: each one re-thumps the seal and sweeps the sheen across the cover.
    let successCount: Int

    private var coverHeight: CGFloat { PlusMetrics.coverWidth * CoverMetrics.designSize.height / CoverMetrics.designSize.width }
    private var instant: Bool { reduceMotion || entrance.isInstant }

    var body: some View {
        ZStack(alignment: .top) {
            glow
            stamp(.santorini, side: -1, top: 42, rotation: -10, appear: .stampLeft, float: .floatLeft)
            stamp(.kyoto, side: 1, top: 44, rotation: 9, appear: .stampRight, float: .floatRight)
            coverGroup
        }
        .frame(maxWidth: .infinity)
        .frame(height: PlusMetrics.heroHeight, alignment: .top)
        .accessibilityHidden(true)
    }

    private var glow: some View {
        Ellipse()
            .fill(RadialGradient(colors: [OnbColor.screenGlow, OnbColor.screenGlow.opacity(0)], center: .center, startRadius: 0, endRadius: 150))
            .frame(width: 340, height: 250)
            .offset(y: 30)
            .opacity(entrance.has(.cover) ? 1 : 0)
    }

    private func stamp(_ starter: StarterStamp, side: CGFloat, top: CGFloat, rotation: Double, appear: PlusTimeline.Beat,
                       float: PlusTimeline.Beat) -> some View {
        let shown = entrance.has(appear)
        return StampCard(size: PlusMetrics.stampSize, paper: starter.paper, pitch: PlusMetrics.stampPitch) {
            StampArtCanvas(style: starter.destination.style)
        } caption: { band in
            SerifStampCaption(label: starter.destination.label, number: starter.destination.numberLabel,
                              stampWidth: PlusMetrics.stampSize.width, band: band)
        }
        .shadow(color: OnbColor.shadowSoft, radius: 5, y: 6)
        .rotationEffect(.degrees(rotation))
        .modifier(IdleFloat(active: entrance.has(float) && !reduceMotion))
        .offset(x: shown || instant ? 0 : side * 46, y: shown || instant ? 0 : 12)
        .scaleEffect(shown || instant ? 1 : 0.9)
        .opacity(shown ? 1 : 0)
        .animation(instant ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7), value: shown)
        .offset(x: side * PlusMetrics.stampOffsetX, y: top)
    }

    private var coverGroup: some View {
        ZStack(alignment: .topLeading) {
            PassportCover(style: .midnight, holderName: holderName, width: PlusMetrics.coverWidth)
                .modifier(SuccessSheen(trigger: successCount, instant: instant))
                .shadow(color: OnbColor.shadowDeep, radius: 10, y: 20)
            ZStack {
                PlusSeal()
                    .modifier(SealThumpEffect(style: .entrance, trigger: entrance.has(.seal) ? 1 : 0, instant: instant))
                    .modifier(SealThumpEffect(style: .success, trigger: successCount, instant: instant))
                SealRipple(trigger: entrance.has(.sealLand) ? 1 : 0, instant: instant)
                SealRipple(trigger: successCount, instant: instant)
            }
            .rotationEffect(.degrees(12))
            .offset(x: PlusMetrics.coverWidth - 30, y: coverHeight - 38)
        }
        .frame(width: PlusMetrics.coverWidth, height: coverHeight, alignment: .topLeading)
        .modifier(CoverRiseEffect(played: entrance.has(.cover), instant: instant))
        .modifier(IdleFloat(active: entrance.has(.floatCover) && !reduceMotion))
    }
}

/// One foil sheen pass across the cover (0.9 s) each time `trigger` changes. Uses the app's `foilSheen`, which falls back to a gradient
/// band where the Metal library is missing.
private struct SuccessSheen: ViewModifier {
    let trigger: Int
    let instant: Bool

    func body(content: Content) -> some View {
        if instant {
            content
        } else {
            content.keyframeAnimator(initialValue: -1.0, trigger: trigger) { view, progress in
                view.foilSheen(progress: progress, in: RoundedRectangle(cornerRadius: 8, style: .continuous), peak: 0.7, warmth: 0)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(0, duration: 0.001)
                    CubicKeyframe(1, duration: 0.9)
                    LinearKeyframe(-1, duration: 0.001)
                }
            }
        }
    }
}

/// A slow vertical drift of +-4 pt over 5.4 s. The modifier is always applied so the view keeps its identity; it only moves while `active`.
struct IdleFloat: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content.phaseAnimator(active ? [0.0, 4.0, 0.0, -4.0] : [0.0]) { view, offset in
            view.offset(y: offset)
        } animation: { _ in
            .easeInOut(duration: 1.35)
        }
    }
}
