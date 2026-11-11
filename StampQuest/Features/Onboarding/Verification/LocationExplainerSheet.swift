import SwiftUI

/// The pre-permission sheet: what verified stamps use location for, before iOS asks. "Continue" is the only path to the
/// system prompt; "Not now" never reaches it. The sheet is as tall as its content (measured, so there is no empty gap), scrolls when
/// the text is large, and is full height from accessibility text sizes.
struct LocationExplainerSheet: View {
    let onContinue: () -> Void
    let onNotNow: () -> Void

    @ScaledMetric(relativeTo: .title2) private var titleSize = 24.0
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @ScaledMetric(relativeTo: .headline) private var linkSize = 17.0
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content.background(GeometryReader { Color.clear.preference(key: ExplainerHeightKey.self, value: $0.size.height) })
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(ExplainerHeightKey.self) { contentHeight = $0 }
        .background(OnbColor.background)
        .presentationDetents(typeSize >= .accessibility1 || contentHeight == 0 ? [.large] : [.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("onboarding.verification.explainer.title")
                .font(.system(size: titleSize, weight: .heavy))
                .tracking(-0.02 * titleSize)
                .foregroundStyle(OnbColor.inkPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("onboarding.verification.explainer.body")
                .font(.system(size: bodySize))
                .lineSpacing(3)
                .foregroundStyle(OnbColor.inkSecondary)
            PrimaryCapsuleButton(title: "onboarding.verification.explainer.continue",
                                 identifier: "onboarding.verification.explainer.continue", style: .paper, showsArrow: false, action: onContinue)
                .padding(.top, 12)
            Button(action: onNotNow) {
                Text("onboarding.verification.explainer.notNow")
                    .font(.system(size: linkSize, weight: .semibold))
                    .foregroundStyle(OnbColor.accentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.verification.explainer.notNow")
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

private struct ExplainerHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
