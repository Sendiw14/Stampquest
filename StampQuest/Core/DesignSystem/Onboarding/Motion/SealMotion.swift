import SwiftUI

/// The seal dropping onto a stamp 0.10 s after the switch: from 1.9x, 46 pt up and tilted -14 degrees, down to .90,
/// up to 1.04, settling at 1 (0.8 s, ease-out), then one foil sheen pass. `instant` shows the finished seal.
struct SealDropEffect: ViewModifier {
    let instant: Bool
    /// 0...1 sheen position while idle and tilted; negative for none.
    let idleSheen: Double

    @State private var played = false

    private struct Values {
        var opacity = 0.0
        var scale = 1.9
        var offset = -46.0
        var rotation = -14.0
        var sheen = -1.0
    }

    private static let delay = 0.10
    private nonisolated static let shape = ScallopedCircle()

    func body(content: Content) -> some View {
        if instant {
            content.foilSheen(progress: idleSheen, in: Self.shape, peak: 0.55, warmth: 0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.foilSheen(progress: value.sheen >= 0 ? value.sheen : idleSheen, in: Self.shape, peak: 0.55, warmth: 0)
                    .scaleEffect(value.scale)
                    .rotationEffect(.degrees(value.rotation))
                    .offset(y: value.offset)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: Self.delay)
                    CubicKeyframe(1, duration: 0.4)
                    LinearKeyframe(1, duration: 0.4)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1.9, duration: Self.delay)
                    CubicKeyframe(0.9, duration: 0.4)
                    CubicKeyframe(1.04, duration: 0.2)
                    CubicKeyframe(1, duration: 0.2)
                }
                KeyframeTrack(\.offset) {
                    LinearKeyframe(-46, duration: Self.delay)
                    CubicKeyframe(3, duration: 0.4)
                    CubicKeyframe(0, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                }
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(-14, duration: Self.delay)
                    CubicKeyframe(2, duration: 0.4)
                    CubicKeyframe(0, duration: 0.4)
                }
                KeyframeTrack(\.sheen) {
                    LinearKeyframe(-1, duration: 0.70)
                    LinearKeyframe(0, duration: 0.001)
                    CubicKeyframe(1, duration: 0.85)
                    LinearKeyframe(-1, duration: 0.001)
                }
            }
            .onAppear { played = true }
        }
    }
}

/// A gold ring that swells from the seal 0.55 s after the switch: 1 to 1.55x, fading in to .65 and out (0.75 s).
struct GoldRingEffect: ViewModifier {
    let trigger: Int

    private struct Values {
        var scale = 1.0
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
            view.scaleEffect(value.scale).opacity(value.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1, duration: 0.55)
                CubicKeyframe(1.55, duration: 0.75)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(0, duration: 0.55)
                CubicKeyframe(0.65, duration: 0.075)
                CubicKeyframe(0, duration: 0.675)
            }
        }
    }
}

/// The stamp pressing down 2 pt and back (0.3 s) when the seal lands, 0.5 s after the switch.
struct HeroDipEffect: ViewModifier {
    let trigger: Int

    private struct Values {
        var offset = 0.0
        var scale = 1.0
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
            view.scaleEffect(value.scale).offset(y: value.offset)
        } keyframes: { _ in
            KeyframeTrack(\.offset) {
                LinearKeyframe(0, duration: 0.5)
                CubicKeyframe(2, duration: 0.15)
                CubicKeyframe(0, duration: 0.15)
            }
            KeyframeTrack(\.scale) {
                LinearKeyframe(1, duration: 0.5)
                CubicKeyframe(0.99, duration: 0.15)
                CubicKeyframe(1, duration: 0.15)
            }
        }
    }
}
