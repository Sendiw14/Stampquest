import SwiftUI

/// Top bar of the paper-style onboarding screens: a back chevron, the 25-dot progress strip centred, and Skip. Each
/// button has a 44 x 44 pt target; the strip reads as one "Step n of 5" element.
struct OnboardingTopBar: View {
    /// Prefix for accessibility identifiers: `onboarding.<screen>.<element>`.
    let screen: String
    let step: Int
    var animatesStrip = true
    /// False holds the current group of dots empty until it turns true.
    var fillsStrip = true
    /// Entrance: each part fades in when its flag turns true.
    var backShown = true
    var skipShown = true
    var stripShown = true
    /// Replaces the spoken "Step n of 5".
    var progressLabel: LocalizedStringKey?
    let onBack: () -> Void
    /// Nil hides Skip.
    var onSkip: (() -> Void)?

    static let height: CGFloat = 44

    var body: some View {
        ZStack {
            PunchProgressStrip(step: step, of: OnboardingRoute.progressStepCount, animated: animatesStrip, style: .interests,
                               fillsCurrent: fillsStrip, accessibilityLabelKey: progressLabel)
                .opacity(stripShown ? 1 : 0)
            HStack(spacing: 0) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(OnbColor.accentText)
                        .frame(width: Self.height, height: Self.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("onboarding.common.back"))
                .accessibilityIdentifier("onboarding.\(screen).back")
                .modifier(FadeUp(shown: backShown))
                .padding(.leading, 18 - 12)
                Spacer(minLength: 0)
                if let onSkip {
                    Button(action: onSkip) {
                        Text("onboarding.common.skip")
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(-0.011 * 17)
                            .foregroundStyle(OnbColor.accentText)
                            .frame(minWidth: Self.height, minHeight: Self.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.\(screen).skip")
                    .modifier(FadeUp(shown: skipShown))
                    .padding(.trailing, 24 - 12)
                }
            }
        }
        .frame(height: Self.height)
    }
}
