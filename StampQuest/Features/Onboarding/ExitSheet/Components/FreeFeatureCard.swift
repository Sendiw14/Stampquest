import SwiftUI

/// What the free passport keeps: up to three rows, each a check badge and a line. Rows grow if the text wraps.
struct FreeFeatureCard: View {
    let features: [FreeTierFeature]
    let player: BeatPlayer<ExitBeat>
    let reduceMotion: Bool

    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var textSize = 15.0
    @ScaledMetric(relativeTo: .body) private var rowMin = 40.0

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in row(feature, index: index) }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(OnbColor.freeCardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(contrast == .increased ? OnbColor.inkPrimary.opacity(0.35) : OnbColor.cardHairline, lineWidth: 1)
        }
        .exitBeat(.card, player, reduceMotion: reduceMotion)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("exit.a11y.list"))
        .accessibilityIdentifier("exitSheet.free")
    }

    private func row(_ feature: FreeTierFeature, index: Int) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy)) // audit:fixed-glyph: inside a fixed-size badge or icon button
                .foregroundStyle(OnbColor.ctaLabel)
                .frame(width: 20, height: 20)
                .background(OnbColor.ctaFill, in: Circle())
                .exitBeat(.check(index), player, style: .popIn, reduceMotion: reduceMotion)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(feature.key))
                .font(.system(size: textSize, weight: .medium))
                .tracking(-0.011 * textSize)
                .foregroundStyle(OnbColor.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .exitBeat(.row(index), player, style: .fadeUp(duration: 0.5), reduceMotion: reduceMotion)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: rowMin)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("exit.a11y.included \(String(localized: String.LocalizationValue(feature.key)))"))
    }
}
