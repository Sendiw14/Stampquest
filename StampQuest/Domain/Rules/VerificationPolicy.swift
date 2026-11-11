import Foundation

/// A single position fix. Only used transiently to decide a verification; the
/// coordinates are never persisted.
nonisolated struct LocationReading: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    /// Radius of uncertainty in metres. Negative means the fix is invalid.
    var horizontalAccuracy: Double
    var timestamp: Date
}

nonisolated enum LocationAuthorization: Equatable, Sendable {
    case notDetermined, denied, restricted, authorized
}

/// Every way a verification can fail. None of them is ever presented as success.
nonisolated enum VerificationFailure: Error, Equatable, Sendable {
    case featureDisabled
    case servicesDisabled
    case permissionDenied
    case permissionRestricted
    case timeout
    case staleReading
    case invalidReading
    case poorAccuracy(Double)
    case tooFar(distance: Double, radius: Double)
    case missingDestinationCoordinates
    case cancelled
    case unavailable

    var title: String {
        switch self {
        case .featureDisabled: String(localized: "Location verification is off")
        case .servicesDisabled: String(localized: "Location Services are off")
        case .permissionDenied: String(localized: "Location access is off for StampQuest")
        case .permissionRestricted: String(localized: "Location access is restricted")
        case .timeout: String(localized: "Couldn’t get your location")
        case .staleReading, .invalidReading: String(localized: "That location reading wasn’t usable")
        case .poorAccuracy: String(localized: "Your location isn’t precise enough")
        case .tooFar: String(localized: "You don’t seem to be there yet")
        case .missingDestinationCoordinates: String(localized: "This place can’t be verified")
        case .cancelled: String(localized: "Verification cancelled")
        case .unavailable: String(localized: "Location is unavailable")
        }
    }

    /// Honest explanation plus the next thing the person can do.
    var message: String {
        switch self {
        case .featureDisabled:
            String(localized: "You can turn it back on in Settings. You can still collect this stamp without verifying.")
        case .servicesDisabled:
            String(localized: "Turn on Location Services in the Settings app to verify visits. You can still collect this stamp without verifying.")
        case .permissionDenied:
            String(localized: "You can allow location access in the Settings app. You can still collect this stamp without verifying.")
        case .permissionRestricted:
            String(localized: "Location access is restricted on this device. You can still collect this stamp without verifying.")
        case .timeout:
            String(localized: "We couldn’t get a location fix in time. Try again outdoors, or collect this stamp without verifying.")
        case .staleReading, .invalidReading:
            String(localized: "Try again in a moment, or collect this stamp without verifying.")
        case .poorAccuracy(let metres):
            String(localized: "The reading is only accurate to about \(Int(metres.rounded())) m. Try again with a clearer view of the sky, or collect without verifying.")
        case .tooFar(let distance, let radius):
            String(localized: "You’re about \(Self.format(distance)) away, and verification needs you within \(Self.format(radius)). Nothing was recorded. You can still collect this stamp without verifying.")
        case .missingDestinationCoordinates:
            String(localized: "This destination has no reference location. You can still collect it without verifying.")
        case .cancelled:
            String(localized: "No location was used and nothing was recorded.")
        case .unavailable:
            String(localized: "Location isn’t available right now. You can still collect this stamp without verifying.")
        }
    }

    /// Whether sending the person to Settings can help.
    var suggestsSettings: Bool {
        switch self {
        case .servicesDisabled, .permissionDenied, .featureDisabled: true
        default: false
        }
    }

    private static func format(_ metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(metres >= 1000 ? 1 : 0))))
    }
}

/// Decides whether a location reading is good enough to call a visit "verified".
///
/// This is a convenience check, not proof: locations can be inaccurate or spoofed,
/// and the app says so. Policy:
/// - the reading must be valid and no more than 60 seconds old;
/// - horizontal accuracy must be 100 m or better;
/// - the reading must be within the destination's own radius (a monument and a
///   national park do not share one global distance).
nonisolated struct VerificationPolicy: Sendable {
    static let currentVersion = 1

    var maximumAge: TimeInterval = 60
    var maximumAccuracy: Double = 100

    static let standard = VerificationPolicy()

    func evaluate(_ reading: LocationReading, for destination: Destination, now: Date) -> Result<VisitVerification, VerificationFailure> {
        guard (-90...90).contains(destination.latitude), (-180...180).contains(destination.longitude),
              !(destination.latitude == 0 && destination.longitude == 0) else {
            return .failure(.missingDestinationCoordinates)
        }
        guard reading.horizontalAccuracy >= 0,
              (-90...90).contains(reading.latitude), (-180...180).contains(reading.longitude) else {
            return .failure(.invalidReading)
        }
        guard abs(now.timeIntervalSince(reading.timestamp)) <= maximumAge else { return .failure(.staleReading) }
        guard reading.horizontalAccuracy <= maximumAccuracy else { return .failure(.poorAccuracy(reading.horizontalAccuracy)) }

        let distance = Geo.distanceMeters(lat1: reading.latitude, lon1: reading.longitude,
                                          lat2: destination.latitude, lon2: destination.longitude)
        let radius = destination.verificationRadius
        guard distance <= radius else { return .failure(.tooFar(distance: distance, radius: radius)) }

        return .success(VisitVerification(id: UUID(), verifiedAt: now, distanceMeters: distance.rounded(),
                                          horizontalAccuracyMeters: reading.horizontalAccuracy.rounded(),
                                          radiusMeters: radius, policyVersion: Self.currentVersion))
    }
}

nonisolated enum Geo {
    /// Great-circle distance in metres (haversine).
    static func distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dp = (lat2 - lat1) * .pi / 180, dl = (lon2 - lon1) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }
}
