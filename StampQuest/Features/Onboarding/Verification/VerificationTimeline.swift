import Foundation

/// Delays of the Verification entrance, in seconds from the moment the screen appears. Pure.
nonisolated struct VerificationTimeline: Sendable {
    enum Beat: Hashable, Sendable {
        case back, skip, progress, firstLine, secondLine, yours, firstStop, earned, secondStop
        case subtitle, hero, control, caption, postmark
        case bullet(Int), cta, notNow
    }

    static let standard = VerificationTimeline()
    static let bulletCount = 3

    func delay(of beat: Beat) -> TimeInterval {
        switch beat {
        case .back: 0.05
        case .skip: 0.08
        case .progress: 0.10
        case .firstLine: 0.20
        case .secondLine: 0.40
        case .yours: 0.62
        case .firstStop: 0.95
        case .earned: 1.00
        case .secondStop: 1.30
        case .subtitle: 1.00
        case .hero: 1.05
        case .control: 1.60
        case .caption: 1.70
        case .postmark: 1.80
        case .bullet(let index): 2.00 + 0.10 * Double(index)
        case .cta: 2.30
        case .notNow: 2.45
        }
    }

    var beats: [Beat] {
        [.back, .skip, .progress, .firstLine, .secondLine, .yours, .firstStop, .earned, .secondStop, .subtitle, .hero, .control,
         .caption, .postmark, .cta, .notNow] + (0..<Self.bulletCount).map { Beat.bullet($0) }
    }

    var schedule: [(time: TimeInterval, beat: Beat)] { beats.map { (delay(of: $0), $0) } }

    /// The beat that reveals token `index` of the headline.
    static func beat(forTokenAt index: Int, in tokens: [HeadlineMarkup.Token]) -> Beat {
        let token = tokens[index]
        if case .highlight(let n) = token.kind { return n == 0 ? .yours : .earned }
        let secondLineStart = tokens.firstIndex(where: \.lineBreakBefore) ?? tokens.count
        let onSecondLine = index >= secondLineStart
        if !token.spaceBefore, index > 0, case .highlight = tokens[index - 1].kind { return onSecondLine ? .secondStop : .firstStop }
        return onSecondLine ? .secondLine : .firstLine
    }

    /// Caption swap: the old text leaves over 0.2 s, the new one arrives 0.1 s later over 0.3 s.
    static let captionOut: TimeInterval = 0.2
    static let captionSwapDelay: TimeInterval = 0.1
    static let captionIn: TimeInterval = 0.3
    /// The seal lands this long after the switch; the rigid haptic fires then.
    static let sealContact: TimeInterval = 0.50
    /// The postmark thumps again this long after switching back to Collected.
    static let postmarkReturnDelay: TimeInterval = 0.15
}
