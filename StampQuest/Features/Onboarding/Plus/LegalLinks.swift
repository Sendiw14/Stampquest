import SwiftUI

/// Restore purchases, Terms and Privacy: always present, each with a 44 pt target. The URLs come from `AppConfiguration`; a missing one
/// is a bug that stops a debug build.
struct LegalLinks: View {
    let terms: URL?
    let privacy: URL?
    let isRestoreEnabled: Bool
    let restore: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var size = 13.0

    init(terms: URL? = AppConfiguration.termsURL, privacy: URL? = AppConfiguration.privacyPolicyURL, isRestoreEnabled: Bool = true,
         restore: @escaping () -> Void) {
        assert(terms != nil && privacy != nil, "Set AppConfiguration.termsURL and privacyPolicyURL: the Plus paywall must link to both.")
        self.terms = terms
        self.privacy = privacy
        self.isRestoreEnabled = isRestoreEnabled
        self.restore = restore
    }

    var body: some View {
        HStack(spacing: 26) {
            Button(action: restore) { label("onboarding.plus.restore") }
                .disabled(!isRestoreEnabled)
                .accessibilityIdentifier("onboarding.plus.restore")
            link("onboarding.plus.terms", url: terms, identifier: "onboarding.plus.terms")
            link("onboarding.plus.privacy", url: privacy, identifier: "onboarding.plus.privacy")
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
    }

    private func label(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(OnbColor.inkSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func link(_ key: LocalizedStringKey, url: URL?, identifier: String) -> some View {
        if let url { Link(destination: url) { label(key) }.accessibilityIdentifier(identifier) } else { label(key) }
    }
}
