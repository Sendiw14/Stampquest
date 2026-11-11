import SwiftUI

struct SQPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SQFont.headline)
            .foregroundStyle(isEnabled ? SQColor.onAccent : SQColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, SQSpace.md)
            .background(isEnabled ? SQColor.accentStrong : SQColor.disabled.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(SQMotion.quick, value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
    }
}

struct SQSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SQFont.headline)
            .foregroundStyle(isEnabled ? SQColor.accentText : SQColor.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, SQSpace.md)
            .background(SQColor.surface.opacity(configuration.isPressed ? 0.7 : 1),
                        in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous)
                .strokeBorder(SQColor.border, lineWidth: 1))
            .animation(SQMotion.quick, value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
    }
}

struct SQIconButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(prominent ? SQColor.onAccent : SQColor.textPrimary)
            .frame(width: SQHit.minimum, height: SQHit.minimum)
            .background(prominent ? SQColor.accentStrong : SQColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(prominent ? .clear : SQColor.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Circle())
    }
}

extension ButtonStyle where Self == SQPrimaryButtonStyle {
    static var sqPrimary: SQPrimaryButtonStyle { SQPrimaryButtonStyle() }
}
extension ButtonStyle where Self == SQSecondaryButtonStyle {
    static var sqSecondary: SQSecondaryButtonStyle { SQSecondaryButtonStyle() }
}

/// The main call to action on a screen. One per screen.
struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SQSpace.xs) {
                if isLoading {
                    ProgressView().tint(SQColor.onAccent)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.sqPrimary)
        .disabled(isLoading)
    }
}

struct SecondaryActionButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SQSpace.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.sqSecondary)
    }
}

/// A round icon button with a mandatory accessibility label.
struct IconActionButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: systemImage) }
            .buttonStyle(SQIconButtonStyle(prominent: prominent))
            .accessibilityLabel(label)
    }
}
