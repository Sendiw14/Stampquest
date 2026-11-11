import SwiftUI

/// "Choose your [first] stamp" / "That's your [first] stamp.": 36 pt Heavy words in a flow layout. The stamp-word is
/// the same view in both states, so it can bump on collect; the other words swap in place while hidden.
struct FirstStampHeadline: View {
    /// Which text to show: false for choosing, true for collected.
    let collected: Bool
    /// False while the words are out (the swap between the two states).
    let textVisible: Bool
    let choreo: FirstStampChoreographer

    @ScaledMetric(relativeTo: .largeTitle) private var size = FirstStampMetrics.headlineSize

    private var markup: String {
        collected ? String(localized: "onboarding.firstStamp.title.done") : String(localized: "onboarding.firstStamp.title.choose")
    }

    var body: some View {
        Group {
            if let tokens = HeadlineMarkup.parse(markdown: markup) {
                HeadlineFlowLayout(lineHeight: size * FirstStampMetrics.headlineLineHeight / FirstStampMetrics.headlineSize,
                                   spaceWidth: 8, growsForTallItems: true) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        tokenView(token, secondLine: tokens[..<index].contains { $0.lineBreakBefore } || token.lineBreakBefore)
                            .layoutValue(key: SpaceBeforeKey.self, value: token.spaceBefore)
                            .layoutValue(key: LineBreakBeforeKey.self, value: token.lineBreakBefore)
                    }
                }
            } else {
                Text(HeadlineMarkup.plainText(markup)).font(font).foregroundStyle(OnbColor.inkPrimary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: HeadlineMarkup.plainText(markup)))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.firstStamp.title")
    }

    private var font: Font { .system(size: size, weight: .heavy) }

    @ViewBuilder
    private func tokenView(_ token: HeadlineMarkup.Token, secondLine: Bool) -> some View {
        switch token.kind {
        case .highlight:
            StampWordFrame(word: token.text, size: size, style: .interests(size: size))
                .modifier(StampInEffect(played: choreo.has(.firstWord), instant: choreo.isInstant))
                .modifier(BumpEffect(trigger: choreo.contactCount))
        case .plain:
            Text(token.text)
                .font(font)
                .tracking(-0.04 * size)
                .foregroundStyle(OnbColor.inkPrimary)
                .fixedSize()
                .modifier(FadeUp(shown: choreo.has(secondLine ? .stampWord : .firstLine)))
                .opacity(textVisible ? 1 : 0)
                .offset(y: textVisible ? 0 : -6)
        }
    }
}

/// A short grow and settle: 1 to 1.07 and back over half a second.
struct BumpEffect: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.07, duration: 0.2)
                CubicKeyframe(1, duration: 0.3)
            }
        }
    }
}
