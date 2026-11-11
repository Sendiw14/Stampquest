import Foundation
import CoreLocation
import MapKit

/// Which places the Map and its List show. Shared by both, not persisted: the Map always opens on All.
nonisolated enum MapLayer: String, CaseIterable, Identifiable, Sendable {
    case all, collected, verified, saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .collected: String(localized: "Collected")
        case .verified: String(localized: "Verified")
        case .saved: String(localized: "Saved")
        }
    }

    /// Saved means wishlisted and not collected, so a collected place that is also on the wishlist never counts as saved.
    func includes(_ state: StampState) -> Bool {
        switch self {
        case .all: true
        case .collected: state.isInPassport
        case .verified: state == .verified
        case .saved: state == .wishlisted
        }
    }
}

/// A catalog destination that can be drawn on the map: valid coordinates, and the stamp that depicts it (nil draws the
/// designed placeholder).
nonisolated struct MapPlace: Identifiable, Hashable, Sendable {
    let destination: Destination
    let design: StampDesign?

    var id: String { destination.id }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude) }
}

extension Destination {
    /// Same rule as the verification policy: in range and not the null island placeholder.
    nonisolated var hasMapCoordinate: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && !(latitude == 0 && longitude == 0)
    }
}

nonisolated struct MapCounts: Equatable, Sendable {
    var collected = 0
    var verified = 0
    var saved = 0

    var isEmpty: Bool { collected == 0 && verified == 0 && saved == 0 }

    /// "3 collected · 1 verified · 2 saved", or "Nothing collected yet".
    var line: String {
        isEmpty ? String(localized: "Nothing collected yet")
                : String(localized: "\(collected) collected · \(verified) verified · \(saved) saved")
    }
}

/// Everything the Map shows, derived from the catalog and the user's records and nothing else (rule 12). A pure value:
/// build it again whenever a record changes and the Map follows without a refresh (rule 18).
nonisolated struct MapDerived: Sendable {
    /// Destinations with valid coordinates, in catalog order.
    let places: [MapPlace]
    /// Every destination, with or without coordinates: the List shows all of them.
    let destinations: [Destination]
    let counts: MapCounts
    private let states: [String: StampState]
    private let placeIndex: [String: MapPlace]

    init(catalog: Catalog, snapshot: PassportSnapshot) {
        var states: [String: StampState] = [:]
        var counts = MapCounts()
        for destination in catalog.destinations {
            let state = snapshot.state(of: destination.id)
            states[destination.id] = state
            switch state {
            case .verified: counts.collected += 1; counts.verified += 1
            case .collected: counts.collected += 1
            case .wishlisted: counts.saved += 1
            case .notCollected: break
            }
        }
        self.states = states
        self.counts = counts
        self.destinations = catalog.destinations
        let places = catalog.destinations.filter(\.hasMapCoordinate).map { MapPlace(destination: $0, design: catalog.stamp(forDestination: $0.id)) }
        self.places = places
        self.placeIndex = Dictionary(places.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static let empty = MapDerived(catalog: .empty, snapshot: .empty)

    /// Verified over collected over saved over available.
    func state(for id: String) -> StampState { states[id] ?? .notCollected }

    func visiblePlaces(_ layer: MapLayer) -> [MapPlace] { places.filter { layer.includes(state(for: $0.id)) } }

    func visibleDestinations(_ layer: MapLayer) -> [Destination] { destinations.filter { layer.includes(state(for: $0.id)) } }

    func place(id: String) -> MapPlace? { placeIndex[id] }
}

/// The camera maths of the Map, pure so it can be checked without a screen.
nonisolated enum MapGeometry {
    /// The free band of the window: markers stay between the chips (66 pt below the window's top) and the preview card
    /// (148 pt above its bottom).
    static let freeBandTop: CGFloat = 66
    static let freeBandBottomInset: CGFloat = 148
    static let sideMargin: CGFloat = 14
    /// A view that shows more than this many degrees of longitude is zoomed out past a regional level.
    static let regionalLongitude: Double = 40
    static let selectionDuration: TimeInterval = 0.35
    static let clusterDuration: TimeInterval = 0.5

    static func freeBandCenterY(windowHeight: CGFloat) -> CGFloat {
        (freeBandTop + max(freeBandTop, windowHeight - freeBandBottomInset)) / 2
    }

    static var regionalWidth: Double { MKMapSize.world.width * regionalLongitude / 360 }

    /// The rect to show so `coordinate` sits at the centre of the free band. The zoom is kept unless the map is zoomed out
    /// past a regional level, in which case it zooms in to that level.
    static func focusRect(on coordinate: CLLocationCoordinate2D, current: MKMapRect, size: CGSize) -> MKMapRect {
        guard size.width > 0, size.height > 0 else { return current }
        let width = min(max(current.width, 1), regionalWidth)
        let perPoint = width / Double(size.width)
        let place = MKMapPoint(coordinate)
        // The map centre sits below the place by the distance between the window centre and the band centre.
        let shift = (Double(size.height) / 2 - Double(freeBandCenterY(windowHeight: size.height))) * perPoint
        let centre = MKMapPoint(x: place.x, y: place.y + shift)
        let height = Double(size.height) * perPoint
        return MKMapRect(x: centre.x - width / 2, y: centre.y - height / 2, width: width, height: height)
    }

    /// The rect around `coordinate` that is `meters` wide across the window (Locate).
    static func localRect(on coordinate: CLLocationCoordinate2D, meters: Double, size: CGSize) -> MKMapRect {
        guard size.width > 0, size.height > 0 else { return .null }
        let width = meters * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
        let height = width * Double(size.height / size.width)
        let centre = MKMapPoint(coordinate)
        return MKMapRect(x: centre.x - width / 2, y: centre.y - height / 2, width: width, height: height)
    }

    /// The smallest rect holding every coordinate, never narrower than `minimumLongitude` degrees.
    static func boundingRect(_ coordinates: [CLLocationCoordinate2D], minimumLongitude: Double = 0) -> MKMapRect {
        var rect = MKMapRect.null
        for c in coordinates { let p = MKMapPoint(c); rect = rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0)) }
        guard !rect.isNull else { return rect }
        let minWidth = MKMapSize.world.width * minimumLongitude / 360
        if rect.width < minWidth { rect = rect.insetBy(dx: (rect.width - minWidth) / 2, dy: 0) }
        if rect.height < minWidth / 2 { rect = rect.insetBy(dx: 0, dy: (rect.height - minWidth / 2) / 2) }
        return rect
    }
}

/// Where the camera opens (5.6). Never the user's location: that only follows a tap on Locate.
nonisolated enum MapInitialCamera {
    /// Longitude and latitude covered by one "region" when looking for the densest part of the catalog.
    static let regionLongitude: Double = 39
    static let regionLatitude: Double = 30
    static let minimumLongitude: Double = 12

    static func rect(places: [MapPlace], derived: MapDerived) -> MKMapRect? {
        // MapKit cannot zoom out far enough to hold places on opposite sides of the world, so a spread-out passport opens on
        // the region that holds most of its stamps. Otherwise the same rule applies to the whole catalog.
        let mine = places.filter { derived.state(for: $0.id).isInPassport }
        let dense = densest(mine.isEmpty ? places : mine)
        return dense.isEmpty ? nil : MapGeometry.boundingRect(dense.map(\.coordinate), minimumLongitude: minimumLongitude)
    }

    /// The places inside the 39° by 30° box that holds the most of them. Ties go to the box centred on the smallest id.
    /// Sorted by longitude so each candidate only looks at the places inside its longitude band.
    static func densest(_ places: [MapPlace]) -> [MapPlace] {
        let sorted = places.sorted { $0.destination.longitude < $1.destination.longitude }
        let lons = sorted.map(\.destination.longitude)
        var best: [MapPlace] = []
        var bestID = ""
        for centre in sorted {
            let lon = centre.destination.longitude
            var lo = lowerBound(lons, lon - regionLongitude / 2)
            var inside: [MapPlace] = []
            while lo < sorted.count, lons[lo] <= lon + regionLongitude / 2 {
                if abs(sorted[lo].destination.latitude - centre.destination.latitude) <= regionLatitude / 2 { inside.append(sorted[lo]) }
                lo += 1
            }
            if inside.count > best.count || (inside.count == best.count && centre.id < bestID) { best = inside; bestID = centre.id }
        }
        return best
    }

    private static func lowerBound(_ values: [Double], _ target: Double) -> Int {
        var low = 0, high = values.count
        while low < high { let mid = (low + high) / 2; if values[mid] < target { low = mid + 1 } else { high = mid } }
        return low
    }
}

/// How a cluster is drawn: its size by member count, and whether it carries the "already in your passport" check.
nonisolated enum MapClusterStyle {
    static func diameter(count: Int) -> CGFloat { count < 5 ? 34 : count < 13 ? 40 : 46 }
    static func countFontSize(count: Int) -> CGFloat { count >= 13 ? 17 : 15 }
}

/// The camera move the screen asks the map surface for. A new `id` is a new request.
struct MapCameraCommand {
    enum Target {
        /// Fit these coordinates' rect inside the free band.
        case fit(MKMapRect)
        /// Centre this place in the free band.
        case focus(CLLocationCoordinate2D)
        /// Ease to a local view of this position.
        case local(CLLocationCoordinate2D, meters: Double)
        /// Zoom to the members of a cluster.
        case cluster(MKMapRect)
    }

    let id: Int
    let target: Target
    var animated = true
}

extension Int {
    /// "1 place", "2 places": the grammar agreement `^[…](inflect:)` does in a Text, as a plain String for VoiceOver labels.
    var placesPhrase: String { String(AttributedString(localized: "^[\(self) place](inflect: true)").characters) }
}
