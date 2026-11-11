import SwiftUI

/// Motion tokens. See `docs/MOTION.md` for the full specification of each
/// signature interaction (purpose, duration range, easing, reduced-motion form).
enum SQMotion {
    /// Frequent, small state changes (toggles, selection).
    static let quick = Animation.easeOut(duration: 0.18)
    /// Standard transitions (filters, progress).
    static let standard = Animation.easeInOut(duration: 0.28)
    /// Considered, larger moves (hero transitions).
    static let considered = Animation.easeInOut(duration: 0.42)
    /// Gentle physical settle used by the stamp landing.
    static let settle = Animation.spring(response: 0.5, dampingFraction: 0.82)

    /// Reveal choreography, in seconds from presentation.
    enum Reveal {
        static let recede: Double = 0.0
        static let outline: Double = 0.12
        static let stampIn: Double = 0.30
        static let inkIn: Double = 0.78
        static let titleIn: Double = 0.95
        static let confirmIn: Double = 1.20
        /// Reduced-motion reveal is a single crossfade.
        static let reduced: Double = 0.25
    }
}

extension Animation {
    /// Returns `nil` (no animation) when the user prefers reduced motion.
    func respecting(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}

extension View {
    /// Wraps `withAnimation`-style value animation so Reduce Motion degrades to a
    /// simple fade rather than movement.
    func sqAnimation<V: Equatable>(_ animation: Animation = SQMotion.standard,
                                   value: V,
                                   reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? .easeInOut(duration: 0.12) : animation, value: value)
    }
}
