import SwiftUI

extension StampState {
    /// Colour that accompanies (never replaces) the icon and label.
    var tint: Color {
        switch self {
        case .notCollected: SQColor.textTertiary
        case .wishlisted: SQColor.wishlist
        case .collected: SQColor.manual
        case .verified: SQColor.verified
        }
    }
}

/// Shows where a stamp stands. Always icon + text, so colour is never the only cue.
struct StampCollectionStateBadge: View {
    let state: StampState
    var compact: Bool = false

    var body: some View {
        HStack(spacing: SQSpace.xxs) {
            Image(systemName: state.symbolName)
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .imageScale(.small)
            if !compact {
                Text(state.shortTitle)
                    .font(SQFont.label)
            }
        }
        .foregroundStyle(state.tint)
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(state.tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(state.tint.opacity(0.3), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.title)
    }
}
