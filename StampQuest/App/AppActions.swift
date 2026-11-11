import Foundation
import SwiftUI

extension AppEnvironment {
    /// Collects a stamp. The reveal and the success haptic happen **only** after the
    /// record has been saved; on failure nothing is shown as collected.
    ///
    /// - Returns: nil on success (including "already collected"), or the error to show.
    @discardableResult
    func collect(_ destinationID: String) -> PassportError? {
        do {
            let outcome = try store.collect(destinationID: destinationID)
            if outcome.isNew { presentReveal(for: outcome.stamp) }
            return nil
        } catch let error as PassportError {
            return error
        } catch {
            return .saveFailed
        }
    }

    /// What the reveal needs for a stamp that was just saved, including a collection that this stamp completed.
    func revealPayload(for stamp: UserStamp) -> RevealPayload {
        let snapshot = store.snapshot()
        let completed = catalog.collections(containing: stamp.destinationID)
            .filter { CollectionProgress.make(for: $0, snapshot: snapshot).isComplete }
            .last
        return RevealPayload(destinationID: stamp.destinationID, isVerified: stamp.isVerified,
                             collectedAt: stamp.collectedAt, completedCollectionID: completed?.id)
    }

    /// Shows the reveal over whatever is on screen (the entry point for Discover, Map and Destination detail). It cross-fades in
    /// and out; Stamp detail shows the same view in place and morphs instead.
    func presentReveal(for stamp: UserStamp) {
        let payload = revealPayload(for: stamp)
        // The reveal choreographs its own entrance, so the system cover animation is suppressed.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { router.presentReveal(payload) }
    }

    /// Runs the optional location verification for a destination. The caller decides when to
    /// present the reveal (a sheet must be dismissed first).
    func verify(_ destination: Destination) async -> VerificationAttempt {
        await verification.verify(destination: destination, store: store,
                                  featureEnabled: preferences.locationVerificationEnabled)
    }

    /// Opens the system Settings page for this app (for location permission recovery).
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
