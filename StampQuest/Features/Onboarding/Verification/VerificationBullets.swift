import SwiftUI

/// The three promises under the preview. Each row is one accessibility element; the icon is decorative.
struct VerificationBullets: View {
    let entrance: BeatPlayer<VerificationTimeline.Beat>

    @ScaledMetric(relativeTo: .callout) private var textSize = 15.0

    private static let rows: [(symbol: String, key: LocalizedStringKey)] = [
        ("mappin.and.ellipse", "onboarding.verification.trust.optional"),
        ("clock", "onboarding.verification.trust.foreground"),
        ("lock", "onboarding.verification.trust.private"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 13) {
                    Image(systemName: row.symbol)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(OnbColor.accentText)
                        .frame(width: 19)
                        .accessibilityHidden(true)
                    Text(row.key)
                        .font(.system(size: textSize))
                        .foregroundStyle(OnbColor.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 22, alignment: .leading)
                .modifier(FadeUp(shown: entrance.has(.bullet(index))))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.leading, 62 - 35)
    }
}
