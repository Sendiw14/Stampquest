import Foundation

/// One match in the Search screen. Places and landmarks point at a destination; a collection hit may say which member
/// of the collection made it match.
nonisolated struct DiscoverSearchResults: Equatable, Sendable {
    struct Place: Equatable, Sendable { let destinationID: String }
    struct Landmark: Equatable, Sendable { let destinationID: String; let landmark: String }
    struct Collection: Equatable, Sendable { let collectionID: String; let memberName: String? }

    var places: [Place] = []
    var landmarks: [Landmark] = []
    var collections: [Collection] = []

    var isEmpty: Bool { places.isEmpty && landmarks.isEmpty && collections.isEmpty }
    var count: Int { places.count + landmarks.count + collections.count }
}

/// The offline search index (D2): built once per catalog version from names, alternative names, countries, regions,
/// landmark names, categories, curated keywords and collection titles with their member names.
///
/// Ranking: exact name, then name prefix, then word prefix, then contains, then everything else (alternative names,
/// country, region, category, keywords). Ties break alphabetically. There is no popularity or "featured" term.
nonisolated struct DiscoverSearchIndex: Sendable {
    struct PlaceEntry: Sendable {
        let id: String
        let name: String
        let sortName: String
        let alternatives: [String]
        let country: String
        let region: String
        let category: String
        let keywords: [String]
        /// Everything the place can match on, joined; a cheap first filter before the detailed scoring.
        let haystack: String
    }

    struct LandmarkEntry: Sendable { let destinationID: String; let landmark: String; let text: String }
    struct MemberEntry: Sendable { let name: String; let text: String }
    struct CollectionEntry: Sendable { let id: String; let title: String; let members: [MemberEntry] }

    let places: [PlaceEntry]
    let landmarks: [LandmarkEntry]
    let collections: [CollectionEntry]

    init(catalog: Catalog) {
        places = catalog.destinations.map { d in
            let name = CatalogSearch.normalize(d.name)
            let alternatives = d.alternativeNames.map(CatalogSearch.normalize)
            let country = CatalogSearch.normalize(d.countryName)
            let region = CatalogSearch.normalize(d.region.title)
            let category = CatalogSearch.normalize(d.category.title + " " + d.category.singularTitle)
            let keywords = d.keywords.map(CatalogSearch.normalize)
            let haystack = ([name, country, region, category] + alternatives + keywords).joined(separator: "|")
            return PlaceEntry(id: d.id, name: name, sortName: name, alternatives: alternatives, country: country, region: region,
                              category: category, keywords: keywords, haystack: haystack)
        }
        landmarks = catalog.destinations.compactMap { d in
            let text = CatalogSearch.normalize(d.landmark)
            guard !text.isEmpty, text != CatalogSearch.normalize(d.name) else { return nil }
            return LandmarkEntry(destinationID: d.id, landmark: d.landmark, text: text)
        }
        collections = catalog.collections.map { c in
            CollectionEntry(id: c.id, title: CatalogSearch.normalize(c.title),
                            members: c.destinationIDs.compactMap(catalog.destination(id:)).map { MemberEntry(name: $0.name, text: CatalogSearch.normalize($0.name)) })
        }
    }

    // MARK: Cache (one index per catalog version)

    @MainActor private static var cache: [String: DiscoverSearchIndex] = [:]

    @MainActor
    static func shared(for catalog: Catalog) -> DiscoverSearchIndex {
        let key = "\(catalog.version)#\(catalog.destinations.count)#\(catalog.collections.count)"
        if let hit = cache[key] { return hit }
        let built = DiscoverSearchIndex(catalog: catalog)
        cache[key] = built
        return built
    }

    // MARK: Search

    func search(_ query: String) -> DiscoverSearchResults {
        let tokens = CatalogSearch.tokens(query)
        guard !tokens.isEmpty else { return DiscoverSearchResults() }
        let whole = tokens.joined(separator: " ")

        var scoredPlaces: [(entry: PlaceEntry, score: Int)] = []
        for entry in places {
            // One substring test per token rejects most places before any detailed scoring.
            guard tokens.allSatisfy({ entry.haystack.contains($0) }) else { continue }
            var total = 0
            var matchedAll = true
            for token in tokens {
                let s = Self.score(token, in: entry)
                if s == 0 { matchedAll = false; break }
                total += s
            }
            guard matchedAll else { continue }
            scoredPlaces.append((entry, Self.nameTier(whole, entry.name) * 1_000 + total))
        }
        scoredPlaces.sort { $0.score != $1.score ? $0.score > $1.score : $0.entry.sortName < $1.entry.sortName }

        var landmarkHits: [(entry: LandmarkEntry, score: Int)] = []
        for entry in landmarks where tokens.allSatisfy({ entry.text.contains($0) }) {
            landmarkHits.append((entry, Self.nameTier(whole, entry.text)))
        }
        landmarkHits.sort { $0.score != $1.score ? $0.score > $1.score : $0.entry.text < $1.entry.text }

        var collectionHits: [(DiscoverSearchResults.Collection, Int, String)] = []
        for entry in collections {
            if tokens.allSatisfy({ entry.title.contains($0) }) {
                collectionHits.append((.init(collectionID: entry.id, memberName: nil), 100 + Self.nameTier(whole, entry.title), entry.title))
            } else if let member = entry.members.first(where: { member in tokens.allSatisfy { member.text.contains($0) } }) {
                collectionHits.append((.init(collectionID: entry.id, memberName: member.name), Self.nameTier(whole, member.text), entry.title))
            }
        }
        collectionHits.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 < $1.2 }

        return DiscoverSearchResults(places: scoredPlaces.map { .init(destinationID: $0.entry.id) },
                                     landmarks: landmarkHits.map { .init(destinationID: $0.entry.destinationID, landmark: $0.entry.landmark) },
                                     collections: collectionHits.map(\.0))
    }

    /// 4 exact, 3 prefix, 2 word prefix, 1 contains, 0 none: the order the spec asks for, on the whole query.
    static func nameTier(_ query: String, _ text: String) -> Int {
        if text == query { return 4 }
        if text.hasPrefix(query) { return 3 }
        if text.contains(" " + query) { return 2 }
        if text.contains(query) { return 1 }
        return 0
    }

    private static func score(_ token: String, in e: PlaceEntry) -> Int {
        var best = 0
        func consider(_ text: String, exact: Int, prefix: Int, word: Int, contains: Int) {
            if text == token { best = max(best, exact) }
            else if text.hasPrefix(token) { best = max(best, prefix) }
            else if wordPrefix(text, token) { best = max(best, word) }
            else if token.count >= 3 && text.contains(token) { best = max(best, contains) }
        }
        consider(e.name, exact: 100, prefix: 90, word: 80, contains: 60)
        for alt in e.alternatives { consider(alt, exact: 98, prefix: 88, word: 78, contains: 58) }
        consider(e.country, exact: 55, prefix: 50, word: 48, contains: 40)
        consider(e.region, exact: 45, prefix: 40, word: 38, contains: 30)
        consider(e.category, exact: 45, prefix: 40, word: 38, contains: 30)
        for k in e.keywords { consider(k, exact: 35, prefix: 30, word: 28, contains: 20) }
        return best
    }

    private static func wordPrefix(_ text: String, _ token: String) -> Bool {
        text.split(separator: " ").contains { $0.hasPrefix(token) }
    }
}

/// "Try" ideas for the Search screen. Only ideas that return at least one result are offered.
nonisolated enum DiscoverIdeas {
    static func make(catalog: Catalog, index: DiscoverSearchIndex, limit: Int = 6) -> [String] {
        let present = Set(catalog.destinations.map(\.category))
        let preferred: [DestinationCategory] = [.beach, .island, .hiddenGem, .nationalPark, .foodCulture, .architecture, .nature, .museum, .landmark, .city]
        var candidates = preferred.filter(present.contains).map(\.title)
        // Countries with more than one place read as a real idea; alphabetical, never ranked by anything.
        candidates += catalog.countries.filter { $0.destinationIDs.count > 1 }.map(\.name)
        candidates += catalog.countries.filter { $0.destinationIDs.count == 1 }.map(\.name)
        var seen = Set<String>()
        var ideas: [String] = []
        for term in candidates where seen.insert(term).inserted {
            guard !index.search(term).isEmpty else { continue }
            ideas.append(term)
            if ideas.count == limit { break }
        }
        return ideas
    }
}
