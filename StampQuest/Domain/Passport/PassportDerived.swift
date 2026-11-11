import Foundation

/// One collected stamp joined to the catalogue. Either catalogue half can be missing (a destination that left the
/// catalogue), in which case the screen draws the missing-artwork placeholder from the record's own snapshot.
nonisolated struct PassportEntry: Identifiable, Hashable, Sendable {
    let stamp: CollectedStamp
    let destination: Destination?
    let design: StampDesign?

    var id: String { stamp.stampID }
    var destinationID: String { stamp.destinationID }
    var name: String { destination?.name ?? stamp.title }
    var countryName: String { CountryInfo.name(for: stamp.countryCode) }
    var collectedAt: Date { stamp.collectedAt }
    var isVerified: Bool { stamp.isVerified }
    var isFavorite: Bool { stamp.isFavorite }
}

/// The four numbers on the ticket. All describe the whole passport and never react to filters.
nonisolated struct PassportMetrics: Equatable, Sendable {
    let collected: Int
    let verified: Int
    let countries: Int
    /// Collections in which at least one stamp is held. Started, not completed.
    let sets: Int

    static func compute(snapshot: PassportSnapshot, catalog: Catalog) -> PassportMetrics {
        let stamps = snapshot.stamps
        let owned = Set(stamps.map(\.destinationID))
        return PassportMetrics(
            collected: stamps.count,
            verified: stamps.filter(\.isVerified).count,
            countries: Set(stamps.map(\.countryCode)).count,
            sets: catalog.collections.filter { !owned.isDisjoint(with: $0.destinationIDs) }.count)
    }
}

/// A removable filter chip shown under the controls.
nonisolated struct PassportFilterChip: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable { case verified, favorites, country(String), collection(String) }
    let kind: Kind
    let title: String
    var id: String {
        switch kind {
        case .verified: "verified"
        case .favorites: "favorites"
        case .country(let code): "country.\(code)"
        case .collection(let id): "collection.\(id)"
        }
    }
}

/// Everything the Passport screen shows, derived from the records in one pass.
nonisolated struct PassportDerived: Sendable {
    /// Every stamp, unfiltered, most recent first.
    let all: [PassportEntry]
    /// `all` after the active filters, in the active sort.
    let visible: [PassportEntry]
    let metrics: PassportMetrics
    let chips: [PassportFilterChip]

    var hiddenCount: Int { all.count - visible.count }
    var isEmpty: Bool { all.isEmpty }

    static func make(snapshot: PassportSnapshot, catalog: Catalog, query: PassportQuery) -> PassportDerived {
        let entries = snapshot.stamps.map { PassportEntry(stamp: $0, destination: catalog.destination(id: $0.destinationID),
                                                          design: catalog.stamp(forDestination: $0.destinationID)) }
        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let visible = query.apply(to: snapshot.stamps, catalog: catalog).compactMap { byID[$0.stampID] }
        return PassportDerived(all: entries, visible: visible, metrics: .compute(snapshot: snapshot, catalog: catalog),
                               chips: query.chips(catalog: catalog))
    }

    /// Countries that appear in the collection, A to Z, for the filter sheet.
    static func countries(in entries: [PassportEntry]) -> [(code: String, name: String)] {
        Set(entries.map(\.stamp.countryCode)).map { ($0, CountryInfo.name(for: $0)) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    /// Collections in which a stamp is held, in display order.
    static func collections(in entries: [PassportEntry], catalog: Catalog) -> [StampCollection] {
        let owned = Set(entries.map(\.destinationID))
        return catalog.collections.filter { !owned.isDisjoint(with: $0.destinationIDs) }
    }
}

/// Paper pages of four stamps, in the active sort.
nonisolated enum PassportPaging {
    static let pageSize = 4

    /// Chunks of four. When the last page is full (or there are none) an empty page follows, so there is always an open
    /// slot to add a stamp by hand.
    static func pages(_ entries: [PassportEntry]) -> [[PassportEntry]] {
        var pages = stride(from: 0, to: entries.count, by: pageSize).map { Array(entries[$0..<min($0 + pageSize, entries.count)]) }
        if pages.last.map({ $0.count == pageSize }) ?? true { pages.append([]) }
        return pages
    }

    /// "Nov to Oct 2026" for a page: the span of collection dates on it.
    static func dateSpan(_ page: [PassportEntry], calendar: Calendar = .current, locale: Locale = .current) -> String {
        let dates = page.map(\.collectedAt)
        guard let first = dates.min(), let last = dates.max() else { return "" }
        func style(_ withYear: Bool) -> Date.FormatStyle {
            var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated)
            if withYear { style = style.year() }
            return style
        }
        let a = calendar.dateComponents([.year, .month], from: first), b = calendar.dateComponents([.year, .month], from: last)
        if a == b { return last.formatted(style(true)) }
        if a.year == b.year { return String(localized: "\(first.formatted(style(false))) to \(last.formatted(style(true)))") }
        return String(localized: "\(first.formatted(style(true))) to \(last.formatted(style(true)))")
    }
}

/// How stamps are tilted: by grid position, never random per launch.
nonisolated enum PassportTilt {
    static let grid: [Double] = [-1.5, 1.2, -1.0, 1.5, -1.2, 1.0, -1.6, 1.3]
    static let page: [Double] = [-3, 2.2, 1.6, -2.4]
    static func grid(_ index: Int) -> Double { grid[index % grid.count] }
    static func page(_ index: Int) -> Double { page[index % page.count] }
}

nonisolated enum PassportDateText {
    /// "5 Nov" in the current year, "5 Nov 2025" otherwise (the order follows the locale).
    static func short(_ date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        if !sameYear { style = style.year() }
        return date.formatted(style)
    }

    static func withYear(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated).year())
    }

    static func long(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day().month(.wide))
    }
}

/// What the share image is allowed to contain. Stamps, counts and the owner's name only: this type has no field for a
/// note, a caption, a memory or a photo, so none can leak.
nonisolated struct PassportExportModel: Sendable {
    struct Item: Sendable { let design: StampDesign; let name: String; let date: Date; let isVerified: Bool }
    let ownerName: String
    let stampCount: Int
    let countryCount: Int
    let items: [Item]

    static func make(entries: [PassportEntry], metrics: PassportMetrics, ownerName: String) -> PassportExportModel {
        PassportExportModel(ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines), stampCount: metrics.collected,
                            countryCount: metrics.countries,
                            items: entries.compactMap { entry in
                                entry.design.map { Item(design: $0, name: entry.name, date: entry.collectedAt, isVerified: entry.isVerified) }
                            })
    }
}
