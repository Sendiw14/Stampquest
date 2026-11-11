import SwiftUI

/// Keyframe values of the stamp's flight from the desk to slot 1.
struct FlightValues {
    var offset = CGSize.zero
    var scale = FirstStampMetrics.pressedScale
    /// Extra rotation on top of the desk tilt, in degrees.
    var rotation = 0.0
    var shadowY = 18.0
    var shadowBlur = 16.0
    /// Foil sheen position: negative while resting.
    var sheen = -1.0
}

/// Flies the stamp along the arc to slot 1 and leaves it there: lift, apex above the slot, contact, settle, then one
/// foil sheen pass. `instant` shows the final pose (Reduce Motion, a restored screen, an interrupted reveal).
struct StampFlightEffect: ViewModifier {
    let trigger: Int
    let instant: Bool
    let target: FlightTarget
    let finalScale: CGFloat
    let finalRotation: Double

    private static var flight: TimeInterval { RevealChoreography.flightDuration }
    private nonisolated static let shape = FixedPitchPerforatedShape(pitch: FirstStampMetrics.starterPitch, notchRatio: 0.29)

    func body(content: Content) -> some View {
        let shadow = OnbColor.shadowDeep
        if instant {
            content.scaleEffect(finalScale)
                .rotationEffect(.degrees(finalRotation))
                .shadow(color: shadow, radius: 7, y: 14)
                .offset(target.end)
        } else {
            content.keyframeAnimator(initialValue: FlightValues(), trigger: trigger) { view, value in
                view.foilSheen(progress: value.sheen, in: Self.shape, peak: 0.55, warmth: 0)
                    .scaleEffect(value.scale)
                    .rotationEffect(.degrees(value.rotation))
                    .shadow(color: shadow, radius: value.shadowBlur / 2, y: value.shadowY)
                    .offset(value.offset)
            } keyframes: { _ in
                KeyframeTrack(\.offset) {
                    CubicKeyframe(CGSize(width: 0, height: -12), duration: duration(0.16))
                    CubicKeyframe(target.apex, duration: duration(0.62 - 0.16))
                    CubicKeyframe(target.contact, duration: duration(0.82 - 0.62))
                    CubicKeyframe(target.end, duration: duration(1 - 0.82))
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.10, duration: duration(0.16))
                    CubicKeyframe(1.02, duration: duration(0.62 - 0.16))
                    CubicKeyframe(0.87, duration: duration(0.82 - 0.62))
                    CubicKeyframe(finalScale, duration: duration(1 - 0.82))
                }
                KeyframeTrack(\.rotation) {
                    CubicKeyframe(-2, duration: duration(0.16))
                    CubicKeyframe(3, duration: duration(0.62 - 0.16))
                    CubicKeyframe(2.6, duration: duration(0.82 - 0.62))
                    CubicKeyframe(finalRotation, duration: duration(1 - 0.82))
                }
                KeyframeTrack(\.shadowY) {
                    CubicKeyframe(28, duration: duration(0.16))
                    CubicKeyframe(34, duration: duration(0.62 - 0.16))
                    CubicKeyframe(8, duration: duration(0.82 - 0.62))
                    CubicKeyframe(14, duration: duration(1 - 0.82))
                }
                KeyframeTrack(\.shadowBlur) {
                    CubicKeyframe(22, duration: duration(0.16))
                    CubicKeyframe(26, duration: duration(0.62 - 0.16))
                    CubicKeyframe(8, duration: duration(0.82 - 0.62))
                    CubicKeyframe(14, duration: duration(1 - 0.82))
                }
                KeyframeTrack(\.sheen) {
                    LinearKeyframe(-1, duration: RevealChoreography.standard.delay(of: .sheen))
                    LinearKeyframe(0, duration: 0.001)
                    CubicKeyframe(1, duration: 0.85)
                    LinearKeyframe(-1, duration: 0.001)
                }
            }
        }
    }

    private func duration(_ fraction: Double) -> TimeInterval { Self.flight * fraction }
}

/// The page pressing down 2 pt when the stamp touches it and coming back (0.30 s, 40% down).
struct PagePressEffect: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(y: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(RevealChoreography.pageBump, duration: 0.12)
                CubicKeyframe(0, duration: 0.18)
            }
        }
    }
}

/// A horizontal shake of +-6 pt, three cycles in 0.3 s, once per failed save.
struct ShakeEffect: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(6, duration: 0.05)
                CubicKeyframe(-6, duration: 0.05)
                CubicKeyframe(6, duration: 0.05)
                CubicKeyframe(-6, duration: 0.05)
                CubicKeyframe(6, duration: 0.05)
                CubicKeyframe(-6, duration: 0.05)
                CubicKeyframe(0, duration: 0.001)
            }
        }
    }
}
