import SwiftUI

/// "Picked for you": three uncollected stamps, slightly rotated, each opening its destination.
struct PicksRow: View {
    let items: [DestinationItem]
    let onOpen: (String) -> Void
    private let angles: [Double] = [-2, 1.5, -1]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button { onOpen(item.id) } label: {
                    VStack(spacing: 6) {
                        PerforatedStampView(design: item.design, showsTitle: false, isDecorative: true)
                            .frame(width: 104).rotationEffect(.degrees(angles[index % angles.count]))
                            .shadow(color: HomeColor.shadow1.opacity(0.34), radius: 6, y: 12)
                            .padding(.bottom, 6)
                        Text(item.destination.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(1)
                        Text(item.destination.countryName).font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(item.destination.name), \(item.destination.countryName)"))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("home-pick-\(item.id)")
            }
        }
    }
}
