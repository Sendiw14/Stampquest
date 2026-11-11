import Foundation

/// Delays of the "passport ready" entrance and its auto-open, in seconds from the moment the screen appears. Pure.
nonisolated struct ReadyTimeline: Sendable {
    enum Beat: Hashable, Sendable {
        case back, progress, firstLine, isWord, ready, stop, subtitle, cover, caption, cta
        /// The cover starts to swing open.
        case open
        case emblem, holderLabel, name, issued, count
        case slot(Int)
        case footer, stamp, postmark
        case icon(Int), label(Int)
    }

    static let standard = ReadyTimeline()
    /// When the cover opens by itself.
    static let openTime: TimeInterval = 2.35
    static let slotCount = 6
    static let summaryCount = 3

    func delay(of beat: Beat) -> TimeInterval {
        let open = Self.openTime
        switch beat {
        case .back: return 0.05
        case .progress: return 0.10
        case .firstLine: return 0.20
        case .isWord: return 0.40
        case .ready: return 0.62
        case .stop: return 0.95
        case .subtitle: return 1.00
        case .cover: return 1.05
        case .caption: return 2.00
        case .cta: return 2.40
        case .open: return open
        case .emblem: return open + 0.55
        case .holderLabel: return open + 0.60
        case .name: return open + 0.66
        case .issued: return open + 0.74
        case .count: return open + 0.80
        case .slot(let index): return open + 0.85 + 0.06 * Double(index)
        case .footer: return open + 1.20
        case .stamp: return open + 1.00
        case .postmark: return open + 1.40
        case .icon(let index): return open + 1.30 + 0.16 * Double(index)
        case .label(let index): return open + 1.30 + 0.16 * Double(index) + 0.06
        }
    }

    var beats: [Beat] {
        [.back, .progress, .firstLine, .isWord, .ready, .stop, .subtitle, .cover, .caption, .cta, .open, .emblem, .holderLabel, .name,
         .issued, .count, .footer, .stamp, .postmark]
            + (1..<Self.slotCount).map { Beat.slot($0) }
            + (0..<Self.summaryCount).flatMap { [Beat.icon($0), .label($0)] }
    }

    var schedule: [(time: TimeInterval, beat: Beat)] { beats.map { (delay(of: $0), $0) } }

    /// The stamp touches the page at the 52% point of its 0.70 s landing.
    static let stampContact: TimeInterval = 0.36

    /// The beat that reveals token `index` of "Your passport is [ready]."
    static func beat(forTokenAt index: Int, in tokens: [HeadlineMarkup.Token]) -> Beat {
        let token = tokens[index]
        if case .highlight = token.kind { return .ready }
        if !token.spaceBefore, index > 0, case .highlight = tokens[index - 1].kind { return .stop }
        let secondLineStart = tokens.firstIndex(where: \.lineBreakBefore) ?? tokens.count
        return index >= secondLineStart ? .isWord : .firstLine
    }
}
