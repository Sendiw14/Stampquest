import SwiftUI

/// "Your passport / is [ready].": 40 pt Heavy, with the marked word in a terracotta stamp frame (never the verified colour: that means a
/// verified stamp). At accessibility sizes the layout wraps the stamp word onto its own line. One header element.
struct ReadyHeadline: View {
    let entrance: BeatPlayer<ReadyTimeline.Beat>

    @ScaledMetric(relativeTo: .largeTitle) private var size = InterestsMetrics.headlineSize

    private static let markup = String(localized: "onboarding.ready.title")

    var body: some View {
        Group {
            if let tokens = HeadlineMarkup.parse(markdown: Self.markup) {
                HeadlineFlowLayout(lineHeight: size * 1.1, spaceWidth: 8, growsForTallItems: true, tightGap: 2) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        tokenView(token, beat: ReadyTimeline.beat(forTokenAt: index, in: tokens))
                            .layoutValue(key: SpaceBeforeKey.self, value: token.spaceBefore)
                            .layoutValue(key: LineBreakBeforeKey.self, value: token.lineBreakBefore)
                    }
                }
            } else {
                Text(HeadlineMarkup.plainText(Self.markup)).font(.system(size: size, weight: .heavy)).foregroundStyle(OnbColor.inkPrimary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HeadlineMarkup.plainText(Self.markup)))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.ready.title")
    }

    @ViewBuilder
    private func tokenView(_ token: HeadlineMarkup.Token, beat: ReadyTimeline.Beat) -> some View {
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
