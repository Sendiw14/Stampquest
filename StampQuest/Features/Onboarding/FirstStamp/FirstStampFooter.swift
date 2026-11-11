import SwiftUI

/// The line under the desk: where the stamp is kept, or the error with "Try again".
struct FirstStampNote: View {
    let viewModel: FirstStampViewModel
    /// The collected wording (after the swap) and whether the text is showing.
    let collected: Bool
    let textVisible: Bool
    let shown: Bool
    var focusRetry: AccessibilityFocusState<FirstStampScreen.Focus?>.Binding
    let onRetry: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var size = 13.0

    var body: some View {
        Group {
            if viewModel.failure != nil {
                HStack(spacing: 8) {
                    Text("onboarding.firstStamp.status.error").accessibilityIdentifier("onboarding.firstStamp.error")
                    Button(action: onRetry) {
                        Text("onboarding.firstStamp.tryAgain")
                            .foregroundStyle(OnbColor.accentText)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityFocused(focusRetry, equals: .retry)
                    .accessibilityIdentifier("onboarding.firstStamp.tryAgain")
                }
            } else {
                text.opacity(textVisible ? 1 : 0).offset(y: textVisible ? 0 : -6)
                    .accessibilityIdentifier("onboarding.firstStamp.status")
            }
        }
        .font(.system(size: size, weight: .medium))
        .tracking(-0.006 * size)
        .foregroundStyle(OnbColor.inkTertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .modifier(FadeUp(shown: shown, rise: 0))
    }

    @ViewBuilder
    private var text: some View {
        if collected, let date = viewModel.collectedAt {
            if Calendar.current.isDateInToday(date) {
                Text("onboarding.firstStamp.status.done.today")
            } else {
                Text("onboarding.firstStamp.status.done.date \(date.formatted(date: .abbreviated, time: .omitted))")
            }
        } else {
            Text("onboarding.firstStamp.status.choose")
        }
    }
}

/// "Continue": disabled until the stamp is saved and the reveal has enabled it.
struct FirstStampContinueButton: View {
    let isEnabled: Bool
    let shown: Bool
    let action: () -> Void

    var body: some View {
        PrimaryCapsuleButton(title: "onboarding.firstStamp.cta", identifier: "onboarding.firstStamp.cta", style: .paper, showsArrow: false,
                             action: action)
            .disabled(!isEnabled)
            .accessibilityHint(isEnabled ? Text(verbatim: "") : Text("onboarding.firstStamp.a11y.ctaHint"))
            .modifier(FadeUp(shown: shown))
    }
}
