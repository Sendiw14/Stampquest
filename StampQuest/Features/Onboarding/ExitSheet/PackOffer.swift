import Foundation

/// An extra stamp pack sold once. The manifest is the single list of packs: product id, the interest it belongs to, the catalog key of the
/// phrase in its blurb ("the shores you picked") and its preview stamps, hero (front of the stack) first.
nonisolated struct Pack: Identifiable, Equatable, Sendable {
    typealias ID = String

    let id: ID
    let interest: Interest
    let subjectKey: String
    let stamps: [StampDestination]
    /// False until the pack has its own artwork. A pack without real art is never offered (no placeholder art ships).
    var hasRealArt = false
}

nonisolated enum PackProductID {
    static let coasts = "com.stampquest.pack.coasts"
}

nonisolated enum PackManifest {
    /// Coasts has no artwork of its own yet: the three onboarding stamps stand in for layout work only, and `hasRealArt` keeps the pack row
    /// hidden. Set it to true when the Coasts stamps are drawn and listed here.
    static let coasts = Pack(id: PackProductID.coasts, interest: .coasts, subjectKey: "exit.pack.subject.coasts",
                             stamps: [.santorini, .paris, .kyoto], hasRealArt: false)
    static let all = [coasts]
    static let featured = coasts
}

/// Which pack the exit sheet offers. Pure.
nonisolated enum PackOffer {
    struct Offer: Equatable, Sendable {
        let pack: Pack
        /// False: use the generic blurb (no interest led to this pack).
        let isForInterest: Bool
    }

    /// The pack of the first interest, in tile order, that has an unowned pack. No interest with a pack (or none picked): the featured pack
    /// with the generic blurb. Nil when every candidate is owned.
    static func choose(interests: Set<Interest>, owned: Set<Pack.ID>, manifest: [Pack] = PackManifest.all,
                       featured: Pack = PackManifest.featured) -> Offer? {
        let manifest = manifest.filter(\.hasRealArt)
        guard featured.hasRealArt || !manifest.isEmpty else { return nil }
        let candidates = Interest.allCases.filter(interests.contains).compactMap { interest in manifest.first { $0.interest == interest } }
        if let first = candidates.first(where: { !owned.contains($0.id) }) { return Offer(pack: first, isForInterest: true) }
        if !candidates.isEmpty { return nil }
        return owned.contains(featured.id) || !featured.hasRealArt ? nil : Offer(pack: featured, isForInterest: false)
    }

    /// "Stamps for the shores you picked. Buy once, keep forever." when interests led to the pack, the generic line otherwise.
    static func blurb(for pack: Pack, isForInterest: Bool) -> String {
        isForInterest ? String(localized: "exit.pack.blurb \(String(localized: String.LocalizationValue(pack.subjectKey)))")
                      : String(localized: "exit.pack.blurb.generic")
    }
}
