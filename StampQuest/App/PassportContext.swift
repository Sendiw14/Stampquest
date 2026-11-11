import SwiftUI
import SwiftData

/// A destination together with the stamp that depicts it and where the person stands with it.
struct DestinationItem: Identifiable, Hashable {
    let destination: Destination
    let design: StampDesign
    let state: StampState

    var id: String { destination.id }
}

/// A derived, read-only view of the passport made available to every screen through the
/// environment. Because everything is computed from the same snapshot, a change made on
/// one screen is reflected consistently on all the others.
struct PassportContext {
    let catalog: Catalog
    let snapshot: PassportSnapshot
    let statistics: PassportStatistics
    let progress: [CollectionProgress]
    let achievements: [Achievement]

    init(catalog: Catalog, snapshot: PassportSnapshot) {
        self.catalog = catalog
        self.snapshot = snapshot
        self.statistics = PassportStatistics.compute(from: snapshot, catalog: catalog)
        self.progress = CollectionProgress.all(catalog: catalog, snapshot: snapshot)
        self.achievements = AchievementEvaluator.evaluate(snapshot: snapshot, catalog: catalog)
    }

    static let empty = PassportContext(catalog: .empty, snapshot: .empty)

    func state(of destinationID: String) -> StampState { snapshot.state(of: destinationID) }

    func item(_ destination: Destination) -> DestinationItem? {
        guard let design = catalog.stamp(forDestination: destination.id) else { return nil }
        return DestinationItem(destination: destination, design: design, state: snapshot.state(of: destination.id))
    }

    func item(id: String) -> DestinationItem? { catalog.destination(id: id).flatMap(item) }

    func items(ids: [String]) -> [DestinationItem] { ids.compactMap(item(id:)) }

    var allItems: [DestinationItem] { catalog.destinations.compactMap(item) }

    func progress(forCollection id: String) -> CollectionProgress? { progress.first { $0.collection.id == id } }

    /// Incomplete collections, closest to completion first, that have at least one stamp.
    var collectionsInProgress: [CollectionProgress] {
        progress.filter { !$0.isComplete && $0.collected > 0 }
            .sorted { $0.fraction != $1.fraction ? $0.fraction > $1.fraction : $0.collection.order < $1.collection.order }
    }
}

extension EnvironmentValues {
    @Entry var passport: PassportContext = .empty
}

/// Observes the user's records with `@Query` and publishes a `PassportContext` to the
/// view hierarchy below it.
struct PassportProvider<Content: View>: View {
    @Environment(AppEnvironment.self) private var env
    @Query private var stamps: [UserStamp]
    @Query private var wishlist: [WishlistItem]
    @Query private var memories: [MemoryEntry]
    @Query private var trips: [Trip]
    @ViewBuilder var content: () -> Content

    var body: some View {
        let snapshot = PassportSnapshot(userStamps: stamps, wishlist: wishlist, memories: memories, trips: trips)
        content()
            .environment(\.passport, PassportContext(catalog: env.catalog, snapshot: snapshot))
    }
}
