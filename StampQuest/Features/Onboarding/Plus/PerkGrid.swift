import SwiftUI

/// The perk tiles: two columns (one at accessibility text sizes). A lone last tile spans the full width. Each tile is one VoiceOver
/// element inside an "Included with Plus" container.
struct PerkGrid: View {
    let perks: [PlusPerk]
    let entrance: BeatPlayer<PlusTimeline.Beat>
    let reduceMotion: Bool
    var singleColumn = false

    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .footnote) private var labelSize = 13.0
    @ScaledMetric(relativeTo: .footnote) private var discSize = 30.0

    var body: some View {
        VStack(spacing: PlusMetrics.tileGap) {
            ForEach(PlusMetrics.perkRows(count: perks.count, columns: singleColumn ? 1 : 2), id: \.self) { row in
                HStack(spacing: PlusMetrics.tileColumnGap) {
                    ForEach(row, id: \.self) { tile(perks[$0], index: $0) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("onboarding.plus.perks.a11y"))
        .accessibilityIdentifier("onboarding.plus.perks")
    }

    private func tile(_ perk: PlusPerk, index: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: perk.symbol)
                .font(.system(size: discSize * 17 / 30, weight: .medium))
                .foregroundStyle(OnbColor.ctaFill)
                .frame(width: discSize, height: discSize)
                .background(OnbColor.selectedTint, in: Circle())
            Text(LocalizedStringKey(perk.titleKey))
                .font(.system(size: labelSize, weight: .medium))
                .foregroundStyle(OnbColor.inkPrimary)
                .lineSpacing(1)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: PlusMetrics.tileHeight, alignment: .leading)
        .background(OnbColor.passportPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(contrast == .increased ? OnbColor.inkPrimary.opacity(0.45) : OnbColor.cardHairline,
                              lineWidth: contrast == .increased ? 1.5 : 1)
        }
        .modifier(FadeUp(shown: entrance.has(.perk(index)), rise: reduceMotion ? 0 : 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(perk.titleKey)))
        .accessibilityIdentifier("onboarding.plus.perk.\(index)")
    }
}
