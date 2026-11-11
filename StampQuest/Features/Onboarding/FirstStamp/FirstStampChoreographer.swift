import SwiftUI
import Observation

/// Plays the First stamp entrance and the reveal that follows a saved stamp, and jumps to the final state on request.
/// The reveal only starts when the view model says the stamp is saved; interrupting it never plays anything twice.
@MainActor
@Observable
final class FirstStampChoreographer {
    private(set) var entrance: Set<FirstStampEntrance.Beat> = []
    private(set) var reveal: Set<RevealChoreography.Beat> = []
    /// True when beats appear without their entrance animation (Reduce Motion, a restored screen, a skipped reveal).
    private(set) var isInstant = false
    private(set) var entranceStart = Date.now
    /// Counts flights and contacts so keyframe effects know when to play.
    private(set) var flightTrigger = 0
    private(set) var contactCount = 0

    private let revealTimeline = RevealChoreography.standard
    private let entranceTimeline = FirstStampEntrance.standard
    private var revealTask: Task<Void, Never>?

    func has(_ beat: FirstStampEntrance.Beat) -> Bool { entrance.contains(beat) }
    func has(_ beat: RevealChoreography.Beat) -> Bool { reveal.contains(beat) }

    // MARK: Entrance

    /// `fade` is the length of the single cross-fade used when `animated` is false.
    func playEntrance(animated: Bool, fade: TimeInterval) async {
        guard animated else {
            withAnimation(.easeInOut(duration: fade)) { entrance = Set(entranceTimeline.beats) }
            return
        }
        entranceStart = .now
        let clock = ContinuousClock()
        let start = clock.now
        for step in entranceTimeline.schedule {
            try? await clock.sleep(until: start + .seconds(step.time))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: FirstStampEntrance.duration)) { _ = entrance.insert(step.beat) }
        }
    }

    // MARK: Reveal

    /// Starts the reveal for a stamp that was just saved. `onContact` fires when the stamp touches the page.
    func startReveal(animated: Bool, fade: TimeInterval, onContact: @escaping () -> Void, onFinished: @escaping () -> Void) {
        revealTask?.cancel()
        guard animated else {
            isInstant = true
            withAnimation(.easeInOut(duration: fade)) { reveal = Set(revealTimeline.beats) }
            onContact()
            onFinished()
            return
        }
        isInstant = false
        flightTrigger += 1
        revealTask = Task {
            let clock = ContinuousClock()
            let start = clock.now
            for step in revealTimeline.schedule {
                try? await clock.sleep(until: start + .seconds(step.time))
                guard !Task.isCancelled else { return }
                if step.beat == .contact { contactCount += 1; onContact() }
                withAnimation(Self.animation(for: step.beat)) { _ = reveal.insert(step.beat) }
            }
            try? await clock.sleep(until: start + .seconds(revealTimeline.total))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }

    /// Jumps to the final state: cancels the pending work and shows everything in a quick cross-fade.
    func snapReveal() {
        revealTask?.cancel()
        isInstant = true
        withAnimation(.easeInOut(duration: RevealChoreography.skipFade)) { reveal = Set(revealTimeline.beats) }
    }

    private static func animation(for beat: RevealChoreography.Beat) -> Animation {
        switch beat {
        case .ringOut: .easeOut(duration: 0.2)
        case .recede: .easeOut(duration: 0.35)
        case .pillsDim: .easeOut(duration: 0.3)
        case .ghostSlot: .easeOut(duration: RevealChoreography.ghostFade)
        case .textOut: .easeIn(duration: RevealChoreography.textOutDuration)
        case .textIn: .easeOut(duration: RevealChoreography.textInDuration)
        case .contact: .easeOut(duration: 0.7)
        case .postmark, .sheen: .easeOut(duration: 0.2)
        case .ctaEnabled: .easeInOut(duration: RevealChoreography.ctaFade)
        }
    }
}
