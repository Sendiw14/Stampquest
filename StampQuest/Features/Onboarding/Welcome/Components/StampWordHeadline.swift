import SwiftUI

/// "Your [world], one [stamp] at a time.": 56 pt Heavy words laid out by `HeadlineFlowLayout`, with the two
/// highlighted words set in perforated stamp frames. Falls back to plain text with the words highlighted when the
/// string does not fit its line count.
struct StampWordHeadline: View {
    /// The localized headline with `{highlighted}` words.
    let markup: String
    let size: CGFloat
    /// Lines the stamp-frame layout may use; nil goes straight to plain text.
    var maxLines: Int? = WelcomeMetrics.headlineLineCount
    let shown: Set<WelcomeIntroTimeline.Beat>
    let instant: Bool
    let tilt: TiltParallax

    private var lineHeight: CGFloat { size * WelcomeMetrics.headlineLineHeight / WelcomeMetrics.headlineSize }
    private var accessibilityText: String { HeadlineMarkup.plainText(markup) }
    /// How much taller than a text line a stamp frame is (74 pt against 60 at the reference size). The two framed lines grow by this, so the
    /// frames never run into the line below.
    private var frameExtra: CGFloat { max(0, StampWordStyle.welcome(index: 0, size: size).height - lineHeight) }

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: accessibilityText))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("onboarding.welcome.headline")
    }

    @ViewBuilder
    private var content: some View {
        if let tokens = HeadlineMarkup.parse(markup) {
            if let maxLines {
                ViewThatFits(in: .vertical) {
                    flow(tokens)
                    plain(tokens)
                }
                .frame(maxHeight: lineHeight * CGFloat(maxLines) + 2 * frameExtra + size * 0.2, alignment: .topLeading)
            } else {
                plain(tokens)
            }
        } else {
            Text(verbatim: accessibilityText).font(font).foregroundStyle(WelcomeColor.textPrimary)
        }
    }

    private var font: Font { .system(size: size, weight: .heavy) }

    private func flow(_ tokens: [HeadlineMarkup.Token]) -> some View {
        HeadlineFlowLayout(lineHeight: lineHeight, spaceWidth: size * 0.24, growsForTallItems: true) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                tokenView(token, beat: HeadlineMarkup.beat(forTokenAt: index, in: tokens))
                    .layoutValue(key: SpaceBeforeKey.self, value: token.spaceBefore)
                    // Plain words and punctuation draw above the stamp frames, so the comma after "world" is never covered by "stamp".
                    .zIndex(token.kind == .plain ? 1 : 0)
            }
        }
    }

    @ViewBuilder
    private func tokenView(_ token: HeadlineMarkup.Token, beat: WelcomeIntroTimeline.Beat) -> some View {
        switch token.kind {
        case .highlight(let index):
            StampWordFrame(word: token.text, size: size, style: .welcome(index: index, size: size))
                .offset(x: TiltParallax.offset(tilt.tilt.x, limit: WelcomeMetrics.headlineFrameParallax),
                        y: TiltParallax.offset(tilt.tilt.y, limit: WelcomeMetrics.headlineFrameParallax))
                .modifier(StampInEffect(played: shown.contains(beat), instant: instant))
        case .plain:
            Text(token.text)
                .font(font)
                .tracking(-0.045 * size)
                .foregroundStyle(WelcomeColor.textPrimary)
                .fixedSize()
                .modifier(FadeUp(shown: shown.contains(beat)))
        }
    }

    private func plain(_ tokens: [HeadlineMarkup.Token]) -> some View {
        var text = AttributedString()
        for token in tokens {
            var piece = AttributedString((token.spaceBefore && !text.characters.isEmpty ? " " : "") + token.text)
            if token.kind != .plain { piece.foregroundColor = WelcomeColor.highlight }
            text += piece
        }
        return Text(text)
            .font(font)
            .tracking(-0.045 * size)
            .foregroundStyle(WelcomeColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(FadeUp(shown: shown.contains(.your)))
    }
}
