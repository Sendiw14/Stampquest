import SwiftUI
import Observation

/// Plays a `WelcomeIntroTimeline`: reveals the beats and fires the haptic cues on schedule, jumps to the rest state on
/// request, and marks when the idle motion may begin.
@MainActor
@Observable
final class WelcomeIntroPlayer {
    private(set) var shown: Set<WelcomeIntroTimeline.Beat> = []
    /// True when beats appear without their entrance animation (Reduce Motion, a revisit, a skipped intro).
    private(set) var instant = false
    private(set) var isPlaying = false
    /// When the intro finished or was skipped; nil until then.
    private(set) var idleSince: Date?

    let timeline: WelcomeIntroTimeline

    init(timeline: WelcomeIntroTimeline = .standard) { self.timeline = timeline }

    /// Plays the whole intro, or shows the rest state at once when `animated` is false.
    func play(animated: Bool, haptics: WelcomeHaptics) async {
        guard animated else {
            instant = true
            shown = timeline.restState
            idleSince = .now
            return
        }
        isPlaying = true
        defer { isPlaying = false }
        let clock = ContinuousClock()
        let start = clock.now
        for entry in timeline.schedule {
            try? await clock.sleep(until: start + .seconds(entry.time))
            guard !Task.isCancelled, isPlaying else { return }
            switch entry.action {
            case .reveal(let beat): withAnimation(WelcomeIntroTimeline.animation(for: beat)) { _ = shown.insert(beat) }
            case .haptic(let haptic): haptics.play(haptic)
            }
        }
        try? await clock.sleep(until: start + .seconds(timeline.settleTime))
        guard !Task.isCancelled, isPlaying else { return }
        idleSince = .now
    }

    /// Jumps to the rest state in a quarter of a second.
    func skip() {
        guard isPlaying else { return }
        isPlaying = false
        instant = true
        withAnimation(.smooth(duration: WelcomeIntroTimeline.skipDuration)) { shown = timeline.restState }
        idleSince = .now
    }
}
