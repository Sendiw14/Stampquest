import Foundation

/// Every duration and delay of the Welcome intro and its idle motion, in seconds. Pure: the view only plays it.
nonisolated struct WelcomeIntroTimeline: Sendable {
    enum Beat: Int, CaseIterable, Hashable, Sendable {
        case topRow, progress, your, one, world, comma, stampWord, atATime
        case rome, newYork, santorini, kyoto, paris
        case postmark, waves, subtitle, cta, finePrint
    }

    enum Haptic: Hashable, Sendable {
        /// A stamp-word frame lands.
        case frameContact
        /// The hero stamp lands.
        case heroLanding
        /// The postmark presses.
        case postmarkPress
    }

    enum Action: Hashable, Sendable {
        case reveal(Beat)
        case haptic(Haptic)
    }

    struct Entry: Equatable, Sendable {
        let time: TimeInterval
        let action: Action
    }

    let delays: [Beat: TimeInterval]

    static let standard = WelcomeIntroTimeline(delays: [
        .topRow: 0.05, .progress: 0.40, .your: 0.30, .one: 0.50, .world: 0.62, .comma: 0.80, .stampWord: 0.98,
        .atATime: 1.20, .rome: 1.30, .newYork: 1.38, .santorini: 1.46, .kyoto: 1.54, .paris: 1.66,
        .postmark: 2.42, .waves: 2.55, .subtitle: 2.60, .cta: 2.76, .finePrint: 2.92,
    ])

    /// Seconds an animation of `beat` takes once it starts.
    func duration(of beat: Beat) -> TimeInterval {
        switch beat {
        case .topRow: 0.62
        case .world, .stampWord: 0.64
        case .rome, .newYork, .santorini, .kyoto, .paris: 0.82
        case .postmark: 0.56
        case .waves: 0.55
        default: 0.5
        }
    }

    /// Delay of the dot at `index` inside the progress strip after `.progress` starts.
    static let progressDotStagger: TimeInterval = 0.07

    /// Moments after a beat starts at which it touches down (haptic cues).
    private static let contacts: [(Beat, Haptic, TimeInterval)] = [
        (.world, .frameContact, 0.32), (.stampWord, .frameContact, 0.32), (.paris, .heroLanding, 0.22),
        (.postmark, .postmarkPress, 0.26),
    ]

    /// Every action in playing order.
    var schedule: [Entry] {
        let reveals = Beat.allCases.map { Entry(time: delays[$0] ?? 0, action: .reveal($0)) }
        let cues = Self.contacts.map { Entry(time: (delays[$0.0] ?? 0) + $0.2, action: .haptic($0.1)) }
        return (reveals + cues).sorted { $0.time < $1.time }
    }

    /// Start of the last beat: the whole intro is on its way by then.
    var total: TimeInterval { delays.values.max() ?? 0 }
    /// When the last animation has finished.
    var settleTime: TimeInterval { Beat.allCases.map { (delays[$0] ?? 0) + duration(of: $0) }.max() ?? 0 }

    /// Beats that have started `time` seconds into the intro.
    func shown(at time: TimeInterval) -> Set<Beat> { Set(Beat.allCases.filter { (delays[$0] ?? 0) <= time }) }

    /// The state after tapping to skip, and the state Reduce Motion shows at once.
    var restState: Set<Beat> { Set(Beat.allCases) }

    /// Seconds a jump to the rest state takes.
    static let skipDuration: TimeInterval = 0.25
    static let reducedMotionFade: TimeInterval = 0.3

    // MARK: Idle

    enum Idle {
        static let floatAmplitude = 4.0
        static let floatPeriod = 5.4
        static let sweepInterval = 6.0
        static let sweepDuration = 1.2
        static let twinkleMin = 0.25
        static let twinklePeriod = 2.8

        /// Vertical float of a stamp `time` seconds into the idle phase. Eases in over the first second so it never jumps.
        static func floatOffset(at time: TimeInterval, order: Int) -> Double {
            let ramp = min(1, max(0, time))
            let phase = Double(order) * 0.9
            return floatAmplitude * ramp * ramp * (3 - 2 * ramp) * sin(2 * .pi * time / floatPeriod + phase)
        }

        /// 0.25...1, one full cycle every `twinklePeriod`.
        static func twinkle(at time: TimeInterval, order: Int) -> Double {
            let wave = (sin(2 * .pi * time / twinklePeriod + Double(order) * 1.7) + 1) / 2
            return twinkleMin + (1 - twinkleMin) * wave
        }

        /// Progress of the foil sweep, 0...1 while it travels and -1 while it rests.
        static func sweepProgress(at time: TimeInterval) -> Double {
            let t = time.truncatingRemainder(dividingBy: sweepInterval)
            return t < sweepDuration ? t / sweepDuration : -1
        }
    }
}
