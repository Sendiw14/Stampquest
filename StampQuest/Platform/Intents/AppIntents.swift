import AppIntents
import Foundation
import Observation

/// Carries a request from an App Intent (which may run before the UI exists) to the router.
@MainActor
@Observable
final class NavigationInbox {
    static let shared = NavigationInbox()
    var pending: URL?

    static func post(_ url: URL) { shared.pending = url }
}

private nonisolated enum IntentCatalog {
    static let catalog: Catalog? = try? CatalogLoader.load()
}

nonisolated struct DestinationEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Destination"
    static let defaultQuery = DestinationQuery()

    var id: String
    var name: String
    var subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }

    init(_ destination: Destination) {
        id = destination.id
        name = destination.name
        subtitle = destination.subtitle
    }
}

nonisolated struct DestinationQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [DestinationEntity] {
        guard let catalog = IntentCatalog.catalog else { return [] }
        return identifiers.compactMap { catalog.destination(id: $0) }.map(DestinationEntity.init)
    }

    func entities(matching string: String) async throws -> [DestinationEntity] {
        guard let catalog = IntentCatalog.catalog else { return [] }
        return catalog.search(string).prefix(20).map(DestinationEntity.init)
    }

    func suggestedEntities() async throws -> [DestinationEntity] {
        guard let catalog = IntentCatalog.catalog else { return [] }
        return catalog.featured.map(DestinationEntity.init)
    }
}

nonisolated struct OpenPassportIntent: AppIntent {
    static let title: LocalizedStringResource = "Open my passport"
    static let description = IntentDescription("Opens your StampQuest passport.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "stampquest://passport") { await NavigationInbox.post(url) }
        return .result()
    }
}

struct ShowDestinationIntent: AppIntent {
    static let title: LocalizedStringResource = "Show a destination"
    static let description = IntentDescription("Opens a place in StampQuest so you can collect its stamp.")
    static let openAppWhenRun = true

    @Parameter(title: "Destination")
    var destination: DestinationEntity

    func perform() async throws -> some IntentResult {
        if let url = URL(string: "stampquest://destination/\(destination.id)") { await NavigationInbox.post(url) }
        return .result()
    }
}

nonisolated struct StampQuestShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenPassportIntent(), phrases: ["Open my passport in \(.applicationName)", "Show my \(.applicationName) passport"],
                    shortTitle: "My passport", systemImageName: "book.closed")
        AppShortcut(intent: ShowDestinationIntent(), phrases: ["Show \(\.$destination) in \(.applicationName)"],
                    shortTitle: "Show destination", systemImageName: "mappin.and.ellipse")
    }
}
