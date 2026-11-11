import SwiftUI
import Observation

/// The three writes of Stamp detail: collect, wishlist and remove. Each is one transactional call on `PassportStore` (the
/// repository: it enforces one stamp per place, removes the wishlist entry when collecting, and rolls back a failed save). The
/// screen only changes after the write has persisted, and a success haptic, toast or reveal only ever follows a persisted write.
@MainActor
@Observable
final class StampDetailViewModel {
    enum Failure: Identifiable, Equatable {
        case collect, remove
        var id: Int { self == .collect ? 0 : 1 }
    }

    typealias Collector = @MainActor (String) throws -> CollectOutcome
    typealias Remover = @MainActor (String) throws -> StampBackup?

    let destinationID: String
    /// True while a write is in flight: both action pills are inert and the primary reads "Collecting".
    private(set) var isWorking = false
    var failure: Failure?
    /// Set after a collect has persisted; the screen shows the reveal in place.
    var reveal: RevealPayload?

    private let env: AppEnvironment
    private let collector: Collector
    private let remover: Remover
    private static var collectFailedOnce = false
    private static var removeFailedOnce = false

    init(env: AppEnvironment, destinationID: String, collector: Collector? = nil, remover: Remover? = nil) {
        self.env = env
        self.destinationID = destinationID
        self.collector = collector ?? { id in
            #if DEBUG
            if LaunchConfiguration.current.stampCollectFailsOnce, !StampDetailViewModel.collectFailedOnce {
                StampDetailViewModel.collectFailedOnce = true
                throw PassportError.saveFailed
            }
            #endif
            return try env.store.collect(destinationID: id)
        }
        self.remover = remover ?? { id in
            #if DEBUG
            if LaunchConfiguration.current.stampRemoveFailsOnce, !StampDetailViewModel.removeFailedOnce {
                StampDetailViewModel.removeFailedOnce = true
                throw PassportError.saveFailed
            }
            #endif
            return try env.store.removeStamp(destinationID: id)
        }
    }

    // MARK: Collect

    /// Collect stamp: validate, show "Collecting", persist in one transaction, and only then reveal. A stamp that is already in the
    /// passport (a stale screen, a double tap) resolves to success on the existing record: nothing is created and nothing replays.
    func collect() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        await Task.yield()
        do {
            let outcome = try collector(destinationID)
            guard outcome.isNew else { return }
            env.haptics.success()
            reveal = env.revealPayload(for: outcome.stamp)
        } catch {
            failure = .collect
        }
    }

    // MARK: Wishlist

    /// Wishlist / Saved. The state is read from the records, so a second tap can never double-save. A failure changes nothing.
    func toggleWishlist() {
        guard !isWorking else { return }
        do {
            switch env.store.state(of: destinationID) {
            case .wishlisted: try env.store.removeFromWishlist(destinationID: destinationID)
            case .notCollected: try env.store.addToWishlist(destinationID: destinationID)
            case .collected, .verified: return
            }
            env.haptics.selection()
        } catch {
            env.toasts.show(String(localized: "Couldn’t update your wishlist. Nothing changed."), icon: .warning, duration: .seconds(2.4))
        }
    }

    // MARK: Remove

    /// Removes the stamp (and its verification, which lives on the same record). Memories, trips and destinations are untouched.
    /// Call only after the person confirmed.
    func remove(name: String) {
        guard !isWorking else { return }
        do {
            _ = try remover(destinationID)
            env.toasts.show(String(localized: "\(name) removed from your passport."), duration: .seconds(2.4))
        } catch {
            failure = .remove
        }
    }

    // MARK: Postmark

    func isPostmarkHidden(stampID: String) -> Bool { env.preferences.isPostmarkHidden(stampID) }
    func setPostmarkHidden(_ hidden: Bool, stampID: String) { env.preferences.setPostmarkHidden(hidden, for: stampID) }
}
