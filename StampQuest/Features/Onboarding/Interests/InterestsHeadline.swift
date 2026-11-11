import SwiftUI

/// "What do you love to [find]?": 40 pt Heavy words in a flow layout, with the marked word set in a perforated stamp
/// frame. The stamp is not separately focusable: the whole headline is one header element.
struct InterestsHeadline: View {
    let entrance: InterestsEntrance

    @ScaledMetric(relativeTo: .largeTitle) private var size = InterestsMetrics.headlineSize

    private static let markup = String(localized: "onboarding.interests.title")

    var body: some View {
        Group {
            if let tokens = HeadlineMarkup.parse(markdown: Self.markup) {
                HeadlineFlowLayout(lineHeight: size * InterestsMetrics.headlineLineHeight / InterestsMetrics.headlineSize,
                                   spaceWidth: size * 0.2, growsForTallItems: true) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        tokenView(token, beat: InterestsTimeline.beat(forTokenAt: index, in: tokens))
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
        .accessibilityIdentifier("onboarding.interests.title")
    }

    private var font: Font { .system(size: size, weight: .heavy) }

    @ViewBuilder
    private func tokenView(_ token: HeadlineMarkup.Token, beat: InterestsTimeline.Beat) -> some View {
        switch token.kind {
        case .highlight:
            StampWordFrame(word: token.text, size: size, style: .interests(size: size))
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
