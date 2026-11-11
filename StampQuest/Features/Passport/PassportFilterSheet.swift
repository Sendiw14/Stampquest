import SwiftUI

/// "Sort & filter": every choice applies to the query immediately (no draft state), the button shows the live number of
/// matches, and any way of closing the sheet keeps the choices.
struct PassportFilterSheet: View {
    @Bindable var model: PassportViewModel
    let countries: [(code: String, name: String)]
    let collections: [StampCollection]
    let matchCount: Int
    let focus: PassportFilterGroup?
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var titleSize = 24.0

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    group("Sort by", id: .sort) { sortChips }
                    group("Show", id: .show) { showRows }
                    if !countries.isEmpty { group("Country", id: .country) { chips(countries.map { ($0.code, $0.name) }, selected: model.query.countryCodes) { .country($0) } } }
                    if !collections.isEmpty { group("Collection", id: .collection) { chips(collections.map { ($0.id, $0.title) }, selected: model.query.collectionIDs) { .collection($0) } } }
                }
                .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 110)
            }
            .task { if let focus { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { reader.scrollTo(focus, anchor: .top) } } }
        }
        .background(HomeColor.page.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { doneButton }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Sort & filter").font(.system(size: titleSize, weight: .heavy)).tracking(-0.03 * titleSize).foregroundStyle(HomeColor.ink).accessibilityAddTraits(.isHeader).accessibilityIdentifier("passport-filter-sheet")
            Spacer()
            Button("Reset") { model.resetAll() }.font(.system(size: 15.5, weight: .semibold)).foregroundStyle(HomeColor.label)
                .disabled(model.query.isDefault).opacity(model.query.isDefault ? 0.4 : 1).frame(minHeight: 44).accessibilityIdentifier("passport-reset")
        }
    }

    private func group<Content: View>(_ title: LocalizedStringKey, id: PassportFilterGroup, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .bold)).tracking(0.02 * 13).foregroundStyle(HomeColor.sub).accessibilityAddTraits(.isHeader)
            content()
        }
        .id(id)
    }

    // MARK: Sort

    private var sortChips: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(PassportSort.allCases) { sort in
                let selected = model.query.sort == sort
                Button { model.setSort(sort) } label: {
                    HStack(spacing: 6) {
                        if selected { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                        Text(sort.title).font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(selected ? HomeColor.ctaText : HomeColor.ink).padding(.horizontal, 16).frame(minHeight: 38)
                    .background(selected ? HomeColor.cta : HomeColor.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(selected ? .clear : PassportColor.cardLine, lineWidth: 1))
                    .frame(minHeight: 44).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("passport-sort-\(sort.rawValue)")
            }
        }
    }

    // MARK: Show

    private var showRows: some View {
        VStack(spacing: 0) {
            toggleRow(title: "Verified visits only", subtitle: "Stamps with a gold seal", isOn: model.query.onlyVerified, kind: .verified, id: "passport-toggle-verified") {
                VerifiedSeal(size: 24)
            }
            Rectangle().fill(PassportColor.cardLine).frame(height: 1)
            toggleRow(title: "Favorites only", subtitle: "Stamps you hearted", isOn: model.query.onlyFavorites, kind: .favorites, id: "passport-toggle-favorites") {
                Image(systemName: "heart").font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.cta).frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16).background(HomeColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
    }

    private func toggleRow<Icon: View>(title: LocalizedStringKey, subtitle: LocalizedStringKey, isOn: Bool, kind: PassportFilterChip.Kind, id: String,
                                       @ViewBuilder icon: () -> Icon) -> some View {
        let binding = Binding(get: { isOn }, set: { _ in model.toggleFilter(kind) })
        return Button { binding.wrappedValue.toggle() } label: {
            HStack(spacing: 12) {
                icon()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 15.5, weight: .semibold)).foregroundStyle(HomeColor.ink)
                    Text(subtitle).font(.system(size: 12.5, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: binding).labelsHidden().tint(HomeColor.cta).allowsHitTesting(false)
            }
            .frame(minHeight: 60).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(title, isOn: binding).accessibilityHint(Text(subtitle)).accessibilityIdentifier(id) }
    }

    // MARK: Chips

    private func chips(_ items: [(id: String, title: String)], selected: Set<String>, kind: @escaping (String) -> PassportFilterChip.Kind) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.id) { item in
                let on = selected.contains(item.id)
                Button { model.toggleFilter(kind(item.id)) } label: {
                    HStack(spacing: 6) {
                        if on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                        Text(item.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(on ? HomeColor.ctaText : HomeColor.ink).padding(.horizontal, 16).frame(minHeight: 38)
                    .background(on ? HomeColor.cta : HomeColor.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(on ? .clear : PassportColor.cardLine, lineWidth: 1))
                    .frame(minHeight: 44).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : []).accessibilityIdentifier("passport-filter-\(item.id)")
            }
        }
    }

    // MARK: Done

    private var doneButton: some View {
        Button(action: onDone) {
            Group {
                if matchCount == 0 { Text("No stamps match") } else { Text("Show ^[\(matchCount) stamp](inflect: true)") }
            }
            .font(.system(size: 17, weight: .bold)).foregroundStyle(HomeColor.ctaText).contentTransition(.opacity)
            .frame(maxWidth: .infinity, minHeight: 56).background(HomeColor.cta, in: Capsule())
        }
        .buttonStyle(.plain).animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: matchCount)
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 10)
        .background { LinearGradient(colors: [HomeColor.page.opacity(0), HomeColor.page, HomeColor.page], startPoint: .top, endPoint: .bottom).ignoresSafeArea() }
        .accessibilityIdentifier("passport-filter-done")
    }
}
