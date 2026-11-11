import Foundation

/// Stamps collected per month, derived from the records. Months with no activity are
/// included as zeros so a chart has an honest, continuous axis.
nonisolated struct MonthlyCount: Identifiable, Equatable, Sendable {
    let monthStart: Date
    let stamps: Int
    var id: Date { monthStart }
}

nonisolated enum ActivityTimeline {
    /// - Parameter months: how many months ending at (and including) `now`'s month.
    static func monthlyCounts(of stamps: [CollectedStamp], months: Int = 12, now: Date = .now,
                              calendar: Calendar = .current) -> [MonthlyCount] {
        guard months > 0, let currentStart = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        var buckets: [Date: Int] = [:]
        for stamp in stamps {
            if let start = calendar.dateInterval(of: .month, for: stamp.collectedAt)?.start { buckets[start, default: 0] += 1 }
        }
        return (0..<months).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .month, value: -offset, to: currentStart) else { return nil }
            return MonthlyCount(monthStart: start, stamps: buckets[start, default: 0])
        }
    }
}
