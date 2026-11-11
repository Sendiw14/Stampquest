import SwiftUI

nonisolated enum OBRadius {
    static let stampPanel: CGFloat = 1.5
}

extension EnvironmentValues {
    /// True when motion must be removed: the system Reduce Motion setting or the app's own override.
    /// The flow root sets this; components never read the system value directly.
    @Entry var obReducesMotion = false
    /// False when the person turned haptics off in Settings.
    @Entry var obHapticsEnabled = true
}

extension View {
    /// Stamp drop shadow (spec 4.2). SwiftUI radius is about half the CSS blur.
    /// `flying` is the First stamp flight shadow; `lift` 0...1 blends the resting shadow toward the long soft
    /// shadow a stamp has just before it lands (Welcome intro).
    func obStampShadow(flying: Bool = false, landed: Bool = false, lift: CGFloat = 0) -> some View {
        modifier(OBStampShadow(flying: flying, landed: landed, lift: lift))
    }
}

private struct OBStampShadow: ViewModifier {
    let flying: Bool
    let landed: Bool
    let lift: CGFloat
    @Environment(\.colorScheme) private var scheme

    private func mix(_ rest: CGFloat, _ lifted: CGFloat) -> CGFloat { rest + (lifted - rest) * lift }

    func body(content: Content) -> some View {
        if flying {
            content
                .shadow(color: scheme == .dark ? .black.opacity(0.50) : OBColor.ink.opacity(0.30), radius: 1.5, y: 2)
                .shadow(color: scheme == .dark ? .black.opacity(0.40) : OBColor.ink.opacity(0.20), radius: 11, y: 22)
        } else if landed {
            content
                .shadow(color: scheme == .dark ? .black.opacity(0.40) : OBColor.ink.opacity(0.30), radius: 0.5, y: 1)
                .shadow(color: scheme == .dark ? .black.opacity(0.25) : OBColor.ink.opacity(0.14), radius: 2.5, y: 3)
        } else if scheme == .dark {
            content
                .shadow(color: .black.opacity(mix(0.55, 0.22)), radius: mix(0.75, 12), y: mix(1, 20))
                .shadow(color: .black.opacity(mix(0.32, 0.12)), radius: mix(7, 17), y: mix(8, 30))
        } else {
            content
                .shadow(color: OBColor.ink.opacity(mix(0.30, 0.22)), radius: mix(0.75, 12), y: mix(1, 20))
                .shadow(color: OBColor.ink.opacity(mix(0.13, 0.12)), radius: mix(7, 17), y: mix(9, 30))
        }
    }
}
