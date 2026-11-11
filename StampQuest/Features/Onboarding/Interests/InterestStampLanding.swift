import SwiftUI

/// Keyframe effects of picking an interest. Each plays once when its layer appears; `instant` shows the finished state
/// (Reduce Motion, or a stamp that was already picked when the screen opened).
struct StampLandingEffect: ViewModifier {
    let instant: Bool
    /// 0...1 sheen position while idle and tilted; negative for none.
    let idleSheen: Double

    @State private var played = false

    private struct Values {
        var offset = -38.0
        var scale = 1.32
        var rotation = -7.0
        var opacity = 0.0
        var sheen = -1.0
    }

    private nonisolated static let shape = FixedPitchPerforatedShape(pitch: InterestsMetrics.stampPitch, notchRatio: 0.29)
    private nonisolated static let peak = 0.55

    func body(content: Content) -> some View {
        if instant {
            content.foilSheen(progress: idleSheen, in: Self.shape, peak: Self.peak, warmth: 0)
                .scaleEffect(InterestsMetrics.selectedScale)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.foilSheen(progress: value.sheen >= 0 ? value.sheen : idleSheen, in: Self.shape, peak: Self.peak, warmth: 0)
                    .scaleEffect(value.scale)
                    .rotationEffect(.degrees(value.rotation))
                    .offset(y: value.offset)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.offset) {
                    CubicKeyframe(3, duration: 0.322)
                    CubicKeyframe(-1, duration: 0.149)
                    CubicKeyframe(0, duration: 0.149)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.985, duration: 0.322)
                    CubicKeyframe(1.055, duration: 0.149)
                    CubicKeyframe(InterestsMetrics.selectedScale, duration: 0.149)
                }
                KeyframeTrack(\.rotation) {
                    CubicKeyframe(1, duration: 0.322)
                    CubicKeyframe(0, duration: 0.298)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: 0.155)
                    LinearKeyframe(1, duration: 0.465)
                }
                KeyframeTrack(\.sheen) {
                    LinearKeyframe(-1, duration: InterestsTimeline.Pick.sheenDelay)
                    LinearKeyframe(0, duration: 0.001)
                    CubicKeyframe(1, duration: InterestsTimeline.Pick.sheenDuration)
                    LinearKeyframe(-1, duration: 0.001)
                }
            }
            .onAppear { played = true }
        }
    }
}

/// The check badge pops in 0.2 s after the stamp lands: 1.5x down to .93, up to 1.035, settling at 1, from 20 pt up.
struct BadgePopEffect: ViewModifier {
    let instant: Bool
    @State private var played = false

    private struct Values {
        var scale = 1.5
        var offset = -20.0
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        if instant {
            content
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).offset(y: value.offset).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1.5, duration: InterestsTimeline.Pick.badgeDelay)
                    CubicKeyframe(0.93, duration: 0.28)
                    CubicKeyframe(1.035, duration: 0.2)
                    CubicKeyframe(1, duration: 0.16)
                }
                KeyframeTrack(\.offset) {
                    LinearKeyframe(-20, duration: InterestsTimeline.Pick.badgeDelay)
                    CubicKeyframe(2, duration: 0.32)
                    CubicKeyframe(0, duration: 0.32)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: InterestsTimeline.Pick.badgeDelay)
                    CubicKeyframe(1, duration: 0.16)
                    LinearKeyframe(1, duration: 0.48)
                }
            }
            .onAppear { played = true }
        }
    }
}
