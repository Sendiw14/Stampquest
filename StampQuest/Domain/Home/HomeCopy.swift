import Foundation

/// Pure wording and sizing rules for Home. Everything here is tested without a view.
nonisolated enum HomeCopy {
    enum GreetingKind: Equatable { case morning, afternoon, evening, hello, welcome }

    static func greetingKind(hour: Int, isFirstRun: Bool) -> GreetingKind {
        if isFirstRun { return .welcome }
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .hello
        }
    }

    enum Chip: Equatable {
        case places(Int), verified(Int), since(Date)
    }

    /// First match wins; nil hides the chip. No rank or level labels exist.
    static func chip(isFirstRun: Bool, catalogCount: Int, verifiedCount: Int, firstStampDate: Date?) -> Chip? {
        if isFirstRun { return catalogCount >= 20 ? .places(catalogCount / 10 * 10) : nil }
        if verifiedCount >= 1 { return .verified(verifiedCount) }
        return firstStampDate.map(Chip.since)
    }

    /// The count as shown in the numeral: "999+" above 999.
    static func numeralText(_ count: Int) -> String { count > 999 ? "999+" : String(count) }

    /// Numeral point size so the glyph run stays within 196 pt: 320 at most, 84 at least.
    static func numeralSize(unitWidth: Double) -> Double {
        guard unitWidth > 0 else { return 320 }
        return max(84, min(320, 196 / unitWidth))
    }

    /// Distinct countries among collected stamps. A wishlist entry is not a stamp, so it never counts.
    static func countryCount(_ stamps: [CollectedStamp]) -> Int { Set(stamps.map(\.countryCode)).count }
}
