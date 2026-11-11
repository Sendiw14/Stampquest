import CoreGraphics
import Foundation

/// Entrance schedule (seconds from appear) and the layout numbers of the Plus screen, in points of the 402 x 874 reference. Pure.
nonisolated struct PlusTimeline: Sendable {
    enum Beat: Hashable, Sendable {
        case topBar, cover, stampLeft, stampRight, seal, sealLand, brand, plusWord, subtitle
        case perk(Int), line, node(Int), planYearly, planMonthly, badge, cta, finePrint, links
        case floatCover, floatLeft, floatRight
    }

    static let standard = PlusTimeline()
    static let perkCount = 4
    static let nodeCount = 3

    func delay(of beat: Beat) -> TimeInterval {
        switch beat {
        case .topBar: 0.05
        case .cover: 0.20
        case .stampLeft: 0.55
        case .stampRight: 0.65
        case .seal: 1.15
        case .sealLand: 1.45
        case .brand: 0.80
        case .plusWord: 1.00
        case .subtitle: 1.30
        case .perk(let index): 1.45 + 0.08 * Double(index)
        case .line: 2.05
        case .node(let index): 1.95 + 0.14 * Double(index)
        case .planYearly: 2.35
        case .planMonthly: 2.45
        case .badge: 2.80
        case .cta: 2.65
        case .finePrint: 2.85
        case .links: 3.00
        case .floatCover: 2.6
        case .floatLeft: 3.4
        case .floatRight: 3.9
        }
    }

    var beats: [Beat] {
        [.topBar, .cover, .stampLeft, .stampRight, .seal, .sealLand, .brand, .plusWord, .subtitle, .line, .planYearly, .planMonthly, .badge,
         .cta, .finePrint, .links, .floatCover, .floatLeft, .floatRight]
            + (0..<Self.perkCount).map { Beat.perk($0) } + (0..<Self.nodeCount).map { Beat.node($0) }
    }

    var schedule: [(time: TimeInterval, beat: Beat)] { beats.map { (delay(of: $0), $0) } }
}

/// Layout numbers of the Plus screen.
nonisolated enum PlusMetrics {
    static let referenceHeight: CGFloat = 874
    static let sideMargin: CGFloat = 24
    static let contentMaxWidth: CGFloat = 480
    static let closeSize: CGFloat = 30
    static let closeHit: CGFloat = 44
    /// Hero block: from the top of the cover (y 98) to the top of the headline row (y 294).
    static let heroHeight: CGFloat = 196
    static let coverWidth: CGFloat = 124
    static let stampSize = CGSize(width: 76, height: 92)
    static let stampPitch: CGFloat = 9
    /// Horizontal distance from the hero's centre to the stamps' centres.
    static let stampOffsetX: CGFloat = 115
    static let sealSize: CGFloat = 60
    static let headlineSize: CGFloat = 34
    static let wordSize = CGSize(width: 100, height: 48)
    static let tileHeight: CGFloat = 48
    static let tileGap: CGFloat = 8
    static let tileColumnGap: CGFloat = 12
    static let nodeSize: CGFloat = 24
    static let planHeight: CGFloat = 86
    static let planGap: CGFloat = 12
    static let ctaHeight: CGFloat = 58
    static let minHeroScale: CGFloat = 0.7

    /// Hero scale and the factor applied to the gaps between blocks, for a screen `height` tall: gaps compress first (down to half),
    /// then the hero shrinks (never below `minHeroScale`); whatever still does not fit scrolls.
    static func scales(forHeight height: CGFloat) -> (gap: CGFloat, hero: CGFloat) {
        let ratio = min(1, height / referenceHeight)
        return (max(0.5, ratio), max(minHeroScale, ratio))
    }

    /// Rows of perk tile indices for `count` tiles in two columns: a lone last tile sits alone and spans the full width.
    static func perkRows(count: Int, columns: Int = 2) -> [[Int]] {
        guard count > 0 else { return [] }
        return stride(from: 0, to: count, by: columns).map { Array($0..<min($0 + columns, count)) }
    }

    /// The three-step timeline's node centres are 127 pt apart and the two-step's 178 pt, at the 402 pt reference width.
    static func nodeSpacing(steps: Int, width: CGFloat) -> CGFloat { (steps >= 3 ? 127 : 178) / 402 * width }
    static func labelWidth(steps: Int) -> CGFloat { steps >= 3 ? 108 : 140 }
}
