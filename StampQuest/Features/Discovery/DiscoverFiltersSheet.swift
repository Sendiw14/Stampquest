import SwiftUI

/// The Filters sheet (D6). It edits a draft: nothing behind it changes while it is open. The bottom button applies the draft
/// and shows the live number of matches. Cancel, a swipe down and a tap on the scrim all discard the draft.
struct DiscoverFiltersSheet: View {
    let initial: DiscoverFilter
    let matchCount: (DiscoverFilter) -> Int
    let countries: [(code: String, name: String)]
    let regions: [Region]
    let categories: [DestinationCategory]
    let onApply: (DiscoverFilter) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: DiscoverFilter
    @State private var path: [Page] = []
    @ScaledMetric(relativeTo: .title2) private var titleSize = 22.0

    private enum Page: Hashable { case countries }

    init(initial: DiscoverFilter, matchCount: @escaping (DiscoverFilter) -> Int, countries: [(code: String, name: String)],
         regions: [Region], categories: [DestinationCategory], onApply: @escaping (DiscoverFilter) -> Void) {
        self.initial = initial
        self.matchCount = matchCount
        self.countries = countries
        self.regions = regions
        self.categories = categories
        self.onApply = onApply
        _draft = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack(path: $path) {
            main
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Page.self) { _ in
                    DiscoverCountryPicker(selection: $draft.countryCodes, countries: countries)
                }
        }
        .background(HomeColor.page.ignoresSafeArea())
    }

    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                group("Interest") { chips(categories.map { ($0.rawValue, $0.title) }, selected: Set(draft.categories.map(\.rawValue)), idPrefix: "interest") { id in
                    if let c = DestinationCategory(rawValue: id) { draft.toggle(c) }
                } }
                group("Region") { chips(regions.map { ($0.rawValue, $0.title) }, selected: Set(draft.regions.map(\.rawValue)), idPrefix: "region") { id in
                    if let r = Region(rawValue: id) { draft.toggle(r) }
                } }
                group("Country") { countryRow }
                group("Show") { showControl }
            }
            .padding(.horizontal, 24).padding(.top, 26).padding(.bottom, 120)
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: draft)
        }
        .background(HomeColor.page.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { applyButton }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text("Filters").font(.system(size: titleSize, weight: .heavy)).tracking(-0.03 * titleSize).foregroundStyle(HomeColor.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { dismiss() } label: {
                    Text("Cancel").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.sub).frame(minWidth: 44, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain).accessibilityIdentifier("filters-cancel")
                Spacer()
                Button { withAnimation { draft = DiscoverFilter() } } label: {
                    Text("Reset").font(.system(size: 15.5, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                }
                .buttonStyle(.plain).disabled(!draft.isActive).opacity(draft.isActive ? 1 : 0.55).accessibilityIdentifier("filters-reset")
            }
        }
    }

    private func group<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .bold)).tracking(0.02 * 13).foregroundStyle(HomeColor.sub).accessibilityAddTraits(.isHeader)
            content()
        }
    }

    // MARK: Chips

    private func chips(_ items: [(id: String, title: String)], selected: Set<String>, idPrefix: String, toggle: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(items, id: \.id) { item in
                let on = selected.contains(item.id)
                Button { env.haptics.selection(); toggle(item.id) } label: {
                    HStack(spacing: 6) {
                        if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)) }
                        Text(item.title).font(.system(size: 13.5, weight: on ? .bold : .semibold)).lineLimit(1)
                    }
                    .foregroundStyle(on ? HomeColor.ctaText : HomeColor.ink).padding(.horizontal, 16).frame(minHeight: 38)
                    .background(on ? HomeColor.cta : PassportColor.quiet, in: Capsule())
                    .overlay(Capsule().strokeBorder(on ? .clear : PassportColor.cardLine, lineWidth: 1))
                    .frame(minHeight: 44).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : []).accessibilityIdentifier("filters-\(idPrefix)-\(item.id)")
            }
        }
    }

    // MARK: Country

    private var countryRow: some View {
        Button { path.append(.countries) } label: {
            HStack {
                Text(countrySummary).font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.ink3)
            }
            .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 48)
            .background(PassportColor.quiet, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .frame(minHeight: 48).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier("filters-country-row")
    }

    private var countrySummary: String {
        let names = draft.countryCodes.map { CountryInfo.name(for: $0) }.sorted()
        switch names.count {
        case 0: return String(localized: "Any country")
        case 1, 2: return names.joined(separator: ", ")
        default: return String(localized: "\(names.count) countries")
        }
    }

    // MARK: Show

    private var showControl: some View {
        let binding = Binding(get: { draft.show }, set: { draft.show = $0 })
        return HStack(spacing: 0) {
            ForEach(DiscoverFilter.Show.allCases, id: \.self) { show in
                let on = draft.show == show
                Button { if !on { env.haptics.selection() }; binding.wrappedValue = show } label: {
                    Text(show.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(on ? HomeColor.ctaText : HomeColor.ink)
                        .lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: .infinity, minHeight: 36)
                        .background { if on { Capsule().fill(HomeColor.cta) } }
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2).frame(minHeight: 40).background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .accessibilityRepresentation {
            Picker("Show", selection: binding) { ForEach(DiscoverFilter.Show.allCases, id: \.self) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented).accessibilityIdentifier("filters-show")
        }
    }

    // MARK: Apply

    private var applyButton: some View {
        let count = matchCount(draft)
        let empty = draft.isActive && count == 0
        return Button { onApply(draft) } label: {
            Group {
                if !draft.isActive { Text("Show all places") }
                else if count == 0 { Text("No places match") }
                else { Text("Show ^[\(count) place](inflect: true)") }
            }
            .font(.system(size: 17, weight: .bold)).foregroundStyle(HomeColor.ctaText).contentTransition(.opacity)
            .frame(maxWidth: .infinity, minHeight: 56).background(HomeColor.cta.opacity(empty ? 0.5 : 1), in: Capsule())
        }
        .buttonStyle(.plain).disabled(empty).animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: count)
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 10)
        .background { LinearGradient(colors: [HomeColor.page.opacity(0), HomeColor.page, HomeColor.page], startPoint: .top, endPoint: .bottom).ignoresSafeArea() }
        .accessibilityIdentifier("filters-apply")
    }
}

/// Pushed inside the sheet: a searchable list of the catalog's countries, several can be chosen; none means any country.
struct DiscoverCountryPicker: View {
    @Binding var selection: Set<String>
    let countries: [(code: String, name: String)]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var shown: [(code: String, name: String)] {
        let q = CatalogSearch.normalize(query)
        return q.isEmpty ? countries : countries.filter { CatalogSearch.normalize($0.name).contains(q) }
    }

    var body: some View {
        List {
            ForEach(shown, id: \.code) { country in
                let on = selection.contains(country.code)
                Button { if !selection.insert(country.code).inserted { selection.remove(country.code) } } label: {
                    HStack {
                        Text("\(CountryInfo.flag(for: country.code)) \(country.name)").font(.system(size: 16, weight: .medium)).foregroundStyle(HomeColor.ink)
                        Spacer()
                        if on { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(HomeColor.label) }
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).listRowBackground(HomeColor.page).listRowSeparatorTint(PassportColor.cardLine)
                .accessibilityAddTraits(on ? .isSelected : []).accessibilityIdentifier("filters-country-\(country.code)")
            }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(HomeColor.page)
        .searchable(text: $query, prompt: "Search countries")
        .navigationTitle("Country").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("filters-country-done") } }
    }
}
