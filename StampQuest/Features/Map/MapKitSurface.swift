import SwiftUI
import MapKit

/// One catalog place on the MapKit map. MapKit owns clustering, so the annotation is only an id and a coordinate.
final class MapPlaceAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    /// The selected place gets an annotation that MapKit never folds into a cluster.
    let clustered: Bool
    init(place: MapPlace, clustered: Bool) {
        id = place.id
        coordinate = place.coordinate
        self.clustered = clustered
    }
}

final class MapUserAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

/// An annotation view that hosts SwiftUI. Its bounds are the tappable area (never under 44 pt); the artwork and the label
/// are drawn around them and do not take touches.
class HostedAnnotationView: MKAnnotationView {
    var host: UIHostingController<AnyView>?

    func setContent<Content: View>(_ content: Content, canvas: CGSize, hit: CGSize) {
        if let host { host.rootView = AnyView(content) } else {
            let host = UIHostingController(rootView: AnyView(content))
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.safeAreaRegions = []
            host.sizingOptions = []
            addSubview(host.view)
            self.host = host
            clipsToBounds = false
        }
        bounds = CGRect(origin: .zero, size: hit)
        host?.view.frame = CGRect(x: (hit.width - canvas.width) / 2, y: (hit.height - canvas.height) / 2, width: canvas.width, height: canvas.height)
    }
}

final class MapPlaceView: HostedAnnotationView {
    static let reuseID = "place"
    var placeID = ""
    /// Set by the collision pass when another marker would sit on this label.
    var labelHidden = false
    var content = MapMarkerContent(name: "", state: .notCollected)
}

final class MapClusterAnnotationView: HostedAnnotationView {
    static let reuseID = MKMapViewDefaultClusterAnnotationViewReuseIdentifier
}

final class MapUserView: HostedAnnotationView {
    static let reuseID = "user"
}

/// The map, as MapKit draws it: standard, flat, muted, no points of interest, no compass, north up. Markers are SwiftUI
/// views hosted in annotation views; MapKit clusters them and reuses the views.
struct MapKitSurface: UIViewRepresentable {
    let places: [MapPlace]
    let derived: MapDerived
    let selectedID: String?
    let userCoordinate: CLLocationCoordinate2D?
    let camera: MapCameraCommand?
    let reduceMotion: Bool
    let onTapPlace: (String) -> Void
    let onTapEmpty: () -> Void
    let onFail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false
        map.preferredConfiguration = configuration
        map.showsCompass = false
        map.showsScale = false
        map.showsUserLocation = false   // that would start continuous updates; Locate draws its own one-shot dot
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 2_500, maxCenterCoordinateDistance: 80_000_000)
        map.delegate = context.coordinator
        map.register(MapPlaceView.self, forAnnotationViewWithReuseIdentifier: MapPlaceView.reuseID)
        map.register(MapClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MapClusterAnnotationView.reuseID)
        map.register(MapUserView.self, forAnnotationViewWithReuseIdentifier: MapUserView.reuseID)
        map.isAccessibilityElement = false
        map.accessibilityElementsHidden = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tappedMap(_:)))
        tap.delegate = context.coordinator
        for recognizer in map.gestureRecognizers ?? [] {
            if let t = recognizer as? UITapGestureRecognizer, t.numberOfTapsRequired == 2 { tap.require(toFail: t) }
        }
        map.addGestureRecognizer(tap)
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.onTapPlace = onTapPlace
        c.onTapEmpty = onTapEmpty
        c.onFail = onFail
        c.reduceMotion = reduceMotion
        c.derived = derived
        c.selectedID = selectedID
        c.syncPlaces(places)
        c.syncUser(userCoordinate)
        c.refreshViews()
        c.apply(camera)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        weak var map: MKMapView?
        var onTapPlace: (String) -> Void = { _ in }
        var onTapEmpty: () -> Void = {}
        var onFail: () -> Void = {}
        var reduceMotion = false
        var derived = MapDerived.empty
        var selectedID: String?
        private var annotations: [String: MapPlaceAnnotation] = [:]
        private var user: MapUserAnnotation?
        private var lastCommand = 0
        private var appeared = Set<String>()

        // MARK: Places

        func syncPlaces(_ places: [MapPlace]) {
            guard let map else { return }
            let wanted = Set(places.map(\.id))
            var retired: [MapPlaceAnnotation] = []
            for (id, annotation) in annotations {
                // Gone from the layer, or its selected/unselected form changed: take the old annotation off the map.
                if !wanted.contains(id) { annotations[id] = nil; appeared.remove(id); retired.append(annotation) }
                else if annotation.clustered == (id == selectedID) { annotations[id] = nil; retired.append(annotation) }
            }
            for annotation in retired {
                let leaving = !wanted.contains(annotation.id)
                if leaving, !reduceMotion, let view = map.view(for: annotation) {
                    UIView.animate(withDuration: 0.16, animations: { view.alpha = 0 }, completion: { _ in map.removeAnnotation(annotation); view.alpha = 1 })
                } else {
                    map.removeAnnotation(annotation)
                }
            }
            let fresh = places.filter { annotations[$0.id] == nil }.map { MapPlaceAnnotation(place: $0, clustered: $0.id != selectedID) }
            for annotation in fresh { annotations[annotation.id] = annotation }
            if !fresh.isEmpty { map.addAnnotations(fresh) }
        }

        func syncUser(_ coordinate: CLLocationCoordinate2D?) {
            guard let map else { return }
            if let coordinate {
                if let user { user.coordinate = coordinate } else {
                    let annotation = MapUserAnnotation(coordinate: coordinate)
                    user = annotation
                    map.addAnnotation(annotation)
                }
            } else if let user {
                map.removeAnnotation(user)
                self.user = nil
            }
        }

        /// The content of a marker from the records as they stand now.
        private func content(for id: String) -> MapMarkerContent {
            let place = derived.place(id: id)
            let state = derived.state(for: id)
            let selected = id == selectedID
            return MapMarkerContent(name: place?.destination.name ?? "", state: state, design: place?.design, selected: selected,
                                    showsLabel: selected || state.isInPassport)
        }

        func refreshViews() {
            guard let map else { return }
            for annotation in map.annotations {
                guard let view = map.view(for: annotation) else { continue }
                if let place = annotation as? MapPlaceAnnotation, let view = view as? MapPlaceView { configure(view, place) }
                else if let cluster = annotation as? MKClusterAnnotation, let view = view as? MapClusterAnnotationView { configure(view, cluster) }
            }
            avoidLabelCollisions()
        }

        private func configure(_ view: MapPlaceView, _ annotation: MapPlaceAnnotation) {
            var content = content(for: annotation.id)
            view.placeID = annotation.id
            if view.labelHidden && !content.selected { content.showsLabel = false }
            view.content = content
            // The selected marker is drawn above its neighbours and is never swallowed by a cluster.
            view.clusteringIdentifier = annotation.clustered ? "place" : nil
            view.displayPriority = content.selected ? .required : (content.state.isInPassport ? .defaultHigh : .defaultLow)
            view.zPriority = Self.zPriority(state: content.state, selected: content.selected, latitude: annotation.coordinate.latitude)
            view.collisionMode = .rectangle
            view.canShowCallout = false
            view.setContent(MapMarkerView(content: content), canvas: MapMarkerView.canvas, hit: content.hitSize)
            view.isAccessibilityElement = true
            view.accessibilityTraits = .button
            view.accessibilityLabel = Self.spokenLabel(derived.place(id: annotation.id)?.destination, state: content.state)
        }

        private func configure(_ view: MapClusterAnnotationView, _ cluster: MKClusterAnnotation) {
            let members = cluster.memberAnnotations.compactMap { $0 as? MapPlaceAnnotation }
            let inPassport = members.filter { derived.state(for: $0.id).isInPassport }.count
            view.setContent(MapClusterView(count: members.count, hasCollected: inPassport > 0),
                            canvas: CGSize(width: 70, height: 70), hit: CGSize(width: 50, height: 50))
            view.displayPriority = .defaultHigh
            view.zPriority = MKAnnotationViewZPriority(rawValue: 700)
            view.collisionMode = .circle
            view.isAccessibilityElement = true
            view.accessibilityTraits = .button
            let places = members.count.placesPhrase
            view.accessibilityLabel = inPassport > 0
                ? places + ". " + (inPassport == 1 ? String(localized: "One is in your passport.") : String(localized: "\(inPassport) are in your passport."))
                : places
            view.accessibilityHint = String(localized: "Double tap to zoom in.")
        }

        /// Back to front: available, saved, collected, verified, selected; higher on the screen is further back.
        static func zPriority(state: StampState, selected: Bool, latitude: Double) -> MKAnnotationViewZPriority {
            if selected { return .max }
            let base: Float = switch state { case .notCollected: 0; case .wishlisted: 200; case .collected: 400; case .verified: 600 }
            return MKAnnotationViewZPriority(rawValue: base + Float(90 - max(-90, min(90, latitude))))
        }

        static func spokenLabel(_ destination: Destination?, state: StampState) -> String {
            guard let destination else { return "" }
            switch state {
            case .notCollected: return String(localized: "\(destination.name), \(destination.countryName). \(destination.category.singularTitle). Not in your passport.")
            case .wishlisted: return String(localized: "\(destination.name), \(destination.countryName). On your wishlist.")
            case .collected: return String(localized: "\(destination.name), \(destination.countryName). In your passport.")
            case .verified: return String(localized: "\(destination.name), \(destination.countryName). Verified visit.")
            }
        }

        /// Hides the label of a marker when it would sit on another marker or label. The selected and collected ones win.
        func avoidLabelCollisions() {
            guard let map else { return }
            let views = map.annotations.compactMap { map.view(for: $0) as? MapPlaceView }
            func rank(_ v: MapPlaceView) -> Int { v.content.selected ? 2 : v.content.state.isInPassport ? 1 : 0 }
            var taken: [CGRect] = views.map { map.convert($0.bounds, from: $0) }
            for view in views.sorted(by: { rank($0) > rank($1) }) where view.content.showsLabel || view.labelHidden {
                let core = map.convert(view.bounds, from: view)
                let labelRect = CGRect(x: core.midX - 56, y: core.maxY - 6, width: 112, height: 28)
                let blocked = taken.contains { $0.intersects(labelRect) && $0 != core }
                let wanted = view.content.selected || view.content.state.isInPassport
                let hide = blocked && !view.content.selected
                if view.labelHidden != hide || (wanted && view.content.showsLabel == hide) {
                    view.labelHidden = hide
                    var updated = view.content
                    updated.showsLabel = wanted && !hide
                    view.content = updated
                    view.setContent(MapMarkerView(content: updated), canvas: MapMarkerView.canvas, hit: updated.hitSize)
                }
                if !hide && wanted { taken.append(labelRect) }
            }
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let place = annotation as? MapPlaceAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MapPlaceView.reuseID, for: place) as! MapPlaceView
                view.labelHidden = false
                configure(view, place)
                return view
            }
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MapClusterAnnotationView.reuseID, for: cluster) as! MapClusterAnnotationView
                configure(view, cluster)
                return view
            }
            if annotation is MapUserAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MapUserView.reuseID, for: annotation) as! MapUserView
                view.setContent(MapUserDot(), canvas: CGSize(width: 44, height: 44), hit: CGSize(width: 44, height: 44))
                view.zPriority = .max
                view.displayPriority = .required
                view.canShowCallout = false
                view.isAccessibilityElement = true
                view.accessibilityLabel = String(localized: "Your position")
                return view
            }
            return nil
        }

        /// Markers pop in; a new batch of markers is staggered west to east (about 38 ms apart, together beyond 30).
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            // The selected marker is a fresh view: it springs in from 86% rather than popping like a new marker.
            for view in views.compactMap({ $0 as? MapPlaceView }) where view.content.selected && appeared.contains(view.placeID) {
                view.alpha = 1
                guard !reduceMotion else { continue }
                view.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [.allowUserInteraction]) { view.transform = .identity }
            }
            let placeViews = views.compactMap { $0 as? MapPlaceView }.filter { !appeared.contains($0.placeID) }
            let ordered = placeViews.sorted { $0.center.x < $1.center.x }
            let stagger = ordered.count <= 30
            for (index, view) in ordered.enumerated() {
                appeared.insert(view.placeID)
                if reduceMotion {
                    view.alpha = 0
                    UIView.animate(withDuration: 0.18) { view.alpha = 1 }
                } else {
                    view.alpha = 0
                    view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                    UIView.animate(withDuration: stagger ? 0.5 : 0.25, delay: stagger ? Double(index) * 0.038 : 0,
                                   usingSpringWithDamping: 0.62, initialSpringVelocity: 0, options: [.allowUserInteraction]) {
                        view.alpha = 1
                        view.transform = .identity
                    }
                }
            }
            for view in views where !(view is MapPlaceView) && view.alpha < 1 { UIView.animate(withDuration: 0.16) { view.alpha = 1 } }
            avoidLabelCollisions()
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // Selection lives in the view model; MapKit's own selected state is not used.
            DispatchQueue.main.async { mapView.deselectAnnotation(annotation, animated: false) }
            if let place = annotation as? MapPlaceAnnotation {
                onTapPlace(place.id)
            } else if let cluster = annotation as? MKClusterAnnotation {
                zoom(to: cluster, in: mapView)
            }
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) { avoidLabelCollisions() }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) { refreshViews() }

        /// Once the map has drawn, a later tile that fails to load (panning offline) is not "the map can't load".
        private var hasRendered = false

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) { if fullyRendered { hasRendered = true } }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) { if !hasRendered { onFail() } }

        // MARK: Camera

        private func zoom(to cluster: MKClusterAnnotation, in map: MKMapView) {
            let rect = MapGeometry.boundingRect(cluster.memberAnnotations.map(\.coordinate))
            guard !rect.isNull else { return }
            // A cluster of places on the same spot still has to open: never narrower than a few kilometres.
            let minimum = 4_000 * MKMapPointsPerMeterAtLatitude(cluster.coordinate.latitude)
            let widened = rect.width < minimum ? rect.insetBy(dx: (rect.width - minimum) / 2, dy: (rect.height - minimum) / 2) : rect
            show(widened, padding: padding(for: map), duration: MapGeometry.clusterDuration, in: map)
        }

        private func padding(for map: MKMapView) -> UIEdgeInsets {
            UIEdgeInsets(top: MapGeometry.freeBandTop + 24, left: MapGeometry.sideMargin + 24,
                         bottom: MapGeometry.freeBandBottomInset + 24, right: MapGeometry.sideMargin + 24)
        }

        private func show(_ rect: MKMapRect, padding: UIEdgeInsets, duration: TimeInterval, animated: Bool = true, in map: MKMapView) {
            guard animated, !reduceMotion else { map.setVisibleMapRect(rect, edgePadding: padding, animated: false); return }
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                map.setVisibleMapRect(rect, edgePadding: padding, animated: false)
            }
        }

        func apply(_ command: MapCameraCommand?) {
            guard let map, let command, command.id != lastCommand else { return }
            // Before the first layout the map has no size: try again next turn of the run loop.
            guard map.bounds.width > 0, map.bounds.height > 0 else {
                DispatchQueue.main.async { [weak self] in self?.apply(command) }
                return
            }
            lastCommand = command.id
            let size = map.bounds.size
            switch command.target {
            case .fit(let rect):
                show(rect, padding: padding(for: map), duration: 0.5, animated: command.animated, in: map)
            case .cluster(let rect):
                show(rect, padding: padding(for: map), duration: MapGeometry.clusterDuration, animated: command.animated, in: map)
            case .focus(let coordinate):
                let rect = MapGeometry.focusRect(on: coordinate, current: map.visibleMapRect, size: size)
                show(rect, padding: .zero, duration: MapGeometry.selectionDuration, animated: command.animated, in: map)
            case .local(let coordinate, let meters):
                let rect = MapGeometry.localRect(on: coordinate, meters: meters, size: size)
                show(rect, padding: .zero, duration: 0.6, animated: command.animated, in: map)
            }
        }

        // MARK: Taps on the empty map

        @objc func tappedMap(_ recognizer: UITapGestureRecognizer) { onTapEmpty() }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is MKAnnotationView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
