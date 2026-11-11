import SwiftUI
import Observation

/// Plays the Interests entrance: reveals each beat of the timeline on schedule, or all at once.
@MainActor
@Observable
final class InterestsEntrance {
    private(set) var shown: Set<InterestsTimeline.Beat> = []
    private(set) var isInstant = false

    let timeline = InterestsTimeline.standard

    func has(_ beat: InterestsTimeline.Beat) -> Bool { shown.contains(beat) }

    /// `fade` is the length of the single cross-fade used when `animated` is false.
    func play(animated: Bool, fade: TimeInterval) async {
        let cells = Interest.allCases.count
        guard animated else {
            isInstant = true
            withAnimation(.easeInOut(duration: fade)) { shown = Set(timeline.beats(cells: cells)) }
            return
        }
        let clock = ContinuousClock()
        let start = clock.now
        for step in timeline.schedule(cells: cells) {
            try? await clock.sleep(until: start + .seconds(step.time))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: InterestsTimeline.entranceDuration)) { _ = shown.insert(step.beat) }
        }
    }
}
