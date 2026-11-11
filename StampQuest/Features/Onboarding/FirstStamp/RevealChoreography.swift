import Foundation

/// Delays and durations of the First stamp entrance and of the reveal that follows a saved stamp, in seconds. Pure.
nonisolated struct RevealChoreography: Sendable {
    enum Beat: Hashable, Sendable {
        /// The hot slot's pulse ring fades out.
        case ringOut
        /// The two stamps left on the desk recede.
        case recede
        case pillsDim
        /// The desk position the stamp left becomes an empty slot.
        case ghostSlot
        case textOut
        case textIn
        /// The stamp touches the page: success haptic, press, ripple, glow, bump.
        case contact
        case postmark
        case sheen
        case ctaEnabled
    }

    static let standard = RevealChoreography()

    func delay(of beat: Beat) -> TimeInterval {
        switch beat {
        case .ringOut: 0
        case .recede: 0.05
        case .pillsDim: 0.10
        case .ghostSlot: 0.40
        case .textOut: 0.88
        case .textIn: 1.04
        case .contact: 0.97
        case .postmark: 1.01
        case .sheen: 1.25
        case .ctaEnabled: 1.25
        }
    }

    static let flightDuration: TimeInterval = 1.15
    /// Fractions of the flight: the lift, the arc apex above slot 1, the contact and the end.
    static let liftFraction = 0.16, apexFraction = 0.62, contactFraction = 0.82
    static let ctaFade: TimeInterval = 0.45
    static let ghostFade: TimeInterval = 0.35
    static let textOutDuration: TimeInterval = 0.20
    static let textInDuration: TimeInterval = 0.30
    static let reducedFade: TimeInterval = 0.25
    static let skipFade: TimeInterval = 0.15
    static let pageBump: CGFloat = 2

    var beats: [Beat] { [.ringOut, .recede, .pillsDim, .ghostSlot, .textOut, .textIn, .contact, .postmark, .sheen, .ctaEnabled] }

    /// Beats in playing order.
    var schedule: [(time: TimeInterval, beat: Beat)] { beats.map { (delay(of: $0), $0) }.sorted { $0.time < $1.time } }

    /// When the CTA has finished enabling: the whole reveal is over.
    var total: TimeInterval { delay(of: .ctaEnabled) + 0.45 }

    /// Time of the flight's apex, contact and end.
    static var apexTime: TimeInterval { flightDuration * apexFraction }
    static var flightContactTime: TimeInterval { flightDuration * contactFraction }
}

/// Entrance of the screen, from the moment it appears.
nonisolated struct FirstStampEntrance: Sendable {
    enum Beat: Hashable, Sendable {
        case back, skip, progress, firstLine, firstWord, stampWord, subtitle, page
        case slot(Int), starter(Int), pill(Int)
        case note, cta
    }

    static let standard = FirstStampEntrance()
    static let slotCount = 6
    static let starterCount = 3
    static let progressDotsStart: TimeInterval = 0.40
    static let duration: TimeInterval = 0.62
    /// Kyoto and Santorini begin to float at these times.
    static let floatStarts: [TimeInterval] = [2.0, 2.4]

    func delay(of beat: Beat) -> TimeInterval {
        switch beat {
        case .back: 0.05
        case .skip: 0.08
        case .progress: Self.progressDotsStart
        case .firstLine: 0.20
        case .firstWord: 0.62
        case .stampWord: 0.80
        case .subtitle: 1.00
        case .page: 0.55
        case .slot(let index): 0.80 + 0.07 * Double(index)
        case .starter(let index): 1.10 + 0.10 * Double(index)
        case .pill(let index): 1.55 + 0.10 * Double(index)
        case .note: 1.70
        case .cta: 1.80
        }
    }

    var beats: [Beat] {
        [.back, .skip, .progress, .firstLine, .firstWord, .stampWord, .subtitle, .page, .note, .cta]
            + (0..<Self.slotCount).map { Beat.slot($0) } + (0..<Self.starterCount).flatMap { [Beat.starter($0), .pill($0)] }
    }

    var schedule: [(time: TimeInterval, beat: Beat)] { beats.map { (delay(of: $0), $0) }.sorted { $0.time < $1.time } }
}
