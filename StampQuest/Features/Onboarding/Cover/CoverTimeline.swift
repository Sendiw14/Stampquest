import Foundation

/// Delays of the Cover entrance, in seconds from the moment the screen appears. Pure.
nonisolated struct CoverTimeline: Sendable {
    enum Beat: Hashable, Sendable {
        case back, skip, progress, firstLine, cover, stop, subtitle, hero, neighbours
        case swatch(Int)
        case ring, name, field, helper, cta
    }

    static let standard = CoverTimeline()
    static let swatchCount = 5

    func delay(of beat: Beat) -> TimeInterval {
        switch beat {
        case .back: 0.05
        case .skip: 0.08
        case .progress: 0.10
        case .firstLine: 0.20
        case .cover: 0.62
        case .stop: 0.95
        case .subtitle: 1.00
        case .hero: 1.05
        case .neighbours: 1.40
        case .swatch(let index): 1.75 + 0.06 * Double(index)
        case .ring: 1.95
        case .name: 2.05
        case .field: 2.20
        case .helper: 2.28
        case .cta: 2.40
        }
    }

    var beats: [Beat] {
        [.back, .skip, .progress, .firstLine, .cover, .stop, .subtitle, .hero, .neighbours, .ring, .name, .field, .helper, .cta]
            + (0..<Self.swatchCount).map { Beat.swatch($0) }
    }

    var schedule: [(time: TimeInterval, beat: Beat)] { beats.map { (delay(of: $0), $0) } }

    /// How long the typing must pause before the foil sheen runs, and the least time between two runs.
    static let sheenPause: TimeInterval = 0.5
    static let sheenCooldown: TimeInterval = 4
    static let sheenDuration: TimeInterval = 0.95
    /// The sheen band travels between these left edges, in design units.
    static let sheenRange: ClosedRange<Double> = -90...300

    /// Seconds the selection animations take.
    static let slide: TimeInterval = 0.85
    static let pageBlockOut: TimeInterval = 0.25
    static let pageBlockIn: TimeInterval = 0.30
    static let labelOut: TimeInterval = 0.2
    static let labelIn: TimeInterval = 0.3
    static let labelInDelay: TimeInterval = 0.2

    /// The beat that reveals token `index` of "Pick your [cover].".
    static func beat(forTokenAt index: Int, in tokens: [HeadlineMarkup.Token]) -> Beat {
        if case .highlight = tokens[index].kind { return .cover }
        if !tokens[index].spaceBefore, index > 0, case .highlight = tokens[index - 1].kind { return .stop }
        return .firstLine
    }
}
