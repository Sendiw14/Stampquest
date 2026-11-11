import SwiftUI

/// The stamp card of a starter: its pastel border, artwork and serif caption.
struct StarterStampCard: View {
    let starter: StarterStamp
    var size = FirstStampMetrics.starterSize
    /// False when a postmark sits over the stamp's corner: the "No. 01" label is hidden under the ring instead of colliding with its text.
    var showsNumber = true

    var body: some View {
        StampCard(size: size, paper: starter.paper, pitch: size.width / FirstStampMetrics.starterSize.width * FirstStampMetrics.starterPitch) {
            StampArtCanvas(style: starter.destination.style)
        } caption: { band in
            SerifStampCaption(label: starter.destination.label, number: showsNumber ? starter.destination.numberLabel : "", stampWidth: size.width, band: band)
        }
    }
}

/// The name pill under a starter: the name and the country on a dark capsule.
struct StarterPill: View {
    let starter: StarterStamp

    var body: some View {
        HStack(spacing: 3) {
            Text(starter.destination.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(OnbColor.pillLabel)
            Text(starter.destination.country).font(.system(size: 13)).foregroundStyle(OnbColor.pillSublabel)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 11)
        .background(OnbColor.pillFill, in: Capsule())
        .fixedSize()
        .shadow(color: .black.opacity(0.25), radius: 6, y: 5)
    }
}

/// A starter on the desk: the stamp and its pill as one button. While pressed or saving the stamp lifts to 1.1x with a
/// deeper shadow; that is acknowledgement, not success.
struct StarterStampButton: View {
    let starter: StarterStamp
    let isBusy: Bool
    let showsStamp: Bool
    let isDimmed: Bool
    let pillDimmed: Bool
    let failureCount: Int
    let reduceMotion: Bool
    let stampShown: Bool
    let pillShown: Bool
    let instant: Bool
    let onTouchDown: () -> Void
    let onTap: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var showsSpinner = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .top) {
                stamp.frame(width: FirstStampMetrics.starterSize.width, height: FirstStampMetrics.starterSize.height)
                StarterPill(starter: starter)
                    .opacity(pillDimmed ? 0.45 : 1)
                    .modifier(FadeUp(shown: pillShown, rise: 8))
                    .padding(.top, FirstStampMetrics.pillTop)
            }
            .frame(width: 110, height: 150, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(StarterPressStyle(isBusy: isBusy, reduceMotion: reduceMotion, onTouchDown: onTouchDown))
        .task(id: isBusy) {
            showsSpinner = false
            guard isBusy else { return }
            try? await Task.sleep(for: .seconds(FirstStampMetrics.busyIndicatorDelay))
            showsSpinner = !Task.isCancelled
        }
    }

    @ViewBuilder
    private var stamp: some View {
        if showsStamp {
            StarterStampCard(starter: starter)
                .overlay { if showsSpinner { ProgressView().tint(OnbColor.pillFill) } }
                .rotationEffect(.degrees(starter.deskRotation))
                .saturation(isDimmed ? 0.5 : 1)
                .opacity(isDimmed ? (contrast == .increased ? FirstStampMetrics.dimmedOpacityIncreasedContrast : FirstStampMetrics.dimmedOpacity) : 1)
                .modifier(StarterDropEffect(played: stampShown, instant: instant))
                .modifier(ShakeEffect(trigger: reduceMotion ? 0 : failureCount))
        }
    }
}

/// Pressed look: 1.1x with a deeper shadow over 0.18 s, plus the shadow the stamp rests with.
private struct StarterPressStyle: ButtonStyle {
    let isBusy: Bool
    let reduceMotion: Bool
    let onTouchDown: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        let lifted = configuration.isPressed || isBusy
        configuration.label
            .scaleEffect(lifted && !reduceMotion ? FirstStampMetrics.pressedScale : 1)
            .shadow(color: OnbColor.shadowDeep, radius: lifted ? 8 : 6, y: lifted ? 18 : 12)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: lifted)
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { onTouchDown() } }
    }
}

/// A starter dropped onto the desk: from 150 pt above at 1.14x, a 9 pt overshoot, then settling (0.82 s).
struct StarterDropEffect: ViewModifier {
    let played: Bool
    let instant: Bool

    private struct Values {
        var offset = -150.0
        var scale = 1.14
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        if instant {
            content.opacity(played ? 1 : 0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).offset(y: value.offset).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.offset) {
                    CubicKeyframe(9, duration: 0.40)
                    CubicKeyframe(-3, duration: 0.22)
                    CubicKeyframe(0, duration: 0.20)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.975, duration: 0.40)
                    CubicKeyframe(1.01, duration: 0.22)
                    CubicKeyframe(1, duration: 0.20)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: 0.246)
                    LinearKeyframe(1, duration: 0.574)
                }
            }
        }
    }
}
