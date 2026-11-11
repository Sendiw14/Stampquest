import CoreGraphics
import Observation

/// Device tilt for the Welcome parallax: Core Motion at 30 Hz through the shared provider, or a drag gesture where
/// the device has no motion sensor (the Simulator).
@MainActor
@Observable
final class TiltParallax {
    private(set) var tilt = ParallaxTilt.zero
    private(set) var usesDragFallback = true
    private var provider: ParallaxMotionProviding?

    /// Points of drag that count as a full tilt.
    private static let dragRange = 90.0
    static let updateRate = 30.0

    func start(_ provider: ParallaxMotionProviding) {
        self.provider = provider
        usesDragFallback = !provider.isAvailable
        guard provider.isAvailable else { return }
        provider.start(hz: Self.updateRate) { [weak self] in self?.tilt = $0 }
    }

    func stop() {
        provider?.stop()
        tilt = .zero
    }

    func drag(_ translation: CGSize) {
        tilt = ParallaxTilt(x: ParallaxMapping.clamp(translation.width / Self.dragRange),
                            y: ParallaxMapping.clamp(translation.height / Self.dragRange))
    }

    func release() { tilt = .zero }

    /// Offset in points of a layer that moves at most `limit` points either way.
    nonisolated static func offset(_ axis: Double, limit: CGFloat) -> CGFloat { CGFloat(axis) * limit }
}
