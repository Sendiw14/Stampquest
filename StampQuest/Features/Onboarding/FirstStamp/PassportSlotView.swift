import SwiftUI

/// A slot on the passport page: the hot first slot with its star and pulse ring, or an empty one. A perforated
/// outline with notches at 0.29 of the pitch.
struct PassportSlotView: View {
    enum Kind: Equatable {
        /// The slot the first stamp goes to; `pulsing` shows the ring.
        case hot(pulsing: Bool)
        case empty
    }

    let kind: Kind
    var size = FirstStampMetrics.slotSize
    var pitch = FirstStampMetrics.slotPitch

    private var shape: FixedPitchPerforatedShape { FixedPitchPerforatedShape(pitch: pitch, notchRatio: 0.29) }
    private var dash: StrokeStyle { StrokeStyle(lineWidth: lineWidth, dash: FirstStampMetrics.slotDash) }
    private var lineWidth: CGFloat { kind == .empty ? FirstStampMetrics.slotLineWidth : FirstStampMetrics.hotLineWidth }

    var body: some View {
        ZStack {
            shape.fill(OnbColor.slotFill)
            switch kind {
            case .empty:
                shape.stroke(OnbColor.slotOutline, style: dash)
            case .hot(let pulsing):
                shape.stroke(OnbColor.accent, style: dash)
                StarShape()
                    .fill(OnbColor.accent.opacity(0.75))
                    .frame(width: FirstStampMetrics.hotStarRadius * 2, height: FirstStampMetrics.hotStarRadius * 2)
                if pulsing { PulseRing(shape: shape, dash: dash) }
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}

/// An outline that swells 1 to 1.16 while it fades from .6 to 0 over 1.9 s, then rests, again and again.
private struct PulseRing: View {
    let shape: FixedPitchPerforatedShape
    let dash: StrokeStyle

    private struct Values {
        var scale = 1.0
        var opacity = 0.0
    }

    var body: some View {
        shape.stroke(OnbColor.accent, style: dash)
            .keyframeAnimator(initialValue: Values(), repeating: true) { view, value in
                view.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1, duration: 0.001)
                    CubicKeyframe(1.16, duration: 1.9)
                    LinearKeyframe(1, duration: 0.7)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.6, duration: 0.001)
                    CubicKeyframe(0, duration: 1.9)
                    LinearKeyframe(0, duration: 0.7)
                }
            }
    }
}
