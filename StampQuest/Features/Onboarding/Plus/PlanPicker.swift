import SwiftUI

/// Splits a row in proportion to `weights` (Yearly 184 : Monthly 158 at the 402 pt reference), with a fixed gap.
struct WeightedHStack: Layout {
    var weights: [CGFloat]
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 354
        let widths = columnWidths(total: width, count: subviews.count)
        let height = zip(subviews, widths).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, columnWidths(total: bounds.width, count: subviews.count)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func columnWidths(total: CGFloat, count: Int) -> [CGFloat] {
        let used = weights.prefix(count)
        let sum = used.reduce(0, +)
        let share = max(0, total - spacing * CGFloat(max(0, count - 1)))
        return used.map { share * $0 / max(sum, 1) }
    }
}

/// Yearly and Monthly as perforated stamps: terracotta edge and a tinted paper when selected, a pale edge when not. Each card is one
/// VoiceOver element that reads its plan, price, per-month price and saving. The saving badge is part of that label, not a separate stop.
struct PlanPicker: View {
    let plans: [PlusContent.Plan]
    let saveBadge: String?
    let selected: PlusPlanKind
    let isEnabled: Bool
    /// Plans dim only while a purchase is open, not once Plus has started.
    var isDimmed = false
    var isStacked = false
    let shown: Set<PlusTimeline.Beat>
    let reduceMotion: Bool
    let onSelect: (PlusPlanKind) -> Void

    var body: some View {
        Group {
            if isStacked {
                VStack(spacing: PlusMetrics.planGap + 6) { ForEach(plans) { card($0) } }
            } else {
                WeightedHStack(weights: [184, 158], spacing: PlusMetrics.planGap) { ForEach(plans) { card($0) } }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func card(_ plan: PlusContent.Plan) -> some View {
        PlanCard(plan: plan, badge: plan.kind == .yearly ? saveBadge : nil, isSelected: plan.kind == selected, isEnabled: isEnabled, isDimmed: isDimmed,
                 shown: shown, reduceMotion: reduceMotion) { onSelect(plan.kind) }
    }
}

struct PlanCard: View {
    let plan: PlusContent.Plan
    let badge: String?
    let isSelected: Bool
    let isEnabled: Bool
    let isDimmed: Bool
    let shown: Set<PlusTimeline.Beat>
    let reduceMotion: Bool
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var titleSize = 15.0
    @ScaledMetric(relativeTo: .title2) private var priceSize = 23.0
    @ScaledMetric(relativeTo: .footnote) private var periodSize = 13.0
    @ScaledMetric(relativeTo: .caption) private var sublineSize = 12.5
    @State private var bumped = false

    private var appear: PlusTimeline.Beat { plan.kind == .yearly ? .planYearly : .planMonthly }
    private var fade: Animation { .easeInOut(duration: reduceMotion ? 0.15 : 0.22) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    radio
                    Text(verbatim: plan.title).font(.system(size: titleSize, weight: .semibold)).foregroundStyle(OnbColor.inkPrimary)
                }
                (Text(verbatim: plan.price).font(.system(size: priceSize, weight: .semibold, design: .serif)).foregroundStyle(OnbColor.inkPrimary)
                 + Text(verbatim: " " + plan.perPeriod).font(.system(size: periodSize)).foregroundStyle(OnbColor.inkSecondary))
                    .lineLimit(2).minimumScaleFactor(0.8)
                if let subline = plan.subline {
                    Text(verbatim: subline).font(.system(size: sublineSize)).foregroundStyle(OnbColor.inkSecondary)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: PlusMetrics.planHeight, alignment: .leading)
            .background { cardBackground }
            .overlay(alignment: .top) { badgeView }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isDimmed ? 0.7 : 1)
        .scaleEffect(bumped ? 1.03 : 1)
        .animation(.easeInOut(duration: 0.2), value: bumped)
        .animation(fade, value: isSelected)
        .modifier(FadeUp(shown: shown.contains(appear), rise: reduceMotion ? 0 : 16))
        .onChange(of: isSelected) { _, selected in
            guard selected, !reduceMotion else { return }
            bumped = true
            Task { try? await Task.sleep(for: .milliseconds(200)); bumped = false }
        }
        .accessibilityLabel(Text(verbatim: plan.accessibilityLabel))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.plus.plan.\(plan.kind.rawValue)")
    }

    private var radio: some View {
        ZStack {
            Circle().strokeBorder(contrast == .increased ? OnbColor.inkPrimary.opacity(0.7) : OnbColor.radioRing, lineWidth: 1.5)
            Circle().fill(OnbColor.ctaFill).opacity(isSelected ? 1 : 0)
            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(OnbColor.ctaLabel).opacity(isSelected ? 1 : 0)
        }
        .frame(width: 18, height: 18)
    }

    private var cardBackground: some View {
        let shape = FixedPitchPerforatedShape(pitch: PlusMetrics.stampPitch, notchRatio: 0.3)
        return ZStack {
            shape.fill(isSelected ? OnbColor.ctaFill : OnbColor.stampEdge)
            if contrast == .increased && !isSelected { shape.stroke(OnbColor.inkPrimary.opacity(0.45), lineWidth: 1.5) }
            RoundedRectangle(cornerRadius: 3).inset(by: 5).fill(OnbColor.passportPaper)
            RoundedRectangle(cornerRadius: 3).inset(by: 5).fill(OnbColor.selectedTint).opacity(isSelected ? 1 : 0)
        }
        .shadow(color: OnbColor.shadowSoft.opacity(0.35), radius: 4, y: 3)
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge {
            Text(verbatim: badge)
                .font(.system(size: 11.5, weight: .bold))
                .fixedSize()
                .foregroundStyle(OnbColor.ctaLabel)
                .padding(.horizontal, 10)
                .frame(minHeight: 20)
                .background(OnbColor.ctaFill, in: Capsule())
                .overlay { Capsule().strokeBorder(OnbColor.background, lineWidth: 2) }
                .offset(y: -10)
                .scaleEffect(shown.contains(.badge) || reduceMotion ? 1 : 0.5)
                .opacity(shown.contains(.badge) ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55), value: shown.contains(.badge))
        }
    }
}

/// Placeholder cards while plans load: the two stamp outlines, no text.
struct PlanSkeleton: View {
    var isStacked = false

    var body: some View {
        let card = FixedPitchPerforatedShape(pitch: PlusMetrics.stampPitch, notchRatio: 0.3)
            .fill(OnbColor.stampEdge)
            .overlay { RoundedRectangle(cornerRadius: 3).inset(by: 5).fill(OnbColor.passportPaper) }
            .frame(minHeight: PlusMetrics.planHeight)
        Group {
            if isStacked {
                VStack(spacing: PlusMetrics.planGap + 6) { card; card }
            } else {
                WeightedHStack(weights: [184, 158], spacing: PlusMetrics.planGap) { card; card }
            }
        }
        .accessibilityHidden(true)
        .accessibilityIdentifier("onboarding.plus.skeleton")
    }
}
