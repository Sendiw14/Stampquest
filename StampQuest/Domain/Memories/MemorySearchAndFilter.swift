import Foundation

/// The offline search index over memories: title, text, tags, and the linked place's name, alternative names and country.
/// Ranking: title match, then place match, then tag match, then text match; within a tier newest effective date first.
/// There is no popularity term. Memory text is indexed on device only and never leaves this value.
nonisolated struct MemorySearchIndex: Sendable {
    struct Entry: Sendable {
        let id: UUID
        let title: String
        let place: String
        let tags: [String]
        let text: String
        let effectiveDate: Date
        let createdAt: Date
        let haystack: String
    }

    let entries: [Entry]

    init(items: [MemoryItem], catalog: Catalog, calendar: Calendar = .current, locale: Locale = .current) {
        entries = items.map { item in
            let title = CatalogSearch.normalize(item.displayTitle(calendar: calendar, locale: locale) + " " + item.title)
            let destination = item.destinationID.flatMap { catalog.destination(id: $0) }
            let place = destination.map { CatalogSearch.normalize(([$0.name, $0.countryName] + $0.alternativeNames).joined(separator: " ")) } ?? ""
            let tags = item.tags.map(CatalogSearch.normalize)
            let text = CatalogSearch.normalize(item.text)
            return Entry(id: item.id, title: title, place: place, tags: tags, text: text, effectiveDate: item.effectiveDate, createdAt: item.createdAt,
                         haystack: ([title, place, text] + tags).joined(separator: "|"))
        }
    }

    /// Matching memory ids in rank order.
    func search(_ query: String) -> [UUID] {
        let tokens = CatalogSearch.tokens(query)
        guard !tokens.isEmpty else { return [] }
        var hits: [(entry: Entry, tier: Int)] = []
        for entry in entries where tokens.allSatisfy({ entry.haystack.contains($0) }) {
            var best = 0
            for token in tokens {
                var tier = 0
                if entry.title.contains(token) { tier = 4 }
                else if entry.place.contains(token) { tier = 3 }
                else if entry.tags.contains(where: { $0.contains(token) }) { tier = 2 }
                else if entry.text.contains(token) { tier = 1 }
                best = max(best, tier)
            }
            if best > 0 { hits.append((entry, best)) }
        }
        hits.sort { a, b in
            if a.tier != b.tier { return a.tier > b.tier }
            if a.entry.effectiveDate != b.entry.effectiveDate { return a.entry.effectiveDate > b.entry.effectiveDate }
            return a.entry.createdAt > b.entry.createdAt
        }
        return hits.map(\.entry.id)
    }
}

/// The Filter sheet's choices: AND across groups, OR within a group. Sort is not a filter. Never persisted.
nonisolated struct MemoryFilter: Hashable, Sendable {
    enum Sort: String, CaseIterable, Hashable, Sendable {
        case newest, oldest

        var title: String {
            switch self {
            case .newest: String(localized: "Newest first")
            case .oldest: String(localized: "Oldest first")
            }
        }
    }

    /// One removable chip of the filtered timeline: a whole group.
    enum Chip: Hashable, Sendable { case places, tags, photos, stamp }

    var sort: Sort = .newest
    var placeIDs: Set<String> = []
    /// Tag keys (`MemoryTags.key`), so "Food" and "food" are one tag.
    var tagKeys: Set<String> = []
    var hasPhotos = false
    var linkedToStamp = false

    /// Whether any filter (not the sort) is on.
    var isActive: Bool { !placeIDs.isEmpty || !tagKeys.isEmpty || hasPhotos || linkedToStamp }
    var chips: [Chip] {
        (placeIDs.isEmpty ? [] : [.places]) + (tagKeys.isEmpty ? [] : [.tags]) + (hasPhotos ? [.photos] : []) + (linkedToStamp ? [.stamp] : [])
    }
    /// Nothing selected and the default sort: Reset is dimmed.
    var isDefault: Bool { !isActive && sort == .newest }

    mutating func remove(_ chip: Chip) {
        switch chip {
        case .places: placeIDs = []
        case .tags: tagKeys = []
        case .photos: hasPhotos = false
        case .stamp: linkedToStamp = false
        }
    }

    mutating func clearFilters() { placeIDs = []; tagKeys = []; hasPhotos = false; linkedToStamp = false }

    func matches(_ item: MemoryItem, snapshot: PassportSnapshot) -> Bool {
        if !placeIDs.isEmpty, !(item.destinationID.map(placeIDs.contains) ?? false) { return false }
        if !tagKeys.isEmpty, !item.tags.contains(where: { tagKeys.contains(MemoryTags.key($0)) }) { return false }
        if hasPhotos, !item.hasPhotos { return false }
        if linkedToStamp, !MemoryDerived.isLinkedToStamp(item, snapshot: snapshot) { return false }
        return true
    }

    /// The filtered, sorted memories. The Apply button's count and the timeline both come from here, so they agree.
    func apply(to items: [MemoryItem], snapshot: PassportSnapshot) -> [MemoryItem] {
        MemoryDerived.sorted(items.filter { matches($0, snapshot: snapshot) }, oldestFirst: sort == .oldest)
    }
}
