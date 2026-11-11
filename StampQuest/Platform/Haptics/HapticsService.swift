import UIKit
import CoreHaptics

/// Haptic feedback for meaningful events only. Every call honours the user's
/// preference, and success feedback must only be requested after the underlying
/// action has actually succeeded.
@MainActor
final class HapticsService {
    var isEnabled: Bool

    init(isEnabled: Bool = true) { self.isEnabled = isEnabled }

    /// A stamp was saved to the passport, or a verification succeeded.
    func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// A save failed.
    func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    func mediumImpact() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// A light tap for toggles such as the wishlist.
    func lightImpact() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// The Welcome postmark lands.
    func rigidImpact(intensity: CGFloat = 0.6) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: intensity)
    }

    /// A heavy thud, e.g. a stamp landing on a page.
    func heavyImpact(intensity: CGFloat = 0.6) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: intensity)
    }

    func softImpact(intensity: CGFloat = 0.5) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: intensity)
    }

    func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: Stamp thunk

    private var engine: CHHapticEngine?

    /// A stamp lands on a page: two transients (0.9, then 0.45 intensity, 60 ms apart) through Core Haptics,
    /// falling back to a medium impact when the device or engine cannot play them.
    func stampThunk() {
        guard isEnabled else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, playThunk() else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
    }

    private func playThunk() -> Bool {
        do {
            if engine == nil {
                let created = try CHHapticEngine()
                created.resetHandler = { [weak self] in Task { @MainActor in self?.engine = nil } }
                created.stoppedHandler = { [weak self] _ in Task { @MainActor in self?.engine = nil } }
                engine = created
            }
            guard let engine else { return false }
            try engine.start()
            let events = [(0.0, Float(0.9)), (0.06, Float(0.45))].map { time, intensity in
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                           CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)],
                              relativeTime: time)
            }
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            engine = nil
            return false
        }
    }
}
