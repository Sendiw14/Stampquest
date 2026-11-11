import SwiftUI

/// Colours and press feel of a `PrimaryCapsuleButton`.
struct CapsuleButtonStyle {
    let fill: Color
    let label: Color
    let shadow: Color
    let pressScale: CGFloat
    let feedback: SensoryFeedback
    /// Fill and label while disabled; nil dims the enabled look instead.
    var disabledFill: Color?
    var disabledLabel: Color?

    /// The Welcome poster: a selection tick, .97 on press.
    static let welcome = CapsuleButtonStyle(fill: WelcomeColor.ctaFill, label: WelcomeColor.ctaLabel, shadow: WelcomeColor.ctaShadow,
                                            pressScale: 0.97, feedback: .selection)
    /// The paper screens: a light impact, .962 on press.
    static let paper = CapsuleButtonStyle(fill: OnbColor.ctaFill, label: OnbColor.ctaLabel, shadow: OnbColor.ctaShadow,
                                          pressScale: 0.962, feedback: .impact(weight: .light),
                                          disabledFill: OnbColor.ctaDisabledFill, disabledLabel: OnbColor.ctaDisabledLabel)
}

/// Capsule call to action: a label, 58 pt tall, with a soft coloured shadow and a 1 pt top highlight. Pressing springs
/// it down and fires a haptic. `showsArrow` adds the trailing arrow.
struct PrimaryCapsuleButton: View {
    let title: LocalizedStringKey
    var identifier: String
    var style = CapsuleButtonStyle.welcome
    var showsArrow = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                if showsArrow { Image(systemName: "arrow.right").imageScale(.medium) }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryCapsuleButtonStyle(style: style))
        .accessibilityIdentifier(identifier)
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    let style: CapsuleButtonStyle

    @Environment(\.obReducesMotion) private var reduceMotion
    @Environment(\.obHapticsEnabled) private var hapticsEnabled
    @Environment(\.legibilityWeight) private var legibility
    @Environment(\.isEnabled) private var isEnabled

    static let height: CGFloat = 58

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: legibility == .bold ? .bold : .semibold))
            .foregroundStyle(isEnabled ? style.label : (style.disabledLabel ?? style.label))
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background(isEnabled ? style.fill : (style.disabledFill ?? style.fill), in: Capsule())
            .background {
                Capsule().fill(style.shadow).padding(.horizontal, 12).offset(y: 14).blur(radius: 12)
                    .opacity(isEnabled ? 1 : 0)
            }
            .overlay {
                Capsule().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            }
            .contentShape(Capsule())
            .opacity(isEnabled || style.disabledFill != nil ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: isEnabled)
            .scaleEffect(configuration.isPressed && !reduceMotion ? style.pressScale : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(style.feedback, trigger: configuration.isPressed) { _, pressed in pressed && hapticsEnabled }
    }
}
