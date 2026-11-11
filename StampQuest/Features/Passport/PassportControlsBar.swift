import SwiftUI

/// Grid / Pages / List, the sort chip and the filter button. One view: it is also what pins under the title bar, so the
/// two are never on screen at once and share state.
struct PassportControlsBar: View {
    @Bindable var model: PassportViewModel
    let onOpenFilter: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var segmentSpace
    @ScaledMetric(relativeTo: .subheadline) private var segmentSize = 13.5

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { segments.frame(width: 172 * min(1.35, textScale)); sortChip; Spacer(minLength: 0); filterButton }
            VStack(spacing: 8) { segments; HStack(spacing: 10) { sortChip; Spacer(minLength: 0); filterButton } }
        }
        .accessibilityElement(children: .contain)
    }

    private var textScale: CGFloat { typeSize >= .xxxLarge ? 1.2 : 1 }

    // MARK: Segments

    private var segments: some View {
        HStack(spacing: 0) {
            ForEach(PassportLayout.allCases) { layout in
                let selected = model.layout == layout
                Button { withAnimation(.snappy(duration: 0.25)) { model.select(layout) } } label: {
                    Text(layout.title).font(.system(size: segmentSize, weight: selected ? .bold : .semibold))
                        .foregroundStyle(selected ? HomeColor.ink : HomeColor.sub).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 34).padding(.horizontal, 6)
                        .background {
                            if selected {
                                Capsule().fill(HomeColor.card).shadow(color: HomeColor.shadow1.opacity(0.2), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: segmentSpace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3).frame(minHeight: 40).background(PassportColor.quiet, in: Capsule())
        .overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .padding(.vertical, 2)
        .accessibilityRepresentation {
            Picker("View", selection: Binding(get: { model.layout }, set: { model.select($0) })) {
                ForEach(PassportLayout.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).accessibilityIdentifier("passport-layout")
        }
    }

    // MARK: Sort

    private var sortChip: some View {
        Menu {
            Picker("Sort by", selection: Binding(get: { model.query.sort }, set: { model.setSort($0) })) {
                ForEach(PassportSort.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 12, weight: .bold)).accessibilityHidden(true)
                Text(model.query.sort.shortTitle).font(.system(size: segmentSize, weight: .semibold)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).accessibilityHidden(true)
            }
            .foregroundStyle(HomeColor.ink).padding(.horizontal, 14).frame(minHeight: 40)
            .background(HomeColor.card, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .padding(.vertical, 2).contentShape(Capsule())
        }
        .accessibilityLabel(Text("Sort")).accessibilityValue(Text(model.query.sort.title)).accessibilityIdentifier("passport-sort")
    }

    // MARK: Filter

    private var filterButton: some View {
        let count = model.query.activeFilterCount
        return Button(action: onOpenFilter) {
            Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(count > 0 ? HomeColor.ctaText : HomeColor.ink)
                .frame(width: 40, height: 40)
                .background(count > 0 ? HomeColor.cta : PassportColor.quiet, in: Circle())
                .overlay(Circle().strokeBorder(count > 0 ? .clear : PassportColor.cardLine, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if count > 0 {
                        Text("\(count)").font(.system(size: 11, weight: .bold)).foregroundStyle(HomeColor.page)
                            .frame(minWidth: 18, minHeight: 18).background(HomeColor.ink, in: Circle()).offset(x: 5, y: -4)
                    }
                }
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Sort and filter"))
        .accessibilityValue(count > 0 ? Text("^[\(count) filter](inflect: true) on") : Text("No filters"))
        .accessibilityIdentifier("passport-options")
    }
}
