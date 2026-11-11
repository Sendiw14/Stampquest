import Foundation
import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, passport, discover, map, memories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .passport: String(localized: "Passport")
        case .discover: String(localized: "Discover")
        case .map: String(localized: "Map")
        case .memories: String(localized: "Memories")
        }
    }

    var symbolName: String {
        switch self {
        case .home: "house"
        case .passport: "book.closed"
        case .discover: "magnifyingglass"
        case .map: "map"
        case .memories: "heart.text.square"
        }
    }
}

/// Every place a navigation stack can push. Typed so routes are checked by the compiler
/// and can be created from deep links.
enum Route: Hashable {
    case destination(String)
    case stamp(String)
    case collection(String)
    case collections
    case wishlist
    case statistics
    case achievements
    case trips
    case trip(UUID)
    case memory(UUID)
    case settings
    case category(DestinationCategory)
    case country(String)
    /// All interests (the grid behind "See all").
    case interests
    case discoverResults(DiscoverResultsSpec)
}

/// What the reveal screen needs to show a freshly collected stamp.
struct RevealPayload: Identifiable, Equatable {
    let id = UUID()
    let destinationID: String
    let isVerified: Bool
    let collectedAt: Date
    /// The collection this stamp just completed, if any.
    var completedCollectionID: String?
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    private(set) var paths: [AppTab: [Route]] = [:]
    var reveal: RevealPayload?
    /// Increments each time the person re-selects the current tab; stacks pop to root.
    private(set) var tabReselect = 0

    func path(for tab: AppTab) -> [Route] { paths[tab] ?? [] }

    func binding(for tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    /// Pushes onto the stack of the tab the person is currently looking at.
    func push(_ route: Route, on tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        if let tab { selectedTab = tab }
        paths[target, default: []].append(route)
    }

    func popToRoot(_ tab: AppTab? = nil) { paths[tab ?? selectedTab] = [] }

    func select(_ tab: AppTab) {
        if tab == selectedTab {
            if !path(for: tab).isEmpty { popToRoot(tab) }
            tabReselect += 1
        }
        selectedTab = tab
    }

    func presentReveal(_ payload: RevealPayload) { reveal = payload }
    func dismissReveal() { reveal = nil }

    // MARK: Deep links

    /// Handles `stampquest://` URLs. Returns whether the URL was understood.
    @discardableResult
    func open(_ url: URL, catalog: Catalog) -> Bool {
        guard url.scheme?.lowercased() == "stampquest", let host = url.host?.lowercased() else { return false }
        let arg = url.pathComponents.dropFirst().first
        switch host {
        case "home": selectedTab = .home
        case "passport": selectedTab = .passport
        case "discover": selectedTab = .discover
        case "map": selectedTab = .map
        case "memories": selectedTab = .memories
        case "destination":
            guard let arg, catalog.destination(id: arg) != nil else { return false }
            selectedTab = .discover
            paths[.discover] = [.destination(arg)]
        case "stamp":
            guard let arg, let destinationID = StampID.destinationID(from: arg) ?? Optional(arg),
                  catalog.destination(id: destinationID) != nil else { return false }
            selectedTab = .passport
            paths[.passport] = [.stamp(destinationID)]
        case "collection":
            guard let arg, catalog.collection(id: arg) != nil else { return false }
            selectedTab = .discover
            paths[.discover] = [.collection(arg)]
        default: return false
        }
        return true
    }
}
