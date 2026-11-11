import Foundation

/// Delays and durations of the Interests entrance and of a pick, in seconds. Pure: the screen only plays it.
nonisolated struct InterestsTimeline: Sendable {
    enum Beat: Hashable, Sendable {
        case back, skip, progress, progressDots, firstLine, secondLine, find, questionMark, subtitle, page
        case cell(Int), label(Int)
        case counter, cta
    }

    static let standard = InterestsTimeline()

    static let progressDotsStart: TimeInterval = 0.40
    static let entranceDuration: TimeInterval = 0.62

    func delay(of beat: Beat) -> TimeInterval {
        switch beat {
        case .back: 0.05
        case .skip: 0.08
        case .progress: 0.10
        case .progressDots: Self.progressDotsStart
        case .firstLine: 0.20
        case .secondLine: 0.36
        case .find: 0.62
        case .questionMark: 0.95
        case .subtitle: 1.00
        case .page: 0.55
        case .cell(let index): 0.95 + 0.09 * Double(index)
        case .label(let index): 0.95 + 0.09 * Double(index) + 0.10
        case .counter: 1.30
        case .cta: 1.50
        }
    }

    /// Every beat of a screen with `cells` interests.
    func beats(cells: Int) -> [Beat] {
        [.back, .skip, .progress, .progressDots, .firstLine, .secondLine, .find, .questionMark, .subtitle, .page, .counter, .cta]
            + (0..<cells).flatMap { [Beat.cell($0), .label($0)] }
    }

    /// Beats in playing order.
    func schedule(cells: Int) -> [(time: TimeInterval, beat: Beat)] {
        beats(cells: cells).map { (delay(of: $0), $0) }.sorted { $0.0 < $1.0 }
    }

    /// When the last entrance animation has finished.
    var settleTime: TimeInterval { delay(of: .cta) + Self.entranceDuration }

    /// The beat that reveals token `index` of the headline: the line it is on (the string breaks lines with a
    /// newline), the stamp word, or the punctuation that follows it.
    static func beat(forTokenAt index: Int, in tokens: [HeadlineMarkup.Token]) -> Beat {
        let token = tokens[index]
        if case .highlight = token.kind { return .find }
        if !token.spaceBefore && index > 0, case .highlight = tokens[index - 1].kind { return .questionMark }
        guard let secondLineStart = tokens.firstIndex(where: \.lineBreakBefore) else { return .firstLine }
        return index >= secondLineStart ? .secondLine : .firstLine
    }

    // MARK: Pick

    enum Pick {
        static let ghostFade: TimeInterval = 0.20
        static let land: TimeInterval = 0.62
        static let rippleDelay: TimeInterval = 0.12
        static let rippleDuration: TimeInterval = 0.6
        static let badgeDelay: TimeInterval = 0.20
        static let badgeDuration: TimeInterval = 0.64
        static let postmarkDelay: TimeInterval = 0.30
        static let postmarkDuration: TimeInterval = 0.52
        static let sheenDelay: TimeInterval = 0.45
        static let sheenDuration: TimeInterval = 0.85
        /// Moment the stamp touches the page, for the heavy thud.
        static let thudDelay: TimeInterval = 0.32
        static let unpickLift: TimeInterval = 0.34
        static let unpickBadge: TimeInterval = 0.20
        static let ghostReturn: TimeInterval = 0.30
        static let reducedFade: TimeInterval = 0.15
        static let announceDebounce: TimeInterval = 0.4
    }
}
