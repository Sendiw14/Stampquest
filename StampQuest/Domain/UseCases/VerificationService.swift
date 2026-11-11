import Foundation
import Observation
import OSLog

/// The result of one verification attempt. A success exists only after the
/// reading passed the policy **and** the record was saved.
enum VerificationAttempt {
    case success(VerificationOutcome)
    case failure(VerificationFailure)
    case saveFailed
}

/// Runs the optional "verify my visit" flow end to end:
/// feature on? → services on? → permission → one reading → policy → save.
///
/// Nothing is persisted unless every step succeeds, and no success state is exposed
/// otherwise. The person's location is used once, in the foreground, and discarded.
@MainActor
@Observable
final class VerificationService {
    enum Phase: Equatable {
        case idle
        case requestingPermission
        case locating
    }

    private(set) var phase: Phase = .idle
    var isBusy: Bool { phase != .idle }

    private let provider: LocationProviding
    private let policy: VerificationPolicy
    private let now: () -> Date
    private let log = Logger(subsystem: "app.stampquest.ios", category: "verification")

    init(provider: LocationProviding, policy: VerificationPolicy = .standard, now: @escaping () -> Date = { .now }) {
        self.provider = provider
        self.policy = policy
        self.now = now
    }

    var authorization: LocationAuthorization { provider.authorization }

    func verify(destination: Destination, store: PassportStore, featureEnabled: Bool) async -> VerificationAttempt {
        guard phase == .idle else { return .failure(.cancelled) }
        defer { phase = .idle }
        guard featureEnabled else { return .failure(.featureDisabled) }
        guard await provider.servicesEnabled() else { return .failure(.servicesDisabled) }

        var status = provider.authorization
        if status == .notDetermined {
            phase = .requestingPermission
            status = await provider.requestAuthorization()
        }
        switch status {
        case .authorized: break
        case .denied: return .failure(.permissionDenied)
        case .restricted: return .failure(.permissionRestricted)
        case .notDetermined: return .failure(.unavailable)
        }

        phase = .locating
        let reading: LocationReading
        do {
            reading = try await provider.currentReading(timeout: .seconds(15))
        } catch let failure as VerificationFailure {
            return .failure(failure)
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch {
            return .failure(.unavailable)
        }

        switch policy.evaluate(reading, for: destination, now: now()) {
        case .failure(let failure):
            log.notice("Verification rejected")
            return .failure(failure)
        case .success(let verification):
            do {
                let outcome = try store.recordVerification(destinationID: destination.id, verification: verification)
                return .success(outcome)
            } catch {
                return .saveFailed
            }
        }
    }
}
