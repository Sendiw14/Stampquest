import SwiftUI

/// Three perforated preview stamps (the pack's hero in front), an owned badge, and on purchase a ring pulse and a small bump. Each stamp is
/// flattened once by `StampCard`, so only transforms and opacity move.
struct PackStack: View {
    let pack: Pack
    let isOwned: Bool
    let ownedCount: Int
    let player: BeatPlayer<ExitBeat>
    let reduceMotion: Bool

    static let size = CGSize(width: 78, height: 80)

    private struct Bump {
        var scale = 1.0
        var rotation = 0.0
    }

    private struct Pulse {
        var scale = 0.8
        var opacity = 0.0
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ring
            ZStack(alignment: .topLeading) {
                stamp(pack.stamps[safe: 1], size: CGSize(width: 46, height: 56), pitch: 6, paper: OnbColor.stampCities, rotation: -12, at: CGPoint(x: 0, y: 18))
                    .exitBeat(.stackLeft, player, style: .slide(x: 18, y: 8, scale: 0.6, duration: 0.5), reduceMotion: reduceMotion)
                stamp(pack.stamps[safe: 2], size: CGSize(width: 46, height: 56), pitch: 6, paper: OnbColor.stampFood, rotation: 11, at: CGPoint(x: 31, y: 14))
                    .exitBeat(.stackRight, player, style: .slide(x: -18, y: 8, scale: 0.6, duration: 0.5), reduceMotion: reduceMotion)
                stamp(pack.stamps[safe: 0], size: CGSize(width: 52, height: 64), pitch: 7, paper: OnbColor.stampCoasts, rotation: 0, at: CGPoint(x: 13, y: 8))
                    .exitBeat(.stackFront, player, style: .slide(x: 0, y: 16, scale: 0.7, duration: 0.6), reduceMotion: reduceMotion)
            }
            .modifier(PackBumpEffect(trigger: ownedCount, instant: reduceMotion))
            badge
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stamp(_ destination: StampDestination?, size: CGSize, pitch: CGFloat, paper: Color, rotation: Double, at origin: CGPoint) -> some View {
        if let destination {
            StampCard(size: size, paper: paper, pitch: pitch, borderRatio: 0.09, captionRatio: 0.06) { StampArtCanvas(style: destination.style) }
                .shadow(color: OnbColor.shadowSoft, radius: 3, y: 6)
                .rotationEffect(.degrees(rotation))
                .offset(x: origin.x, y: origin.y)
        }
    }

    private var badge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .heavy)) // audit:fixed-glyph: inside a fixed-size badge or icon button
            .foregroundStyle(OnbColor.ctaLabel)
            .frame(width: 22, height: 22)
            .background(OnbColor.ctaFill, in: Circle())
            .overlay { Circle().strokeBorder(OnbColor.passportPaper, lineWidth: 2) }
            .scaleEffect(isOwned || reduceMotion ? 1 : 0.3)
            .opacity(isOwned ? 1 : 0)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .timingCurve(0.3, 1.25, 0.4, 1, duration: 0.45).delay(0.12), value: isOwned)
            .offset(x: 54, y: 0)
    }

    @ViewBuilder
    private var ring: some View {
        if !reduceMotion {
            Circle()
                .stroke(OnbColor.ctaFill, lineWidth: 2)
                .frame(width: 70, height: 70)
                .keyframeAnimator(initialValue: Pulse(), trigger: ownedCount) { view, value in
                    view.scaleEffect(value.scale).opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(0.8, duration: 0.05)
                        CubicKeyframe(2, duration: 0.75)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0, duration: 0.05)
                        LinearKeyframe(0.75, duration: 0.105)
                        CubicKeyframe(0, duration: 0.645)
                    }
                }
                .offset(x: (Self.size.width - 70) / 2, y: (Self.size.height - 70) / 2)
        }
    }
}

/// 1 to 1.1x and -3 degrees at 35%, .98x and +1 degree at 70%, then rest (0.6 s).
private struct PackBumpEffect: ViewModifier {
    let trigger: Int
    let instant: Bool

    private struct Values {
        var scale = 1.0
        var rotation = 0.0
    }

    func body(content: Content) -> some View {
        if instant { content } else {
            content.keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.scaleEffect(value.scale).rotationEffect(.degrees(value.rotation))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.1, duration: 0.21)
                    CubicKeyframe(0.98, duration: 0.21)
                    CubicKeyframe(1, duration: 0.18)
                }
                KeyframeTrack(\.rotation) {
                    CubicKeyframe(-3, duration: 0.21)
                    CubicKeyframe(1, duration: 0.21)
                    CubicKeyframe(0, duration: 0.18)
                }
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
