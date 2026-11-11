import Foundation

/// How a timeline entry is drawn. Derived from the number of photos and nothing else; never stored or chosen by hand.
nonisolated enum MemoryShape: Equatable, Sendable {
    /// No photos: a quote card.
    case note
    /// One photo: a row with a square thumbnail.
    case row
    /// Exactly two photos.
    case pair
    /// Three or more photos.
    case wide

    init(photoCount: Int) {
        switch photoCount {
        case ..<1: self = .note
        case 1: self = .row
        case 2: self = .pair
        default: self = .wide
        }
    }
}

/// A value copy of a `MemoryEntry`, so derived state, search and filters can be computed (and tested) without SwiftData.
nonisolated struct MemoryItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var text: String
    var eventDate: Date
    var createdAt: Date
    var destinationID: String?
    var stampID: String?
    var tripID: UUID?
    var tags: [String]
    var photoFilenames: [String]

    init(id: UUID = UUID(), title: String = "", text: String = "", eventDate: Date, createdAt: Date? = nil, destinationID: String? = nil,
         stampID: String? = nil, tripID: UUID? = nil, tags: [String] = [], photoFilenames: [String] = []) {
        self.id = id
        self.title = title
        self.text = text
        self.eventDate = eventDate
        self.createdAt = createdAt ?? eventDate
        self.destinationID = destinationID
        self.stampID = stampID
        self.tripID = tripID
        self.tags = tags
        self.photoFilenames = photoFilenames
    }

    /// The date a memory sorts and groups by: the day it is about.
    var effectiveDate: Date { eventDate }

    var shape: MemoryShape { MemoryShape(photoCount: photoFilenames.count) }
    var hasPhotos: Bool { !photoFilenames.isEmpty }

    /// The title, else the first sentence of the text, else the date ("5 November"). Never "Untitled".
    func displayTitle(calendar: Calendar = .current, locale: Locale = .current) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let sentence = MemoryText.firstSentence(text) { return sentence }
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        style = style.day().month(.wide)
        return eventDate.formatted(style)
    }

    /// Newest effective date first; ties by creation date, newest first.
    static func newestFirst(_ a: MemoryItem, _ b: MemoryItem) -> Bool {
        a.effectiveDate != b.effectiveDate ? a.effectiveDate > b.effectiveDate : a.createdAt > b.createdAt
    }
}

nonisolated enum MemoryText {
    /// The first sentence of `text`, trimmed, or nil if there is none.
    static func firstSentence(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var end = trimmed.endIndex
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let ch = trimmed[index]
            if ch == "\n" { end = index; break }
            if ".!?".contains(ch) {
                let next = trimmed.index(after: index)
                if next == trimmed.endIndex || trimmed[next].isWhitespace { end = next; break }
            }
            index = trimmed.index(after: index)
        }
        let sentence = trimmed[trimmed.startIndex..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return sentence.isEmpty ? nil : sentence
    }
}

/// Tags: free text, trimmed, case-insensitive de-duplication (first spelling wins), 1 to 24 characters, at most 8.
nonisolated enum MemoryTags {
    static let maxCount = 8
    static let maxLength = 24

    static func normalize(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in raw {
            let trimmed = String(tag.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(key(trimmed)).inserted else { continue }
            result.append(trimmed)
            if result.count == maxCount { break }
        }
        return result
    }

    /// The comparison key of a tag.
    static func key(_ tag: String) -> String { tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
}

nonisolated struct MemorySection: Identifiable, Equatable, Sendable {
    /// "2026-11"
    let id: String
    /// The first day of the month, in the calendar used to group.
    let monthStart: Date
    let items: [MemoryItem]

    var count: Int { items.count }
}

nonisolated enum MemoryPlaceState: Equatable, Sendable {
    case noPlace, notInPassport, collected, verified
    /// The memory still points at a destination that is no longer in the catalog.
    case removedFromCatalog
}

/// Everything the Memories screens show that is not a stored value: counts, sections and place state, all derived.
nonisolated enum MemoryDerived {
    static func sorted(_ items: [MemoryItem], oldestFirst: Bool = false) -> [MemoryItem] {
        oldestFirst ? items.sorted { MemoryItem.newestFirst($1, $0) } : items.sorted(by: MemoryItem.newestFirst)
    }

    /// Months in the order of `items` (callers sort first). Months group by effective date in `calendar`.
    static func sections(_ items: [MemoryItem], calendar: Calendar = .current) -> [MemorySection] {
        var result: [(key: DateComponents, start: Date, items: [MemoryItem])] = []
        for item in items {
            let key = calendar.dateComponents([.year, .month], from: item.effectiveDate)
            if let last = result.last, last.key == key { result[result.count - 1].items.append(item) }
            else { result.append((key, calendar.date(from: key) ?? item.effectiveDate, [item])) }
        }
        return result.map { MemorySection(id: String(format: "%04d-%02d", $0.key.year ?? 0, $0.key.month ?? 0), monthStart: $0.start, items: $0.items) }
    }

    static func memoryCount(_ items: [MemoryItem]) -> Int { items.count }

    /// Distinct places, including a place that has left the catalog.
    static func placeCount(_ items: [MemoryItem]) -> Int { Set(items.compactMap(\.destinationID)).count }

    static func placeState(of item: MemoryItem, catalog: Catalog, snapshot: PassportSnapshot) -> MemoryPlaceState {
        guard let id = item.destinationID else { return .noPlace }
        guard catalog.destination(id: id) != nil else { return .removedFromCatalog }
        switch snapshot.state(of: id) {
        case .verified: return .verified
        case .collected: return .collected
        case .notCollected, .wishlisted: return .notInPassport
        }
    }

    /// True when the memory is tied to a place whose stamp is in the passport.
    static func isLinkedToStamp(_ item: MemoryItem, snapshot: PassportSnapshot) -> Bool {
        guard item.stampID != nil, let id = item.destinationID else { return false }
        return snapshot.state(of: id).isInPassport
    }

    static func memories(forDestination id: String, in items: [MemoryItem]) -> [MemoryItem] {
        items.filter { $0.destinationID == id }.sorted(by: MemoryItem.newestFirst)
    }

    static func memories(forStamp stampID: String, in items: [MemoryItem]) -> [MemoryItem] {
        items.filter { $0.stampID == stampID }.sorted(by: MemoryItem.newestFirst)
    }

    /// Tags in use with their counts: most used first, ties alphabetical. The first spelling seen is shown.
    static func tagCounts(_ items: [MemoryItem]) -> [(tag: String, count: Int)] {
        var counts: [String: (tag: String, count: Int)] = [:]
        for item in items { for tag in item.tags {
            let key = MemoryTags.key(tag)
            counts[key] = (counts[key]?.tag ?? tag, (counts[key]?.count ?? 0) + 1)
        } }
        return counts.values.sorted { $0.count != $1.count ? $0.count > $1.count : $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
            .map { (tag: $0.tag, count: $0.count) }
    }

    /// Places with at least one memory: most memories first, ties alphabetical by name.
    static func placeCounts(_ items: [MemoryItem], catalog: Catalog) -> [(id: String, name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in items { if let id = item.destinationID { counts[id, default: 0] += 1 } }
        return counts.map { (id: $0.key, name: catalog.destination(id: $0.key)?.name ?? String(localized: "Place no longer in the catalog"), count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The two photos shown as prints in the header: the newest memory with photos, and the next newest with photos that
    /// belongs to a different place (else simply the next newest with photos).
    static func prints(_ items: [MemoryItem]) -> [String] {
        let withPhotos = items.sorted(by: MemoryItem.newestFirst).filter(\.hasPhotos)
        guard let first = withPhotos.first, let front = first.photoFilenames.first else { return [] }
        var result = [front]
        let rest = withPhotos.dropFirst()
        let other = rest.first { $0.destinationID != first.destinationID } ?? rest.first
        if let back = other?.photoFilenames.first { result.append(back) }
        return result
    }
}
