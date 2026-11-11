import SwiftUI

/// "Featured today": the one next stamp and its Collect action, as a ticket stub that straddles the poster edge.
struct TodayCardView: View {
    let item: DestinationItem
    let isFirstRun: Bool
    let state: HomeViewModel.CollectState
    let now: Date
    let onOpen: () -> Void
    let onCollect: () -> Void
    let onRetry: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .title) private var titleSize = 28.0
    @ScaledMetric(relativeTo: .footnote) private var detailSize = 13.5

    private var phase: DestinationPhase {
        DestinationPhaseCalculator.phase(latitude: item.destination.latitude, longitude: item.destination.longitude, at: now)
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 14) { details; collect(fullWidth: true) } }
            else { HStack(spacing: 0) { details.frame(maxWidth: .infinity, alignment: .leading); divider; collect(fullWidth: false).padding(.leading, 14) } }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .padding(.leading, 0)
        .background(cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(HomeColor.cardLine.opacity(0.7), lineWidth: 1))
        .shadow(color: HomeColor.shadow1.opacity(scheme == .dark ? 0.72 : 0.46), radius: 15, y: 22)
        .shadow(color: HomeColor.shadow1.opacity(scheme == .dark ? 0.6 : 0.34), radius: 5, y: 4)
        .accessibilityElement(children: .contain)
    }

    // MARK: Pieces

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isFirstRun ? "YOUR FIRST STAMP" : "FEATURED TODAY")
                .font(.system(size: 11, weight: .bold)).tracking(0.14 * 11).foregroundStyle(HomeColor.label)
            Button(action: onOpen) {
                Text(item.destination.name).font(.system(size: titleSize, weight: .heavy)).tracking(-0.04 * titleSize)
                    .foregroundStyle(HomeColor.ink).lineLimit(typeSize.isAccessibilitySize ? 3 : 1).minimumScaleFactor(0.7)
            }
            .buttonStyle(.plain).accessibilityIdentifier("home-today-title")
            HStack(spacing: 6) {
                Circle().fill(HomeColor.thereNow).frame(width: 7, height: 7).accessibilityHidden(true)
                Text("\(item.destination.countryName) · \(phase.phrase) there now")
                    .font(.system(size: detailSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2)
            }
            if state == .failed {
                HStack(spacing: 8) {
                    Text("Couldn't save. Try again.").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(SQColor.error)
                    Button("Retry", action: onRetry).font(.system(size: 12.5, weight: .bold)).foregroundStyle(HomeColor.label)
                        .frame(minHeight: 44).accessibilityIdentifier("home-collect-retry")
                }
            } else {
                Text(isFirstRun ? "Free to collect. Works offline." : "Verify on site later for a gold seal.")
                    .font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.ink3).lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Featured today: \(item.destination.name), \(item.destination.countryName), \(phase.phrase) there now"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onOpen)
    }

    private var divider: some View {
        Rectangle().fill(.clear).frame(width: 2, height: 82)
            .overlay { Rectangle().stroke(HomeColor.ink3.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [2, 4])).frame(width: 0) }
            .accessibilityHidden(true)
    }

    private func collect(fullWidth: Bool) -> some View {
        HomePill(title: "Collect", width: fullWidth ? 280 : 102, isBusy: state == .saving, action: onCollect)
            .disabled(state == .saving)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .accessibilityLabel(Text("Collect \(item.destination.name)"))
            .accessibilityHint(Text("Adds the stamp by hand. Verify on site later for a gold seal."))
            .accessibilityIdentifier("home-collect")
    }

    @ViewBuilder private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        if reduceTransparency { shape.fill(HomeColor.card) }
        else if #available(iOS 26.0, *) { shape.fill(HomeColor.card.opacity(0.4)).glassEffect(.regular.tint(HomeColor.card.opacity(0.5)), in: shape) }
        else { shape.fill(.ultraThinMaterial).overlay(shape.fill(HomeColor.card.opacity(scheme == .dark ? 0.90 : 0.86))) }
    }
}
