import SwiftUI

/// The parts of the exit sheet that arrive on a schedule.
nonisolated enum ExitBeat: Hashable, Sendable {
    case start, upgrade, word, comma, subtitle, card
    case check(Int), row(Int)
    case label, packCard, packTitle, blurb, stackLeft, stackRight, stackFront, pill, cta, link
}

/// Delays in seconds after the sheet appears. `timeScale` multiplies every one (tests and previews set it to 0 to skip the entrance).
enum ExitSheetMotion {
    static var timeScale = 1.0

    static func delay(of beat: ExitBeat) -> TimeInterval {
        let seconds: TimeInterval = switch beat {
        case .start: 0.45
        case .upgrade: 0.61
        case .word: 0.73
        case .comma, .subtitle: 1.00
        case .card: 1.20
        case .check(let index): 1.42 + 0.24 * Double(index)
        case .row(let index): 1.46 + 0.24 * Double(index)
        case .label: 2.25
        case .packCard: 2.37
        case .packTitle: 2.49
        case .blurb: 2.57
        case .stackLeft: 2.55
        case .stackRight: 2.61
        case .stackFront, .pill: 2.67
        case .cta: 2.87
        case .link: 3.01
        }
        return seconds * timeScale
    }

    static let beats: [ExitBeat] = [.start, .upgrade, .word, .comma, .subtitle, .card, .label, .packCard, .packTitle, .blurb, .stackLeft,
                                    .stackRight, .stackFront, .pill, .cta, .link]
        + (0..<3).flatMap { [ExitBeat.check($0), .row($0)] }

    static func makePlayer() -> BeatPlayer<ExitBeat> {
        BeatPlayer(schedule: beats.map { (delay(of: $0), $0) })
    }
}

/// How a part arrives: all of them are opacity plus transform only. Reduce Motion drops the transform and fades.
struct ExitBeatModifier: ViewModifier {
    enum Style {
        case fadeUp(duration: Double = 0.6)
        case popIn
        case slide(x: CGFloat, y: CGFloat, scale: CGFloat, duration: Double)
    }

    let player: BeatPlayer<ExitBeat>
    let beat: ExitBeat
    var style = Style.fadeUp()
    let reduceMotion: Bool

    private static let ease = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.6)

    func body(content: Content) -> some View {
        let shown = player.has(beat) || reduceMotion && player.isInstant
        switch style {
        case .fadeUp(let duration):
            content.opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 16)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .timingCurve(0.2, 0.8, 0.2, 1, duration: duration), value: shown)
        case .popIn:
            content.opacity(shown ? 1 : 0)
                .scaleEffect(shown || reduceMotion ? 1 : 0.3)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .timingCurve(0.3, 1.25, 0.4, 1, duration: 0.45), value: shown)
        case .slide(let x, let y, let scale, let duration):
            content.opacity(shown ? 1 : 0)
                .offset(x: shown || reduceMotion ? 0 : x, y: shown || reduceMotion ? 0 : y)
                .scaleEffect(shown || reduceMotion ? 1 : scale)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .timingCurve(0.2, 0.8, 0.2, 1, duration: duration), value: shown)
        }
    }
}

extension View {
    func exitBeat(_ beat: ExitBeat, _ player: BeatPlayer<ExitBeat>, style: ExitBeatModifier.Style = .fadeUp(), reduceMotion: Bool) -> some View {
        modifier(ExitBeatModifier(player: player, beat: beat, style: style, reduceMotion: reduceMotion))
    }
}
