import SwiftUI

/// Look back: the latest memory as a slightly rotated postcard, with the destination's stamp on the right.
struct LookBackPostcard: View {
    let memory: HomeMemory
    let item: DestinationItem?
    let onOpen: () -> Void

    private var dateLine: String {
        let date = memory.eventDate.formatted(.dateTime.day().month(.abbreviated).year())
        return item.map { "\(date) · \($0.destination.name)".uppercased() } ?? date.uppercased()
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dateLine).font(.system(size: 11, weight: .bold)).tracking(0.12 * 11).foregroundStyle(HomeColor.label).lineLimit(1)
                    Text(memory.title.isEmpty ? String(localized: "A memory") : memory.title)
                        .font(.system(size: 22, weight: .semibold, design: .serif).italic()).foregroundStyle(HomeColor.ink).lineLimit(2)
                    if !memory.text.isEmpty { Text(memory.text).font(.system(size: 13)).foregroundStyle(HomeColor.sub).lineLimit(2) }
                    if memory.photoCount > 0 {
                        Text("^[\(memory.photoCount) photo](inflect: true)").font(.system(size: 12, weight: .semibold)).foregroundStyle(HomeColor.label)
                            .padding(.horizontal, 10).frame(height: 24).background(HomeColor.tint, in: Capsule())
                    }
                }
                Spacer(minLength: 0)
                if let item {
                    Rectangle().fill(HomeColor.cardLine.opacity(0.7)).frame(width: 1).padding(.vertical, 4)
                    PerforatedStampView(design: item.design, showsTitle: false, isDecorative: true).frame(width: 74).rotationEffect(.degrees(6))
                }
            }
            .padding(18)
            .background(HomeColor.postcard, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(HomeColor.cardLine.opacity(0.7), lineWidth: 1))
            .shadow(color: HomeColor.shadow1.opacity(0.2), radius: 8, y: 6)
            .rotationEffect(.degrees(-1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Memory: \(memory.title.isEmpty ? String(localized: "A memory") : memory.title)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home-lookback")
    }
}
