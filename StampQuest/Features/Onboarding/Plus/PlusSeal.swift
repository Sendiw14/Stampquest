import SwiftUI

/// The Plus seal: a scalloped terracotta disc with a cream ring, a star and "PLUS" on an arc, on a 100 unit canvas. Its colours are the
/// same in light and dark, and it is flattened once (`drawingGroup`).
struct PlusSeal: View {
    var size: CGFloat = PlusMetrics.sealSize

    static let cream = Color(.sRGB, red: 0xFF / 255, green: 0xF1 / 255, blue: 0xDC / 255)
    private static let gradient = Gradient(stops: [
        .init(color: Color(.sRGB, red: 0xE9 / 255, green: 0x90 / 255, blue: 0x6A / 255), location: 0),
        .init(color: Color(.sRGB, red: 0xC0 / 255, green: 0x66 / 255, blue: 0x3F / 255), location: 0.45),
        .init(color: Color(.sRGB, red: 0x86 / 255, green: 0x47 / 255, blue: 0x2C / 255), location: 1),
    ])

    var body: some View {
        Canvas { context, canvas in
            let scale = canvas.width / 100
            context.translateBy(x: canvas.width / 2, y: canvas.height / 2)
            context.scaleBy(x: scale, y: scale)
            let box = CGRect(x: -50, y: -50, width: 100, height: 100)
            context.fill(ScallopedCircle().path(in: box),
                         with: .linearGradient(Self.gradient, startPoint: CGPoint(x: -40, y: -50), endPoint: CGPoint(x: 40, y: 50)))
            context.stroke(Path(ellipseIn: CGRect(x: -37, y: -37, width: 74, height: 74)), with: .color(Self.cream.opacity(0.85)), lineWidth: 1.4)
            context.stroke(Path(ellipseIn: CGRect(x: -22, y: -22, width: 44, height: 44)), with: .color(Self.cream.opacity(0.5)), lineWidth: 0.9)
            ArcText.draw("PLUS", in: &context, center: .zero, radius: 25.5, tracking: 2.4, placement: .top,
                         font: .system(size: 9.5, weight: .heavy), color: Self.cream)
            var star = context
            star.translateBy(x: 0, y: 4)
            star.scaleBy(x: 0.5, y: 0.5)
            star.fill(StarShape.unitPath, with: .color(Self.cream))
        }
        .frame(width: size, height: size)
        .drawingGroup()
        .shadow(color: OnbColor.shadowSoft, radius: 4, y: 5)
        .accessibilityHidden(true)
    }
}

/// The seal thumping onto the cover: scale and tilt only. `.entrance` is the first landing (2.1x, -16 degrees, 0.55 s); `.success`
/// is the second thump when Plus starts (1.32x, -9 degrees, 0.6 s).
struct SealThumpEffect: ViewModifier {
    enum Style { case entrance, success }

    let style: Style
    let trigger: Int
    let instant: Bool

    private struct Values {
        var scale: Double
        var rotation: Double
        var opacity: Double
    }

    func body(content: Content) -> some View {
        if instant {
            content.opacity(style == .success || trigger > 0 ? 1 : 0)
        } else {
            switch style {
            case .entrance:
                content.keyframeAnimator(initialValue: Values(scale: 2.1, rotation: -16, opacity: 0), trigger: trigger) { view, value in
                    view.scaleEffect(value.scale).rotationEffect(.degrees(value.rotation)).opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(0.93, duration: 0.30)
                        CubicKeyframe(1.04, duration: 0.14)
                        CubicKeyframe(1, duration: 0.11)
                    }
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(2, duration: 0.30)
                        CubicKeyframe(0, duration: 0.25)
                    }
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(1, duration: 0.30)
                        LinearKeyframe(1, duration: 0.25)
                    }
                }
            case .success:
                content.keyframeAnimator(initialValue: Values(scale: 1, rotation: 0, opacity: 1), trigger: trigger) { view, value in
                    view.scaleEffect(value.scale).rotationEffect(.degrees(value.rotation))
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.32, duration: 0.228)
                        CubicKeyframe(0.95, duration: 0.192)
                        CubicKeyframe(1, duration: 0.18)
                    }
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(-9, duration: 0.228)
                        CubicKeyframe(0, duration: 0.372)
                    }
                }
            }
        }
    }
}

/// A 60 pt ring that widens from the seal: opacity 0 to .75 at 14% and back to 0, scale .8 to 2, 0.8 s. `trigger` counts the plays.
struct SealRippleEffect: ViewModifier {
    let trigger: Int
    let instant: Bool

    private struct Values {
        var scale = 0.8
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        if instant {
            content.opacity(0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) { CubicKeyframe(2, duration: 0.8) }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.75, duration: 0.112)
                    CubicKeyframe(0, duration: 0.688)
                }
            }
        }
    }
}

/// The ring itself, in the mode-independent ripple colour #F2B48E.
struct SealRipple: View {
    let trigger: Int
    let instant: Bool

    var body: some View {
        Circle()
            .stroke(Color(.sRGB, red: 0xF2 / 255, green: 0xB4 / 255, blue: 0x8E / 255), lineWidth: 2)
            .frame(width: PlusMetrics.sealSize, height: PlusMetrics.sealSize)
            .modifier(SealRippleEffect(trigger: trigger, instant: instant))
            .allowsHitTesting(false)
    }
}
