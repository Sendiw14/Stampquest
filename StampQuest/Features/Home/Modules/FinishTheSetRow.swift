import SwiftUI

/// One set in progress: its title, "n of m collected", five slots (collected stamps first, then empty dashed slots).
struct FinishTheSetRow: View {
    let set: HomeSet
    let items: [DestinationItem]
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(set.progress.collection.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.ink)
                        Text("\(set.progress.collected) of \(set.progress.total) collected").font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3).accessibilityHidden(true)
                }
                HStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { slot in
                        if slot < items.count {
                            PerforatedStampView(design: items[slot].design, showsTitle: false, isDecorative: true).frame(width: 38)
                        } else {
                            RoundedRectangle(cornerRadius: 4).strokeBorder(HomeColor.ink3.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, dash: [3, 3]))
                                .frame(width: 38, height: 47.5)
                        }
                    }
                    if set.extraCount > 0 { Text("+\(set.extraCount) more").font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1).minimumScaleFactor(0.8).padding(.leading, 4) }
                    Spacer(minLength: 0)
                }
                .accessibilityHidden(true)
            }
            .padding(16)
            .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(HomeColor.cardLine.opacity(0.7), lineWidth: 1))
            .shadow(color: HomeColor.shadow1.opacity(0.18), radius: 8, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(set.progress.collection.title), \(set.progress.collected) of \(set.progress.total) collected"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home-set-\(set.progress.collection.id)")
    }
}
