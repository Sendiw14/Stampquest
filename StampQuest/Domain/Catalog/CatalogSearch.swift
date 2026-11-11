import Foundation

/// Ranked, forgiving search over catalogue destinations.
nonisolated enum CatalogSearch {
    /// Pre-normalised searchable text for one destination.
    struct Entry: Sendable {
        let id: String
        let name: String
        let landmark: String
        let altNames: [String]
        let country: String
        let region: String
        let category: String
        let keywords: [String]
        let summary: String
        let featured: Bool

        init(_ d: Destination) {
            id = d.id
            name = CatalogSearch.normalize(d.name)
            landmark = CatalogSearch.normalize(d.landmark)
            altNames = d.alternativeNames.map(CatalogSearch.normalize)
            country = CatalogSearch.normalize(d.countryName)
            region = CatalogSearch.normalize(d.region.title)
            category = CatalogSearch.normalize(d.category.title + " " + d.category.singularTitle)
            keywords = d.keywords.map(CatalogSearch.normalize)
            summary = CatalogSearch.normalize(d.summary)
            featured = d.isFeatured
        }
    }

    /// Lowercases and strips diacritics and punctuation so "Reykjavík", "reykjavik"
    /// and "Reykjavik!" all match.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        let cleaned = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(cleaned)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    static func tokens(_ query: String) -> [String] {
        normalize(query).split(separator: " ").map(String.init)
    }

    static func search(_ query: String, in entries: [Entry], destinations: [String: Destination]) -> [Destination] {
        let queryTokens = tokens(query)
        if queryTokens.isEmpty { return entries.compactMap { destinations[$0.id] } }

        var results: [(Destination, Int)] = []
        for entry in entries {
            var total = 0
            var matchedAll = true
            for token in queryTokens {
                let s = score(token, in: entry)
                if s == 0 { matchedAll = false; break }
                total += s
            }
            if matchedAll, let d = destinations[entry.id] {
                results.append((d, total + (entry.featured ? 2 : 0)))
            }
        }
        return results
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.name.localizedCompare($1.0.name) == .orderedAscending }
            .map(\.0)
    }

    private static func score(_ token: String, in e: Entry) -> Int {
        var best = 0
        func consider(_ text: String, exact: Int, prefix: Int, contains: Int) {
            if text == token { best = max(best, exact) }
            else if text.hasPrefix(token) || wordPrefix(text, token) { best = max(best, prefix) }
            else if token.count >= 3 && text.contains(token) { best = max(best, contains) }
        }
        consider(e.name, exact: 100, prefix: 85, contains: 60)
        consider(e.landmark, exact: 90, prefix: 78, contains: 55)
        for alt in e.altNames { consider(alt, exact: 88, prefix: 74, contains: 50) }
        consider(e.country, exact: 70, prefix: 60, contains: 35)
        for k in e.keywords { consider(k, exact: 55, prefix: 45, contains: 30) }
        consider(e.region, exact: 45, prefix: 40, contains: 20)
        consider(e.category, exact: 45, prefix: 40, contains: 20)
        if token.count >= 4 && e.summary.contains(token) { best = max(best, 12) }
        return best
    }

    private static func wordPrefix(_ text: String, _ token: String) -> Bool {
        text.split(separator: " ").contains { $0.hasPrefix(token) }
    }
}
