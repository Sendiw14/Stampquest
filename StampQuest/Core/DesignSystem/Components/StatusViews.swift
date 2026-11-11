import SwiftUI

extension View {
    /// Keeps long-form content at a comfortable reading width on iPad and landscape.
    func sqReadableWidth(_ maxWidth: CGFloat = 720) -> some View {
        self.frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }

    /// The standard paper-coloured screen background.
    func sqScreenBackground() -> some View {
        self.background(SQColor.background.ignoresSafeArea())
    }
}

/// A designed empty state with an optional single action.
struct EmptyStateView<Art: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?
    @ViewBuilder var art: () -> Art

    var body: some View {
        VStack(spacing: SQSpace.md) {
            art()
                .padding(.bottom, SQSpace.xs)
            Text(title)
                .font(SQFont.section)
                .foregroundStyle(SQColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(SQFont.body)
                .foregroundStyle(SQColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                PrimaryActionButton(title: actionTitle, action: action)
                    .padding(.top, SQSpace.xs)
                    .frame(maxWidth: 320)
            }
        }
        .padding(SQSpace.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// The default art for an empty state: a single light SF Symbol.
struct EmptyStateSymbol: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(SQColor.accent)
            .accessibilityHidden(true)
    }
}

extension EmptyStateView where Art == EmptyStateSymbol {
    init(title: LocalizedStringKey, message: LocalizedStringKey, systemImage: String,
         actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.init(title: title, message: message, actionTitle: actionTitle, action: action) {
            EmptyStateSymbol(name: systemImage)
        }
    }
}

struct LoadingStateView: View {
    var message: LocalizedStringKey = "Loading…"

    var body: some View {
        VStack(spacing: SQSpace.sm) {
            ProgressView()
            Text(message).font(SQFont.meta).foregroundStyle(SQColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }
}

/// An in-place error that says what happened, whether data was saved, and what to do next.
struct InlineErrorView: View {
    let title: LocalizedStringKey
    let message: String
    var retryTitle: LocalizedStringKey = "Try again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(SQFont.headline)
                .foregroundStyle(SQColor.error)
            Text(message)
                .font(SQFont.subheadline)
                .foregroundStyle(SQColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(retryTitle, action: retry)
                    .font(SQFont.subheadline.weight(.semibold))
                    .foregroundStyle(SQColor.accentText)
                    .padding(.top, SQSpace.xxs)
            }
        }
        .padding(SQSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SQColor.error.opacity(0.10), in: RoundedRectangle(cornerRadius: SQRadius.medium, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// Shown only where a feature genuinely needs a connection (map tiles).
struct OfflineBanner: View {
    var body: some View {
        Label("You’re offline. Map tiles may be missing, but everything else works.", systemImage: "wifi.slash")
            .font(SQFont.caption)
            .foregroundStyle(SQColor.textSecondary)
            .padding(.horizontal, SQSpace.md)
            .padding(.vertical, SQSpace.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
    }
}

/// A progress bar that reads as "N of M" to VoiceOver.
struct AccessibleProgressIndicator: View {
    let value: Int
    let total: Int
    var tint: Color = SQColor.accent
    var height: CGFloat = 8

    private var fraction: Double { total == 0 ? 0 : min(1, Double(value) / Double(total)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(SQColor.stone.opacity(0.5))
                Capsule().fill(tint)
                    .frame(width: max(fraction > 0 ? height : 0, geo.size.width * fraction))
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(value) of \(total)")
    }
}
