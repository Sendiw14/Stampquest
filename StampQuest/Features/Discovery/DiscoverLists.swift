import SwiftUI
import SwiftData

/// The Results list: places for an interest, a collection, or a set of filters. Filters are removable chips; the list is
/// A to Z (collection order inside a collection); there is no popularity sort.
struct DiscoverResultsView: View {
    let spec: DiscoverResultsSpec

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: DiscoverFilter
    @State private var showFilters = false

    init(spec: DiscoverResultsSpec) {
        self.spec = spec
        _filter = State(initialValue: spec.filter)
    }

    private var title: String {
        switch spec.scope {
        case .places: String(localized: "Places")
        case .category(let category): category.title
        case .collection(let id): passport.catalog.collection(id: id)?.title ?? String(localized: "Places")
        }
    }

    private func matches(_ filter: DiscoverFilter) -> [Destination] {
        DiscoverResults.matches(scope: spec.scope, filter: filter, catalog: passport.catalog, state: passport.snapshot.state(of:))
    }

    var body: some View {
        let found = matches(filter).compactMap { passport.item($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if case .collection(let id) = spec.scope, let progress = passport.progress(forCollection: id) {
                    Text("^[\(progress.total) place](inflect: true) · \(progress.collected) collected").font(.system(size: 14, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
                if filter.isActive { chipRow }
                Text("Showing ^[\(found.count) place](inflect: true)").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.sub)
                    .accessibilityIdentifier("results-count")
                if found.isEmpty {
                    EmptyStateView(title: "No places match", message: "Try removing a filter.", systemImage: "line.3.horizontal.decrease.circle",
                                   actionTitle: "Clear filters") { withAnimation { filter = DiscoverFilter() } }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(found) { item in
                            Button { env.router.push(.destination(item.id)) } label: { DiscoverPlaceRow(item: item) }
                                .buttonStyle(.plain).accessibilityIdentifier("result-\(item.id)")
                            Rectangle().fill(PassportColor.cardLine).frame(height: 1)
                        }
                    }
                }
            }
            .frame(maxWidth: 560, alignment: .leading).padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 60).frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: filter)
        }
        .background(HomeColor.page.ignoresSafeArea())
        .navigationTitle(title).navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showFilters = true } label: { Text("Filters") }.accessibilityIdentifier("results-filters")
            }
        }
        .sheet(isPresented: $showFilters) {
            DiscoverFiltersSheet(initial: filter, matchCount: { matches($0).count },
                                 countries: passport.catalog.countries.map { ($0.code, $0.name) },
                                 regions: Region.allCases.filter { r in passport.catalog.destinations.contains { $0.region == r } },
                                 categories: DestinationCategory.allCases.filter { c in passport.catalog.destinations.contains { $0.category == c } },
                                 onApply: { filter = $0; showFilters = false })
                .presentationDetents([.medium, .large], selection: .constant(.large))
                .presentationDragIndicator(.visible).presentationCornerRadius(36)
        }
    }

    private var chipRow: some View {
        HStack(alignment: .top, spacing: 8) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(filter.chips, id: \.id) { chip in
                    Button { withAnimation { filter.remove(chip) } } label: {
                        HStack(spacing: 6) {
                            Text(chip.title).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                            Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(HomeColor.label).padding(.horizontal, 12).frame(minHeight: 32)
                        .background(PassportColor.accentTint, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.accentBorder, lineWidth: 1))
                        .frame(minHeight: 44).contentShape(Capsule())
                    }
                    .buttonStyle(.plain).padding(.vertical, -6)
                    .accessibilityLabel(Text("\(chip.title), remove filter")).accessibilityIdentifier("chip-\(chip.id)")
                }
            }
            Button { withAnimation { filter = DiscoverFilter() } } label: {
                Text("Clear all").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain).accessibilityIdentifier("results-clear-all")
        }
    }
}

/// "See all" on Browse by interest: every interest as a stamp in a three-column grid.
struct AllInterestsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @Query private var profiles: [PassportProfile]

    private var picks: Set<Interest> { Set(profiles.first?.interestRaws.compactMap(Interest.init(rawValue:)) ?? []) }

    var body: some View {
        let derived = DiscoverDerived.make(catalog: passport.catalog, snapshot: passport.snapshot, recentIDs: [], picks: picks)
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3), alignment: .leading, spacing: 26) {
                ForEach(Array(derived.interests.enumerated()), id: \.element.id) { index, interest in
                    Button { env.router.push(.category(interest.category)) } label: {
                        DiscoverInterestTile(interest: interest, art: passport.item(id: interest.artDestinationID),
                                             tilt: DiscoverInterestRail.tilts[index % DiscoverInterestRail.tilts.count])
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("discover-interest-\(interest.category.rawValue)")
                }
            }
            .frame(maxWidth: 560).padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 60).frame(maxWidth: .infinity)
        }
        .background(HomeColor.page.ignoresSafeArea())
        .navigationTitle("Interests").navigationBarTitleDisplayMode(.large)
    }
}

/// Used by "More from [country]" on a destination.
struct CountryResultsView: View {
    let countryCode: String
    @Environment(\.passport) private var passport

    var body: some View {
        DestinationListScreen(title: "\(CountryInfo.flag(for: countryCode)) \(CountryInfo.name(for: countryCode))",
                              items: passport.allItems.filter { $0.destination.countryCode == countryCode })
    }
}

struct DestinationListScreen: View {
    let title: String
    let items: [DestinationItem]
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView {
            if items.isEmpty {
                EmptyStateView(title: "Nothing here yet", message: "There are no places in this list.", systemImage: "tray").padding(.top, SQSpace.xl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        Button { env.router.push(.destination(item.id)) } label: { DestinationRow(item: item) }.buttonStyle(.plain)
                        Divider().overlay(SQColor.separator)
                    }
                }
                .padding(.horizontal, SQSpace.screenMargin)
            }
        }
        .sqScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
