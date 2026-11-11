import SwiftUI
import MapKit
import Observation

/// What happens on the Map besides drawing it: the layer, the selection, the camera requests and Locate.
/// Which places exist and how they stand comes from `MapDerived` (catalog and records), never from here.
@MainActor
@Observable
final class MapViewModel {
    private(set) var layer: MapLayer = .all
    private(set) var selectedID: String?
    private(set) var camera: MapCameraCommand?
    /// The one-shot position, shown only while Locate is on. Never stored, never sent anywhere.
    private(set) var userCoordinate: CLLocationCoordinate2D?
    private(set) var isLocating = false
    private(set) var showsLocationOffBanner = false
    private(set) var mapUnavailable: Bool
    var showsExplainer = false
    var showsGuide = false
    var showsList = false
    var isSearching = false
    /// Changes when the map is asked to start over ("Try again" on the unavailable state).
    private(set) var mapGeneration = 0
    /// Collect and wishlist run through the same actions as Discover: idempotent, with Undo, one toast.
    let actions: DiscoverViewModel

    private let env: AppEnvironment
    private var cameraCounter = 0
    private var hasPlacedInitialCamera = false
    private var locateTask: Task<Void, Never>?

    init(env: AppEnvironment) {
        self.env = env
        self.actions = DiscoverViewModel(env: env)
        #if DEBUG
        mapUnavailable = LaunchConfiguration.current.mapUnavailable
        #else
        mapUnavailable = false
        #endif
    }

    var isLocateOn: Bool { userCoordinate != nil }

    // MARK: Layer

    func setLayer(_ new: MapLayer, derived: MapDerived) {
        guard new != layer else { return }
        layer = new
        env.haptics.selection()
        // The card stays only if its place is still in the layer.
        if let id = selectedID, !new.includes(derived.state(for: id)) { selectedID = nil }
    }

    // MARK: Selection

    /// A tap on a marker: selects it, or clears it when it is already selected.
    func tapPlace(_ id: String, derived: MapDerived) {
        if selectedID == id { clearSelection(); return }
        select(id, derived: derived)
    }

    func select(_ id: String, derived: MapDerived) {
        guard let place = derived.place(id: id) else { return }
        selectedID = id
        env.haptics.selection()
        move(.focus(place.coordinate))
    }

    func clearSelection() { selectedID = nil }

    /// A Search result: shows the place, switching to All first when the layer would hide it.
    func showPlace(_ id: String, derived: MapDerived) {
        if !layer.includes(derived.state(for: id)) { layer = .all }
        showsList = false
        select(id, derived: derived)
    }

    // MARK: Camera

    func move(_ target: MapCameraCommand.Target, animated: Bool = true) {
        cameraCounter += 1
        camera = MapCameraCommand(id: cameraCounter, target: target, animated: animated)
    }

    /// Opens on the user's collected places, else the densest region of the catalog. Once per session of this screen.
    func placeInitialCamera(derived: MapDerived) {
        guard !hasPlacedInitialCamera, !derived.places.isEmpty else { return }
        hasPlacedInitialCamera = true
        if let rect = MapInitialCamera.rect(places: derived.places, derived: derived) { move(.fit(rect), animated: false) }
    }

    func retryMap() {
        mapUnavailable = false
        mapGeneration += 1
        hasPlacedInitialCamera = false
    }

    func mapFailedToLoad() { mapUnavailable = true }

    // MARK: Card actions

    func collect(_ id: String) { actions.collect(id) }
    func toggleSave(_ id: String) { actions.toggleWishlist(id) }
    func openDetail(_ id: String) { env.router.push(.destination(id), on: .map) }
    func openStamp(_ id: String) { env.router.push(.stamp(id), on: .passport) }

    // MARK: Locate

    /// Locate, and nothing else: the explainer when permission was never asked, the banner when it was refused, otherwise
    /// one position fix. Tapping it again turns the position off.
    func tapLocate() {
        if isLocateOn || isLocating { turnLocateOff(); return }
        showsLocationOffBanner = false
        switch env.location.authorization {
        case .notDetermined: showsExplainer = true
        case .denied, .restricted: showsLocationOffBanner = true
        case .authorized: fix()
        }
    }

    /// "Continue" on the explainer: asks for When In Use, then fixes once if it was granted.
    func continueFromExplainer() {
        showsExplainer = false
        locateTask?.cancel()
        locateTask = Task { [env] in
            let result = await env.location.requestAuthorization()
            guard !Task.isCancelled else { return }
            switch result {
            case .authorized: fix()
            case .denied, .restricted: showsLocationOffBanner = true
            case .notDetermined: break
            }
        }
    }

    func dismissExplainer() { showsExplainer = false }

    private func fix() {
        locateTask?.cancel()
        isLocating = true
        locateTask = Task { [env] in
            defer { isLocating = false }
            do {
                let reading = try await env.location.currentReading(timeout: .seconds(10))
                guard !Task.isCancelled else { return }
                guard reading.horizontalAccuracy >= 0, (-90...90).contains(reading.latitude), (-180...180).contains(reading.longitude) else {
                    throw VerificationFailure.invalidReading
                }
                let here = CLLocationCoordinate2D(latitude: reading.latitude, longitude: reading.longitude)
                userCoordinate = here
                move(.local(here, meters: 25_000))
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                env.toasts.show(String(localized: "Couldn’t find your location. Try again."))
            }
        }
    }

    /// Off when the person taps Locate again, leaves the Map tab or the app goes to the background.
    func turnLocateOff() {
        locateTask?.cancel()
        locateTask = nil
        isLocating = false
        userCoordinate = nil
    }

    func dismissLocationOffBanner() { showsLocationOffBanner = false }

    /// Back from Settings with permission granted: the banner has done its job.
    func authorizationMayHaveChanged() {
        if showsLocationOffBanner, env.location.authorization == .authorized { showsLocationOffBanner = false }
    }

    func openSettings() { env.openSystemSettings() }
}
