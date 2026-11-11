import Foundation

/// Today's featured stamp, the side stamp and the three picks. Deterministic for one install and one local day.
nonisolated struct HomeFeaturedPicks: Equatable, Sendable {
    var featured: String?
    var side: String?
    var picks: [String]
}

nonisolated enum HomeFeaturedPicker {
    /// Stable across launches (Swift's `Hasher` is not): FNV-1a over the install id and the day number.
    static func seed(installID: String, day: Int) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in "\(installID)#\(day)".utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return hash
    }

    static func dayNumber(_ date: Date, calendar: Calendar) -> Int {
        Int((calendar.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400).rounded())
    }

    /// `pool` is already deduplicated and ordered by priority groups; this shuffles it by the seed.
    static func shuffled(_ pool: [String], seed: UInt64) -> [String] {
        var state = seed
        func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        var result = pool.sorted()
        for index in stride(from: result.count - 1, to: 0, by: -1) { result.swapAt(index, Int(next() % UInt64(index + 1))) }
        return result
    }

    /// - Parameters:
    ///   - priority: uncollected destinations from the wishlist, then the next of each in-progress set, then catalog featured.
    ///   - rest: every other uncollected destination, used only to fill up to five.
    ///   - firstRun: the catalog's first-run defaults (featured first), used when nothing is collected.
    static func picks(priority: [String], rest: [String], firstRun: [String]?, seed: UInt64) -> HomeFeaturedPicks {
        if let firstRun, let first = firstRun.first {
            let others = Array(firstRun.dropFirst())
            return HomeFeaturedPicks(featured: first, side: others.first, picks: Array(others.prefix(3)))
        }
        var seen = Set<String>()
        let primary = priority.filter { seen.insert($0).inserted }
        let filler = rest.filter { seen.insert($0).inserted }
        var order = shuffled(primary, seed: seed)
        if order.count < 5 { order += shuffled(filler, seed: seed &+ 1).prefix(5 - order.count) }
        let featured = order.first
        let others = Array(order.dropFirst())
        return HomeFeaturedPicks(featured: featured, side: others.first, picks: Array(others.prefix(3)))
    }
}
