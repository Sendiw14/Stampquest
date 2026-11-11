import Foundation

/// Collects a stamp during onboarding. Success is reported only after the passport saved it, so the reveal
/// and the progress that follows can never get ahead of the data.
@MainActor
protocol StampCollecting {
    /// Throws if the save failed; nothing is collected in that case.
    func collect(_ destination: StampDestination) async throws -> UserStamp
    /// The stamp already in the passport for this destination, if any (never re-collect on relaunch).
    func existing(_ destination: StampDestination) -> UserStamp?
}

@MainActor
struct CollectStampUseCase: StampCollecting {
    let store: PassportStore

    func collect(_ destination: StampDestination) async throws -> UserStamp {
        try store.collect(destinationID: destination.id).stamp
    }

    func existing(_ destination: StampDestination) -> UserStamp? {
        store.stamp(forDestination: destination.id)
    }
}
