import SwiftUI

/// The three things that were set up: a status icon and a line each. A row of three columns, or a vertical list at
/// accessibility text sizes. Each row is one accessibility element.
struct ReadySummary: View {
    let rows: [ReadyContent.Row]
    let entrance: BeatPlayer<ReadyTimeline.Beat>
    let isVertical: Bool

    @ScaledMetric(relativeTo: .caption) private var textSize = 12.5

    var body: some View {
        Group {
            if isVertical {
                VStack(alignment: .leading, spacing: 16) { ForEach(rows.indices, id: \.self) { row($0) } }
            } else {
                HStack(alignment: .top, spacing: 14) { ForEach(rows.indices, id: \.self) { row($0) } }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ index: Int) -> some View {
        let item = rows[index]
        let layout = isVertical ? AnyLayout(HStackLayout(alignment: .center, spacing: 14)) : AnyLayout(VStackLayout(spacing: 8))
        return layout {
            icon(item.status)
                .modifier(IconPopEffect(played: entrance.has(.icon(index)), instant: entrance.isInstant))
            Text(item.text)
                .font(.system(size: textSize, weight: .medium))
                .foregroundStyle(OnbColor.inkPrimary)
                .multilineTextAlignment(isVertical ? .leading : .center)
                .lineLimit(isVertical ? nil : 3)
                .frame(maxWidth: isVertical ? .infinity : 104, alignment: isVertical ? .leading : .center)
                .modifier(FadeUp(shown: entrance.has(.label(index)), rise: 8))
        }
        .frame(width: isVertical ? nil : 104, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.status == .done ? "onboarding.ready.a11y.done \(item.text)" : "onboarding.ready.a11y.off \(item.text)"))
        .accessibilityIdentifier("onboarding.ready.summary.\(index)")
    }

    @ViewBuilder
    private func icon(_ status: ReadyContent.Row.Status) -> some View {
        switch status {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(OnbColor.ctaLabel)
                .frame(width: 22, height: 22)
                .background(OnbColor.ctaFill, in: Circle())
        case .off:
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(OnbColor.inkSecondary)
                .frame(width: 22, height: 22)
                .overlay { Circle().stroke(OnbColor.inkSecondary, lineWidth: 1.6) }
        }
    }
}

/// An icon popping in: from .3x, past 1.18x, settling at 1 (0.45 s).
struct IconPopEffect: ViewModifier {
    let played: Bool
    let instant: Bool

    private struct Values {
        var scale = 0.3
        var opacity = 0.0
    }

    func body(content: Content) -> some View {
        if instant {
            content.opacity(played ? 1 : 0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.18, duration: 0.27)
                    CubicKeyframe(1, duration: 0.18)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: 0.2)
                    LinearKeyframe(1, duration: 0.25)
                }
            }
        }
    }
}
