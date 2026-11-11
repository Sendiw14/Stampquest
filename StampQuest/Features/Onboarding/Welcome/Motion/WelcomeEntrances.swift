import SwiftUI

/// Entrance effects of the Welcome intro. Each plays when `played` turns true; `instant` shows the finished state
/// without animation (Reduce Motion, tap to skip).
extension WelcomeIntroTimeline {
    /// Animation that reveals `beat` when its state flips.
    static func animation(for beat: Beat) -> Animation {
        switch beat {
        case .topRow: .smooth(duration: 0.62)
        case .progress: .smooth(duration: 0.3)
        case .waves: .smooth(duration: 0.55)
        default: .smooth(duration: 0.5)
        }
    }
}

/// A fan stamp dropped from 150 pt above at 1.14x with a spring that overshoots by about 9 pt (.82 s).
struct FanDropEffect: ViewModifier {
    let played: Bool
    let instant: Bool

    private struct Values {
        var offset = -150.0
        var scale = 1.14
        var opacity = 0.0
    }

    private static let spring = Spring(response: 0.45, dampingRatio: 0.66)

    func body(content: Content) -> some View {
        if instant {
            content.opacity(played ? 1 : 0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).offset(y: value.offset).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.offset) { SpringKeyframe(0, duration: 0.82, spring: Self.spring) }
                KeyframeTrack(\.scale) { SpringKeyframe(1, duration: 0.82, spring: Self.spring) }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: 0.14)
                    CubicKeyframe(1, duration: 0.68)
                }
            }
        }
    }
}

/// The postmark pressed onto the stamp: 1.7x down to .90, up to 1.05, settling at 1 (.56 s).
struct PostmarkPressEffect: ViewModifier {
    let played: Bool
    let instant: Bool

    private struct Values {
        var scale = 1.7
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        if instant {
            content.opacity(played ? 1 : 0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.9, duration: 0.26)
                    CubicKeyframe(1.05, duration: 0.16)
                    CubicKeyframe(1, duration: 0.14)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: 0.14)
                    CubicKeyframe(1, duration: 0.42)
                }
            }
        }
    }
}
