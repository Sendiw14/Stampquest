import SwiftUI

/// "Pick your [cover].": 40 pt Heavy, with the marked word in a terracotta stamp frame. One header element.
struct CoverHeadline: View {
    let entrance: BeatPlayer<CoverTimeline.Beat>

    @ScaledMetric(relativeTo: .largeTitle) private var size = InterestsMetrics.headlineSize

    private static let markup = String(localized: "onboarding.cover.title")

    var body: some View {
        Group {
            if let tokens = HeadlineMarkup.parse(markdown: Self.markup) {
                flow(tokens)
            } else {
                Text(HeadlineMarkup.plainText(Self.markup)).font(.system(size: size, weight: .heavy)).foregroundStyle(OnbColor.inkPrimary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HeadlineMarkup.plainText(Self.markup)))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.cover.title")
    }

    /// At accessibility sizes the layout simply wraps the stamp word under "Pick your".
    private func flow(_ tokens: [HeadlineMarkup.Token]) -> some View {
        HeadlineFlowLayout(lineHeight: size * 1.5, spaceWidth: 8, growsForTallItems: true, tightGap: 2) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { offset, token in
                tokenView(token, beat: CoverTimeline.beat(forTokenAt: offset, in: tokens))
                    .layoutValue(key: SpaceBeforeKey.self, value: token.spaceBefore)
            }
        }
    }

    @ViewBuilder
    private func tokenView(_ token: HeadlineMarkup.Token, beat: CoverTimeline.Beat) -> some View {
        switch token.kind {
        case .highlight:
            StampWordFrame(word: token.text, size: size, style: .interests(size: size))
                .modifier(StampInEffect(played: entrance.has(beat), instant: entrance.isInstant))
        case .plain:
            Text(token.text)
                .font(.system(size: size, weight: .heavy))
                .tracking(-0.04 * size)
                .foregroundStyle(OnbColor.inkPrimary)
                .fixedSize()
                .modifier(FadeUp(shown: entrance.has(beat)))
        }
    }
}
