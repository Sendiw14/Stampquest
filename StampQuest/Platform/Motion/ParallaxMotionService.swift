import Foundation
import CoreMotion

/// Device tilt, each axis normalised to -1...1.
nonisolated struct ParallaxTilt: Equatable, Sendable {
    var x: Double
    var y: Double
    static let zero = ParallaxTilt(x: 0, y: 0)
}

nonisolated enum ParallaxMapping {
    /// Radians of roll or pitch that map to the full -1...1 range.
    static let fullRange = 0.35

    /// Roll drives x and pitch drives y. Values beyond the full range clamp to plus or minus 1.
    static func tilt(roll: Double, pitch: Double) -> ParallaxTilt {
        ParallaxTilt(x: clamp(roll / fullRange), y: clamp(pitch / fullRange))
    }

    static func clamp(_ value: Double) -> Double { min(1, max(-1, value)) }
}

/// Exponential low-pass filter so sensor noise does not jitter the stamps.
nonisolated struct LowPassFilter: Sendable {
    var alpha = 0.12
    private(set) var value = ParallaxTilt.zero

    mutating func filter(_ input: ParallaxTilt) -> ParallaxTilt {
        value = ParallaxTilt(x: value.x + alpha * (input.x - value.x), y: value.y + alpha * (input.y - value.y))
        return value
    }
}

@MainActor
protocol ParallaxMotionProviding: AnyObject {
    /// False in the Simulator and on devices without a motion sensor: callers fall back to a drag gesture.
    var isAvailable: Bool { get }
    func start(hz: Double, _ onUpdate: @escaping @MainActor (ParallaxTilt) -> Void)
    func stop()
}

extension ParallaxMotionProviding {
    func start(_ onUpdate: @escaping @MainActor (ParallaxTilt) -> Void) { start(hz: 60, onUpdate) }
}

/// Core Motion device motion, only while started.
@MainActor
final class CoreMotionParallaxService: ParallaxMotionProviding {
    private let manager = CMMotionManager()
    private var filter = LowPassFilter()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start(hz: Double, _ onUpdate: @escaping @MainActor (ParallaxTilt) -> Void) {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        filter = LowPassFilter()
        manager.deviceMotionUpdateInterval = 1.0 / hz
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll, pitch = motion.attitude.pitch
            MainActor.assumeIsolated {
                guard let self else { return }
                onUpdate(self.filter.filter(ParallaxMapping.tilt(roll: roll, pitch: pitch)))
            }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}

/// Deterministic stand-in for previews and tests.
@MainActor
final class MockParallaxService: ParallaxMotionProviding {
    var isAvailable: Bool
    private(set) var isRunning = false
    private var handler: (@MainActor (ParallaxTilt) -> Void)?

    init(isAvailable: Bool = true) { self.isAvailable = isAvailable }

    func start(hz: Double, _ onUpdate: @escaping @MainActor (ParallaxTilt) -> Void) { handler = onUpdate; isRunning = true }
    func stop() { handler = nil; isRunning = false }
    func send(_ tilt: ParallaxTilt) { handler?(tilt) }
}
