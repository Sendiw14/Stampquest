import SwiftUI
import Observation

/// Reveals the beats of an entrance on schedule, or all at once. Each beat flips from hidden to shown at its time.
@MainActor
@Observable
final class BeatPlayer<Beat: Hashable & Sendable> {
    private(set) var shown: Set<Beat> = []
    /// True when beats appear without their entrance animation (Reduce Motion, a revisit).
    private(set) var isInstant = false

    private let schedule: [(time: TimeInterval, beat: Beat)]
    private let animation: Animation

    init(schedule: [(time: TimeInterval, beat: Beat)],
         animation: Animation = .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.62)) {
        self.schedule = schedule.sorted { $0.time < $1.time }
        self.animation = animation
    }

    func has(_ beat: Beat) -> Bool { shown.contains(beat) }

    /// Marks every beat as shown with no animation: the finished state (previews, tests).
    func showAll() {
        isInstant = true
        shown = Set(schedule.map(\.beat))
    }

    /// Plays the schedule, or shows everything in one `fade`-second cross-fade when `animated` is false.
    func play(animated: Bool, fade: TimeInterval) async {
        guard animated else {
            isInstant = true
            withAnimation(.easeInOut(duration: fade)) { shown = Set(schedule.map(\.beat)) }
            return
        }
        let clock = ContinuousClock()
        let start = clock.now
        for step in schedule {
            try? await clock.sleep(until: start + .seconds(step.time))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { _ = shown.insert(step.beat) }
        }
    }
}
