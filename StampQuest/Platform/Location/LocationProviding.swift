import Foundation
import CoreLocation

/// Abstraction over the device's location so verification can be tested
/// deterministically without a GPS fix.
@MainActor
protocol LocationProviding: AnyObject {
    /// Whether the system-wide Location Services switch is on.
    func servicesEnabled() async -> Bool
    var authorization: LocationAuthorization { get }
    /// Shows the system permission prompt if (and only if) the status is not determined.
    func requestAuthorization() async -> LocationAuthorization
    /// One foreground fix. Throws `VerificationFailure` (`.timeout`, `.cancelled`, `.unavailable`).
    func currentReading(timeout: Duration) async throws -> LocationReading
}

/// One-shot, foreground-only location via Core Location. Never starts continuous
/// updates, never uses background modes, and never requests "Always" access.
@MainActor
final class CoreLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<LocationAuthorization, Never>?
    private var readingContinuation: CheckedContinuation<LocationReading, Error>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.pausesLocationUpdatesAutomatically = true
    }

    var authorization: LocationAuthorization { Self.map(manager.authorizationStatus) }

    func servicesEnabled() async -> Bool { await Self.queryServicesEnabled() }

    /// `locationServicesEnabled()` can block, so it is checked off the main actor.
    @concurrent private static func queryServicesEnabled() async -> Bool { CLLocationManager.locationServicesEnabled() }

    func requestAuthorization() async -> LocationAuthorization {
        let current = authorization
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentReading(timeout: Duration) async throws -> LocationReading {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Only one request at a time; a second call cancels the first.
                finishReading(.failure(VerificationFailure.cancelled))
                readingContinuation = continuation
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    self?.finishReading(.failure(VerificationFailure.timeout))
                }
                manager.requestLocation()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finishReading(.failure(VerificationFailure.cancelled)) }
        }
    }

    /// Resumes the pending continuation exactly once.
    private func finishReading(_ result: Result<LocationReading, Error>) {
        guard let continuation = readingContinuation else { return }
        readingContinuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }

    // MARK: CLLocationManagerDelegate (delivered on the main thread)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.map(manager.authorizationStatus)
        MainActor.assumeIsolated {
            guard let continuation = authContinuation else { return }
            guard status != .notDetermined else { return }
            authContinuation = nil
            continuation.resume(returning: status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let reading = LocationReading(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                                      horizontalAccuracy: location.horizontalAccuracy, timestamp: location.timestamp)
        MainActor.assumeIsolated { finishReading(.success(reading)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failure: VerificationFailure
        if let clError = error as? CLError, clError.code == .denied { failure = .permissionDenied } else { failure = .unavailable }
        MainActor.assumeIsolated { finishReading(.failure(failure)) }
    }

    private nonisolated static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        @unknown default: .denied
        }
    }
}
