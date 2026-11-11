import SwiftUI
import Observation

/// The actions of the Discover tab, the Search screen, the Results list and the Wishlist. State shown on screen comes from
/// `DiscoverDerived` (records and catalog); this object only changes records and keeps the one-off UI state.
@MainActor
@Observable
final class DiscoverViewModel {
    var errorMessage: String?

    private let env: AppEnvironment

    init(env: AppEnvironment) { self.env = env }

    // MARK: Wishlist (idempotent; Undo restores the original saved date)

    /// Saves or unsaves a place. The state is read from the records, not from what the screen last drew, so a second tap
    /// can never double-save.
    func toggleWishlist(_ destinationID: String) {
        let store = env.store
        do {
            switch store.state(of: destinationID) {
            case .wishlisted:
                let savedAt = store.wishlistDate(destinationID)
                guard try store.removeFromWishlist(destinationID: destinationID) else { return }
                env.haptics.lightImpact()
                env.toasts.show(String(localized: "Removed from wishlist")) { [weak self] in
                    guard let savedAt else { return }
                    self?.perform { _ = try store.restoreWishlistItem(destinationID: destinationID, addedAt: savedAt) }
                }
            case .notCollected:
                guard try store.addToWishlist(destinationID: destinationID) else { return }
                env.haptics.lightImpact()
                env.toasts.show(String(localized: "Saved to wishlist")) { [weak self] in
                    self?.perform { _ = try store.removeFromWishlist(destinationID: destinationID) }
                }
            case .collected, .verified:
                return
            }
        } catch {
            errorMessage = (error as? PassportError)?.errorDescription ?? String(localized: "Your change couldn’t be saved.")
        }
    }

    /// Removes a place from the wishlist (swipe in the Wishlist screen), with Undo.
    func removeFromWishlist(_ destinationID: String) {
        if env.store.state(of: destinationID) == .wishlisted { toggleWishlist(destinationID) }
    }

    /// Starts the collect flow. The reveal belongs to that flow and only follows a saved record.
    func collect(_ destinationID: String) {
        if let error = env.collect(destinationID) { errorMessage = error.errorDescription }
    }

    // MARK: Recents

    func clearRecentlyViewed() {
        let before = env.preferences.recentlyViewed
        guard !before.isEmpty else { return }
        env.preferences.clearRecentlyViewed()
        env.toasts.show(String(localized: "Cleared")) { [prefs = env.preferences] in prefs.restoreRecentlyViewed(before) }
    }

    func clearRecentSearches() {
        let before = env.preferences.recentSearches
        guard !before.isEmpty else { return }
        env.preferences.clearRecentSearches()
        env.toasts.show(String(localized: "Cleared")) { [prefs = env.preferences] in prefs.restoreRecentSearches(before) }
    }

    func noteSearch(_ term: String) { env.preferences.noteSearch(term) }

    private func perform(_ work: () throws -> Void) {
        do { try work() } catch { errorMessage = (error as? PassportError)?.errorDescription }
    }
}
