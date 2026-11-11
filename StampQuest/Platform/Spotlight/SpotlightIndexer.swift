import CoreSpotlight
import UniformTypeIdentifiers
import SwiftUI

/// Makes catalogue destinations findable from system search.
///
/// Only **public catalogue content** is indexed (name, landmark, summary, keywords and the
/// stamp artwork). Nothing about what a person has collected, written or photographed is ever
/// sent to Spotlight.
@MainActor
enum SpotlightIndexer {
    private static let versionKey = "spotlight.indexedCatalogVersion"
    static let domain = "app.stampquest.destinations"

    /// Indexes the catalogue once per catalogue version.
    static func indexIfNeeded(catalog: Catalog, defaults: UserDefaults = .standard) async {
        guard defaults.string(forKey: versionKey) != catalog.version, CSSearchableIndex.isIndexingAvailable() else { return }
        var items: [CSSearchableItem] = []
        for destination in catalog.destinations {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = destination.name == destination.landmark ? destination.name : "\(destination.name), \(destination.landmark)"
            attributes.contentDescription = destination.summary
            attributes.keywords = [destination.name, destination.landmark, destination.countryName] + destination.keywords + destination.alternativeNames
            if let design = catalog.stamp(forDestination: destination.id) {
                let image = renderShareImage(PerforatedStampView(design: design, showsTitle: false, isDecorative: true).frame(width: 120), scale: 2)
                attributes.thumbnailData = image?.pngData()
            }
            items.append(CSSearchableItem(uniqueIdentifier: destination.id, domainIdentifier: domain, attributeSet: attributes))
        }
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [domain])
            try await index.indexSearchableItems(items)
            defaults.set(catalog.version, forKey: versionKey)
        } catch {
            // Search indexing is a convenience; failure is not worth surfacing.
        }
    }

    /// The destination id for a Spotlight tap, if the activity is one of ours.
    static func destinationID(from activity: NSUserActivity) -> String? {
        activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
    }
}
