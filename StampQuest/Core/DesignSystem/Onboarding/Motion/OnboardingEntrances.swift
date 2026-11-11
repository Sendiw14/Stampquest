import SwiftUI

/// Entrance effects shared by the onboarding screens. Each plays when its state flips; `instant` shows the finished
/// state without animation (Reduce Motion, a revisit, a skipped intro).

/// Fade plus a short rise.
struct FadeUp: ViewModifier {
    let shown: Bool
    var rise: CGFloat = 16

    func body(content: Content) -> some View {
        content.opacity(shown ? 1 : 0).offset(y: shown ? 0 : rise)
    }
}

/// A stamp-word frame stamped onto the page: from 20 pt up at 1.5x, down to .93, up to 1.035, settling at 1 (.64 s),
/// with a 2 pt bounce in the last third.
struct StampInEffect: ViewModifier {
    let played: Bool
    let instant: Bool

    private struct Values {
        var scale = 1.5
        var offset = -20.0
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        if instant {
            content.opacity(played ? 1 : 0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).offset(y: value.offset).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.93, duration: 0.32)
                    CubicKeyframe(1.035, duration: 0.18)
                    CubicKeyframe(1, duration: 0.14)
                }
                KeyframeTrack(\.offset) {
                    CubicKeyframe(0, duration: 0.32)
                    CubicKeyframe(2, duration: 0.18)
                    CubicKeyframe(0, duration: 0.14)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: 0.12)
                    CubicKeyframe(1, duration: 0.52)
                }
            }
        }
    }
}

/// A postmark thumping onto a stamp after `delay`: 2.1x down to .93, up to 1.04, settling at 1, while turning from -16
/// degrees through +2 to rest.
struct PostmarkThumpEffect: ViewModifier {
    let instant: Bool
    var delay: TimeInterval = 0.30
    @State private var played = false

    private struct Values {
        var scale = 2.1
        var rotation = -16.0
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        if instant {
            content
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).rotationEffect(.degrees(value.rotation)).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(2.1, duration: delay)
                    CubicKeyframe(0.93, duration: 0.26)
                    CubicKeyframe(1.04, duration: 0.13)
                    CubicKeyframe(1, duration: 0.13)
                }
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(-16, duration: delay)
                    CubicKeyframe(2, duration: 0.26)
                    CubicKeyframe(0, duration: 0.26)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: delay)
                    CubicKeyframe(1, duration: 0.13)
                    LinearKeyframe(1, duration: 0.39)
                }
            }
            .onAppear { played = true }
        }
    }
}

/// An outline that widens from the stamp and fades, once per pick (`trigger` counts the picks).
struct RippleEffect: ViewModifier {
    let trigger: Int
    var delay: TimeInterval = 0.12

    private struct Values {
        var scale = 1.0
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
            view.scaleEffect(value.scale).opacity(value.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(1, duration: delay)
                CubicKeyframe(1.4, duration: 0.6)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(0, duration: delay)
                LinearKeyframe(0.6, duration: 0.001)
                CubicKeyframe(0, duration: 0.6)
            }
        }
    }
}
