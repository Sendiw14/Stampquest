import SwiftUI

/// A starter as a full-width row, for accessibility text sizes: a 60 x 78 thumbnail, the name and the country.
struct StarterStampRow: View {
    let starter: StarterStamp
    let isDimmed: Bool
    let onTap: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                StarterStampCard(starter: starter, size: CGSize(width: 60, height: 78))
                    .saturation(isDimmed ? 0.5 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(starter.destination.name).font(.headline).foregroundStyle(OnbColor.inkPrimary)
                    Text(starter.destination.country).font(.subheadline).foregroundStyle(OnbColor.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .opacity(isDimmed ? (contrast == .increased ? FirstStampMetrics.dimmedOpacityIncreasedContrast : FirstStampMetrics.dimmedOpacity) : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isDimmed ? "onboarding.firstStamp.a11y.starterDimmed \(starter.destination.name) \(starter.destination.country)"
                                          : "onboarding.firstStamp.a11y.starter \(starter.destination.name) \(starter.destination.country)"))
        .accessibilityHint(Text("onboarding.firstStamp.a11y.starterHint \(starter.destination.name)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(starter.accessibilityIdentifier)
    }
}
