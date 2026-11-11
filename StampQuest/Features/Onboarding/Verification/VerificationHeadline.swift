import SwiftUI

/// "Collected is [yours]." / "Verified is [earned].": 32 pt Heavy words in a flow layout, with the two marked words set
/// in a terracotta and a gold stamp frame. One header element for VoiceOver.
struct VerificationHeadline: View {
    let entrance: BeatPlayer<VerificationTimeline.Beat>

    @ScaledMetric(relativeTo: .largeTitle) private var size = 32.0

    private static let markup = String(localized: "onboarding.verification.title")

    var body: some View {
        Group {
            if let tokens = HeadlineMarkup.parse(markdown: Self.markup) {
                HeadlineFlowLayout(lineHeight: size * 36 / 32, spaceWidth: size * 0.25, growsForTallItems: true, tightGap: 2) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        tokenView(token, beat: VerificationTimeline.beat(forTokenAt: index, in: tokens))
                            .layoutValue(key: SpaceBeforeKey.self, value: token.spaceBefore)
                            .layoutValue(key: LineBreakBeforeKey.self, value: token.lineBreakBefore)
                    }
                }
            } else {
                Text(HeadlineMarkup.plainText(Self.markup)).font(font).foregroundStyle(OnbColor.inkPrimary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HeadlineMarkup.plainText(Self.markup)))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.verification.title")
    }

    private var font: Font { .system(size: size, weight: .heavy) }

    @ViewBuilder
    private func tokenView(_ token: HeadlineMarkup.Token, beat: VerificationTimeline.Beat) -> some View {
        switch token.kind {
        case .highlight(let index):
            StampWordFrame(word: token.text, size: size, style: .verification(index: index, size: size))
                .modifier(StampInEffect(played: entrance.has(beat), instant: entrance.isInstant))
        case .plain:
            Text(token.text)
                .font(font)
                .tracking(-0.04 * size)
                .foregroundStyle(OnbColor.inkPrimary)
                .fixedSize()
                .modifier(FadeUp(shown: entrance.has(beat)))
        }
    }
}
