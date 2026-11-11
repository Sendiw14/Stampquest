import SwiftUI

/// The timeline under the perks: three steps (Today, reminder, plan begins), two when no reminder will really be sent, or the no-trial
/// "Today / next renewal". At accessibility sizes it becomes a vertical list. It reads as one VoiceOver element.
struct TrialRoute: View {
    let steps: [PlusContent.Step]
    /// The beats that have already played, passed down by value so this view redraws whenever the screen's entrance advances.
    let shown: Set<PlusTimeline.Beat>
    let reduceMotion: Bool
    var isVertical = false

    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .footnote) private var titleSize = 13.0
    @ScaledMetric(relativeTo: .footnote) private var captionSize = 12.0

    private var key: String { steps.map { $0.title + $0.caption }.joined(separator: "|") }

    var body: some View {
        ZStack {
            Group { if isVertical { vertical } else { horizontal } }
                .id(key)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.22), value: key)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(steps.map { "\($0.title), \($0.caption)" }.joined(separator: ". ")))
        .accessibilityIdentifier("onboarding.plus.timeline")
    }

    // MARK: Layouts

    private var horizontal: some View {
        let spacing = PlusMetrics.nodeSpacing(steps: steps.count, width: 402)
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 8) {
                    node(step.icon, index: index)
                    VStack(spacing: 0) {
                        Text(verbatim: step.title).font(.system(size: titleSize, weight: .semibold)).foregroundStyle(OnbColor.inkPrimary)
                        Text(verbatim: step.caption).font(.system(size: captionSize)).foregroundStyle(OnbColor.inkSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: PlusMetrics.labelWidth(steps: steps.count))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: spacing * CGFloat(steps.count))
        .background(alignment: .top) { dottedLine }
    }

    private var vertical: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    node(step.icon, index: index)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: step.title).font(.system(size: titleSize, weight: .semibold)).foregroundStyle(OnbColor.inkPrimary)
                        Text(verbatim: step.caption).font(.system(size: captionSize)).foregroundStyle(OnbColor.inkSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var dottedLine: some View {
        GeometryReader { proxy in
            let inset = proxy.size.width / CGFloat(steps.count) / 2 + PlusMetrics.nodeSize / 2 + 6
            Path { path in
                path.move(to: CGPoint(x: inset, y: PlusMetrics.nodeSize / 2))
                path.addLine(to: CGPoint(x: proxy.size.width - inset, y: PlusMetrics.nodeSize / 2))
            }
            .stroke(contrast == .increased ? OnbColor.inkPrimary.opacity(0.45) : OnbColor.inkTertiary.opacity(0.55),
                    style: StrokeStyle(lineWidth: contrast == .increased ? 1.5 : 2.4, lineCap: .round, dash: [0.1, 5.2]))
            .mask(alignment: .leading) {
                Rectangle().scaleEffect(x: shown.contains(.line) || reduceMotion ? 1 : 0.001, anchor: .leading)
            }
        }
        .frame(height: PlusMetrics.nodeSize)
    }

    private func node(_ icon: PlusContent.Step.Icon, index: Int) -> some View {
        let filled = icon == .star
        return ZStack {
            Circle().fill(filled ? OnbColor.ctaFill : OnbColor.passportPaper)
            Circle().strokeBorder(OnbColor.ctaFill, lineWidth: filled ? 0 : 1.5)
            Image(systemName: icon == .star ? "star.fill" : icon == .bell ? "bell" : "creditcard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(filled ? OnbColor.ctaLabel : OnbColor.ctaFill)
        }
        .frame(width: PlusMetrics.nodeSize, height: PlusMetrics.nodeSize)
        .scaleEffect(shown.contains(.node(index)) || reduceMotion ? 1 : 0.4)
        .opacity(shown.contains(.node(index)) ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: shown.contains(.node(index)))
    }
}
