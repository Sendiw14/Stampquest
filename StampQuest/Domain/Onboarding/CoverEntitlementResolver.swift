import Foundation

/// Which cover the passport shows. A Plus cover without Plus shows the first free cover (Terracotta, raw id `clay`); the stored
/// selection is never changed, so the cover comes back when Plus does.
nonisolated enum CoverEntitlementResolver {
    static func effectiveCover(selected: CoverStyle, isEntitled: Bool) -> CoverStyle {
        selected.isPlus && !isEntitled ? CoverStyle.free[0] : selected
    }
}
