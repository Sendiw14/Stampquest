import SwiftUI

/// Replaces the call to action once Plus starts ("Trial started. Welcome to Plus.") or while a purchase waits for approval. Tinted
/// with the accent at 10% (light) / 17% (dark); the check pops 0.3 s after the banner arrives.
struct StatusBanner: View {
    enum Kind: Equatable { case success, waiting }

    let text: String
    let kind: Kind

    @Environment(\.obReducesMotion) private var reduceMotion
    @State private var iconShown = false
    @ScaledMetric(relativeTo: .body) private var textSize = 17.0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind == .success ? "checkmark" : "hourglass")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(OnbColor.ctaLabel)
                .frame(width: 26, height: 26)
                .background(OnbColor.ctaFill, in: Circle())
                .scaleEffect(iconShown || reduceMotion ? 1 : 0.3)
            Text(verbatim: text)
                .font(.system(size: textSize, weight: .semibold))
                .foregroundStyle(OnbColor.inkPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: PlusMetrics.ctaHeight)
        .background(OnbColor.selectedTint, in: RoundedRectangle(cornerRadius: PlusMetrics.ctaHeight / 2, style: .continuous))
        .task {
            guard !reduceMotion else { iconShown = true; return }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { iconShown = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
        .accessibilityIdentifier("onboarding.plus.banner")
    }
}
