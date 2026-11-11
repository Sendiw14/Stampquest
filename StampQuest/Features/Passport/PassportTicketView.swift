import SwiftUI

enum PassportTicketCell: Hashable { case collected, verified, countries, sets }

/// The glass ticket of four metrics. Every cell is a button; numbers appear once and update in place.
struct PassportTicketView: View {
    let metrics: PassportMetrics
    let scale: CGFloat
    let onSelect: (PassportTicketCell) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var numeralSize = 30.0
    @ScaledMetric(relativeTo: .caption) private var labelSize = 12.0

    private var grid: Bool { typeSize >= .xxLarge }
    private var cells: [PassportTicketCell] { [.collected, .verified, .countries, .sets] }

    var body: some View {
        Group {
            if grid {
                VStack(spacing: 0) {
                    HStack(spacing: 0) { cell(.collected); divider; cell(.verified) }
                    DottedRule().padding(.horizontal, 18)
                    HStack(spacing: 0) { cell(.countries); divider; cell(.sets) }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, kind in
                        if index > 0 { divider }
                        cell(kind)
                    }
                }
                .frame(height: 88 * scale)
            }
        }
        .cardGlass(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: HomeColor.shadow1.opacity(0.22), radius: 14, y: 12)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: metrics)
        .accessibilityElement(children: .contain)
    }

    private var divider: some View { DottedRule(vertical: true).padding(.vertical, 18) }

    private func value(_ kind: PassportTicketCell) -> Int {
        switch kind {
        case .collected: metrics.collected
        case .verified: metrics.verified
        case .countries: metrics.countries
        case .sets: metrics.sets
        }
    }

    private func cell(_ kind: PassportTicketCell) -> some View {
        Button { onSelect(kind) } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value(kind))").font(.system(size: numeralSize, weight: .heavy)).tracking(-0.04 * numeralSize)
                    .foregroundStyle(HomeColor.ink).contentTransition(.opacity).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    if kind == .verified { VerifiedSeal(size: 15) }
                    label(kind).font(.system(size: labelSize, weight: .semibold)).foregroundStyle(HomeColor.sub).lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(HomeColor.sub.opacity(0.6))
                }
            }
            .padding(.leading, 18 * scale).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken(kind)).accessibilityIdentifier("passport-ticket-\(identifier(kind))")
    }

    private func label(_ kind: PassportTicketCell) -> Text {
        switch kind {
        case .collected: Text("collected")
        case .verified: Text("verified")
        case .countries: metrics.countries == 1 ? Text("country") : Text("countries")
        case .sets: metrics.sets == 1 ? Text("set") : Text("sets")
        }
    }

    private func spoken(_ kind: PassportTicketCell) -> Text {
        switch kind {
        case .collected: Text("^[\(metrics.collected) collected stamp](inflect: true). Shows all stamps.")
        case .verified: Text("^[\(metrics.verified) verified visit](inflect: true). Shows verified stamps.")
        case .countries: Text("^[\(metrics.countries) country](inflect: true). Opens the country filter.")
        case .sets: Text("^[\(metrics.sets) set](inflect: true) started. Opens your collections.")
        }
    }

    private func identifier(_ kind: PassportTicketCell) -> String {
        switch kind {
        case .collected: "collected"
        case .verified: "verified"
        case .countries: "countries"
        case .sets: "sets"
        }
    }
}

/// An empty passport has no metrics: one card invites the first stamp.
struct PassportFirstStampCard: View {
    let scale: CGFloat
    let onExplore: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var titleSize = 24.0
    @ScaledMetric(relativeTo: .footnote) private var lineSize = 13.0

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 14) { copy; explore } }
            else { HStack(spacing: 14) { copy; DottedRule(vertical: true).padding(.vertical, 6); explore } }
        }
        .padding(.horizontal, 18).padding(.vertical, 16).frame(minHeight: 100 * scale)
        .cardGlass(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: HomeColor.shadow1.opacity(0.22), radius: 14, y: 12)
        .accessibilityElement(children: .contain)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Your first stamp").font(.system(size: titleSize, weight: .heavy)).tracking(-0.035 * titleSize).foregroundStyle(HomeColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Free to collect. Works offline.").font(.system(size: lineSize, weight: .medium)).foregroundStyle(HomeColor.sub)
            Text("Verify later for a gold seal.").font(.system(size: lineSize - 0.5, weight: .medium)).foregroundStyle(HomeColor.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var explore: some View {
        Button(action: onExplore) {
            Text("Explore").font(.system(size: 16, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                .frame(minWidth: 104, maxWidth: typeSize.isAccessibilitySize ? .infinity : 104, minHeight: 52)
                .background(HomeColor.cta, in: Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier("passport-first-explore")
    }
}
