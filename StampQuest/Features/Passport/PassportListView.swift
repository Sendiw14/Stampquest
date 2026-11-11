import SwiftUI

/// List view: 80 pt rows with a thumbnail, name, country and date, the verified seal (or "By hand"), the favorite heart
/// and a chevron. Swipe left for Favorite and Remove.
struct PassportListView: View {
    let entries: [PassportEntry]
    let actions: PassportStampActions

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(entries) { entry in
                PassportListRow(entry: entry, actions: actions)
                Rectangle().fill(PassportColor.cardLine).frame(height: 1).padding(.leading, 86)
            }
        }
    }
}

struct PassportListRow: View {
    let entry: PassportEntry
    let actions: PassportStampActions

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var nameSize = 17.0
    @ScaledMetric(relativeTo: .footnote) private var detailSize = 13.0
    @State private var drag: CGFloat = 0
    @State private var isOpen = false

    private static let actionWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            swipeActions
            row
                .background(HomeColor.page)
                .offset(x: drag)
                .simultaneousGesture(swipe)
        }
        .clipped()
        .accessibilityIdentifier("passport-row-\(entry.destinationID)")
    }

    private var row: some View {
        PassportStampButton(entry: entry, actions: PassportStampActions(open: { entry in
            if isOpen { close() } else { actions.open(entry) }
        }, toggleFavorite: actions.toggleFavorite, share: actions.share, remove: actions.remove)) {
            HStack(spacing: 14) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).font(.system(size: nameSize, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    Text("\(entry.countryName), \(PassportDateText.withYear(entry.collectedAt))").font(.system(size: detailSize, weight: .medium))
                        .foregroundStyle(HomeColor.sub).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                }
                Spacer(minLength: 6)
                if entry.isVerified { VerifiedSeal(size: 22) }
                else { Text("By hand").font(.system(size: detailSize - 1, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1) }
                if entry.isFavorite { Image(systemName: "heart.fill").font(.system(size: 14)).foregroundStyle(HomeColor.cta) }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(HomeColor.sub.opacity(0.7))
            }
            .padding(.horizontal, 20).frame(minHeight: 80)
            .contentShape(Rectangle())
        }
    }

    private var thumbnail: some View {
        Group {
            if let design = entry.design { PerforatedStampView(design: design, showsTitle: false, isDecorative: true, lifted: false, aspectRatio: 0.75) }
            else { MissingStampArtwork(name: "") }
        }
        .frame(width: 44, height: 58.7).rotationEffect(.degrees(-1.5)).shadow(color: HomeColor.shadow1.opacity(0.2), radius: 4, y: 3)
    }

    // MARK: Swipe

    private var swipeActions: some View {
        HStack(spacing: 0) {
            action(entry.isFavorite ? "heart.slash" : "heart", entry.isFavorite ? Text("Unfavorite") : Text("Favorite"), fill: HomeColor.cta, ink: HomeColor.ctaText) {
                close(); actions.toggleFavorite(entry)
            }
            action("trash", Text("Remove"), fill: SQColor.error, ink: .white) { close(); actions.remove(entry) }
        }
        .frame(width: Self.actionWidth * 2).opacity(drag < -2 ? 1 : 0)
    }

    private func action(_ symbol: String, _ title: Text, fill: Color, ink: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) { Image(systemName: symbol).font(.system(size: 17, weight: .semibold)); title.font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7) }
                .foregroundStyle(ink).frame(width: Self.actionWidth).frame(maxHeight: .infinity).background(fill)
        }
        .buttonStyle(.plain)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.6 else { return }
                let base: CGFloat = isOpen ? -Self.actionWidth * 2 : 0
                drag = min(0, max(-Self.actionWidth * 2.2, base + value.translation.width))
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.6 else { return }
                withAnimation(.snappy(duration: 0.25)) {
                    isOpen = drag < -Self.actionWidth
                    drag = isOpen ? -Self.actionWidth * 2 : 0
                }
            }
    }

    private func close() { withAnimation(.snappy(duration: 0.25)) { isOpen = false; drag = 0 } }
}
