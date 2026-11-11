import SwiftUI

/// First run only: three informational rows and the footnote. Not tappable.
struct HowItWorks: View {
    private let rows: [(icon: String, title: LocalizedStringKey, text: LocalizedStringKey, verified: Bool)] = [
        ("hand.tap", "Collect", "Add a stamp by hand. Free, offline, no account.", false),
        ("checkmark.seal.fill", "Verify", "Be there and confirm once. The stamp earns a gold seal.", true),
        ("note.text", "Remember", "Add a note and photos. Private by default.", false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "How it works")
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 14) {
                    Image(systemName: row.icon).font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(row.verified ? HomeColor.verifiedGold : HomeColor.label)
                        .frame(width: 34, height: 34).background(HomeColor.tint, in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.ink)
                        Text(row.text).font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 64)
                .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(HomeColor.cardLine.opacity(0.7), lineWidth: 1))
                .accessibilityElement(children: .combine)
            }
            Text("Collecting by hand is always welcome. A gold seal only comes from a verified visit.")
                .font(.system(size: 13)).foregroundStyle(HomeColor.sub).padding(.top, 4)
        }
    }
}

/// The full-width ghost action under Picked for you on first run.
struct ExploreAllButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Explore all places").font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.label)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(HomeColor.cta, lineWidth: 1.4))
        }
        .buttonStyle(.plain).accessibilityIdentifier("home-explore")
    }
}
