import SwiftUI

/// Near you: shown only for a fresh fix inside a place's own radius (the view model gates it). Never asks for permission.
struct NearYouTicket: View {
    let item: DestinationItem
    let nearby: HomeNearby
    let isSaving: Bool
    let onAct: () -> Void

    private var distance: String { Measurement(value: nearby.distanceMeters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)) }

    var body: some View {
        HStack(spacing: 12) {
            PerforatedStampView(design: item.design, showsTitle: false, isDecorative: true).frame(width: 46)
            VStack(alignment: .leading, spacing: 1) {
                Label("Near you · \(distance)", systemImage: "mappin").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(HomeColor.label)
                Text(item.destination.name).font(.system(size: 17.5, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(1)
                Text(nearby.isCollected ? "Verify your \(item.destination.name) stamp.\nLocation is used once." : "Add it to your passport.")
                    .font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(2)
            }
            Spacer(minLength: 0)
            HomePill(title: nearby.isCollected ? "Verify" : "Collect", height: 40, width: 80, isBusy: isSaving, action: onAct)
                .disabled(isSaving)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background { TicketShape().fill(HomeColor.card, style: FillStyle(eoFill: true)).overlay(TicketShape().stroke(HomeColor.cardLine.opacity(0.7), lineWidth: 1)) }
        .shadow(color: HomeColor.shadow1.opacity(0.2), radius: 8, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-near")
    }
}

/// A rounded rectangle with a semicircular notch (radius 10) in the middle of each side.
nonisolated struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 22, style: .continuous)
        let notch = 10.0
        path.addEllipse(in: CGRect(x: rect.minX - notch, y: rect.midY - notch, width: notch * 2, height: notch * 2))
        path.addEllipse(in: CGRect(x: rect.maxX - notch, y: rect.midY - notch, width: notch * 2, height: notch * 2))
        return path
    }

}
