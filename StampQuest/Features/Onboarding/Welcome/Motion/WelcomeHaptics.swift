import CoreGraphics

/// Plays the haptic cues of the Welcome intro. Silent when `isEnabled` is false (Reduce Motion).
struct WelcomeHaptics {
    let service: HapticsService
    let isEnabled: Bool

    func play(_ haptic: WelcomeIntroTimeline.Haptic) {
        guard isEnabled else { return }
        switch haptic {
        case .frameContact: service.lightImpact()
        case .heroLanding: service.mediumImpact()
        case .postmarkPress: service.rigidImpact(intensity: 1)
        }
    }
}
