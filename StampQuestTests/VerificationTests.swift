import Testing
import Foundation
import SwiftData
@testable import StampQuest

// MARK: - Pure policy

struct VerificationPolicyTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let tower = Destination(id: "tower", name: "Tower", landmark: "Tower", countryCode: "FR", region: .europe, category: .landmark,
                            latitude: 48.8584, longitude: 2.2945, verificationRadiusOverride: nil,
                            summary: "s", story: "s", keywords: [], alternativeNames: [], isFeatured: false)

    func reading(lat: Double = 48.8584, lon: Double = 2.2945, accuracy: Double = 10, age: TimeInterval = 1) -> LocationReading {
        LocationReading(latitude: lat, longitude: lon, horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(-age))
    }

    func evaluate(_ r: LocationReading, _ d: Destination? = nil) -> Result<VisitVerification, VerificationFailure> {
        VerificationPolicy.standard.evaluate(r, for: d ?? tower, now: now)
    }

    @Test func readingInsideTheRadiusSucceedsAndStoresOnlyMeasurements() throws {
        // ~100 m north of the tower
        let v = try evaluate(reading(lat: 48.8593)).get()
        #expect(v.distanceMeters > 50 && v.distanceMeters < 150)
        #expect(v.radiusMeters == 600)
        #expect(v.horizontalAccuracyMeters == 10)
        #expect(v.policyVersion == VerificationPolicy.currentVersion)
        #expect(v.verifiedAt == now)
    }

    @Test func readingOutsideTheRadiusFailsWithTheDistance() {
        // Roughly 11 km away.
        guard case .failure(.tooFar(let distance, let radius)) = evaluate(reading(lat: 48.95)) else { Issue.record("expected tooFar"); return }
        #expect(distance > 10_000 && radius == 600)
    }

    @Test func poorAccuracyFailsEvenWhenTheCentreIsClose() {
        #expect(evaluate(reading(accuracy: 450)) == .failure(.poorAccuracy(450)))
    }

    @Test func staleReadingsAreRejected() {
        #expect(evaluate(reading(age: 300)) == .failure(.staleReading))
    }

    @Test func invalidReadingsAreRejected() {
        #expect(evaluate(reading(accuracy: -1)) == .failure(.invalidReading))
        #expect(evaluate(reading(lat: 123)) == .failure(.invalidReading))
    }

    @Test func destinationWithoutCoordinatesCannotBeVerified() {
        let nowhere = Destination(id: "x", name: "X", landmark: "X", countryCode: "FR", region: .europe, category: .landmark,
                                  latitude: 0, longitude: 0, verificationRadiusOverride: nil,
                                  summary: "s", story: "s", keywords: [], alternativeNames: [], isFeatured: false)
        #expect(evaluate(reading(lat: 0, lon: 0), nowhere) == .failure(.missingDestinationCoordinates))
    }

    @Test func radiusDependsOnThePlace() throws {
        let catalog = try CatalogLoader.load()
        let canyon = try #require(catalog.destination(id: "grand-canyon"))
        // 12 km from the South Rim point is fine for a national park...
        let ok = VerificationPolicy.standard.evaluate(reading(lat: canyon.latitude + 0.108, lon: canyon.longitude), for: canyon, now: now)
        #expect((try? ok.get()) != nil)
        // ...but would not be for a single monument.
        let tooFar = VerificationPolicy.standard.evaluate(reading(lat: tower.latitude + 0.108, lon: tower.longitude), for: tower, now: now)
        #expect(tooFar == .failure(.tooFar(distance: tooFar.failureDistance, radius: 600)))
    }

    @Test func haversineMatchesKnownDistances() {
        let parisToLondon = Geo.distanceMeters(lat1: 48.8566, lon1: 2.3522, lat2: 51.5074, lon2: -0.1278)
        #expect(abs(parisToLondon - 343_500) < 3_000)
        #expect(Geo.distanceMeters(lat1: 10, lon1: 10, lat2: 10, lon2: 10) == 0)
    }

    @Test func everyFailureHasHumanReadableCopyAndOffersTheManualAlternative() {
        let all: [VerificationFailure] = [.featureDisabled, .servicesDisabled, .permissionDenied, .permissionRestricted, .timeout, .staleReading,
                                          .invalidReading, .poorAccuracy(150), .tooFar(distance: 3_400, radius: 600), .missingDestinationCoordinates,
                                          .cancelled, .unavailable]
        for failure in all {
            #expect(!failure.title.isEmpty && !failure.message.isEmpty)
            #expect(!failure.message.contains("VerificationFailure"), "No internal identifiers shown to people")
        }
        #expect(VerificationFailure.permissionDenied.suggestsSettings)
        #expect(!VerificationFailure.timeout.suggestsSettings)
    }
}

private extension Result where Failure == VerificationFailure {
    var failureDistance: Double { if case .failure(.tooFar(let d, _)) = self { d } else { 0 } }
}

// MARK: - Service with a mocked provider

@MainActor
final class MockLocationProvider: LocationProviding {
    var servicesOn = true
    var status: LocationAuthorization = .authorized
    var statusAfterPrompt: LocationAuthorization = .authorized
    var result: Result<LocationReading, VerificationFailure> = .failure(.unavailable)
    private(set) var promptCount = 0
    private(set) var readingRequests = 0

    func servicesEnabled() async -> Bool { servicesOn }
    var authorization: LocationAuthorization { status }
    func requestAuthorization() async -> LocationAuthorization {
        promptCount += 1
        status = statusAfterPrompt
        return status
    }
    func currentReading(timeout: Duration) async throws -> LocationReading {
        readingRequests += 1
        return try result.get()
    }
}

@MainActor
struct VerificationServiceTests {
    let container: ModelContainer
    let store: PassportStore
    let provider = MockLocationProvider()
    let service: VerificationService
    let destination: Destination
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try Fixture.container()
        store = PassportStore(context: container.mainContext, catalog: Fixture.catalog)
        let nowCopy = Date(timeIntervalSince1970: 1_800_000_000)
        service = VerificationService(provider: provider, now: { nowCopy })
        destination = Fixture.catalog.destination(id: "a")!
    }

    private func nearReading() -> LocationReading {
        LocationReading(latitude: destination.latitude, longitude: destination.longitude, horizontalAccuracy: 10, timestamp: now)
    }

    private var stamps: Int { (try? container.mainContext.fetchCount(FetchDescriptor<UserStamp>())) ?? -1 }

    @Test func successCollectsAndVerifiesExactlyOnce() async {
        provider.result = .success(nearReading())
        let attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .success(.collectedAndVerified(let stamp)) = attempt else { Issue.record("expected success, got \(attempt)"); return }
        #expect(stamp.isVerified && stamps == 1)
        #expect(!service.isBusy)
    }

    @Test func successOnAnExistingManualStampUpgradesIt() async throws {
        try store.collect(destinationID: "a")
        provider.result = .success(nearReading())
        let attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .success(.upgraded) = attempt else { Issue.record("expected upgrade"); return }
        #expect(stamps == 1)
    }

    @Test func tooFarFailsAndPersistsNothing() async {
        provider.result = .success(LocationReading(latitude: 0.5, longitude: 0.5, horizontalAccuracy: 10, timestamp: now))
        let attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.tooFar) = attempt else { Issue.record("expected tooFar"); return }
        #expect(stamps == 0, "A failed verification never creates or changes a stamp")
    }

    @Test func permissionDeniedFailsButManualCollectionStillWorks() async throws {
        provider.status = .denied
        let attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.permissionDenied) = attempt else { Issue.record("expected denied"); return }
        #expect(provider.readingRequests == 0, "No location is read without permission")
        #expect(stamps == 0)
        let manual = try store.collect(destinationID: "a")
        #expect(manual.isNew && manual.stamp.state == .collected)
    }

    @Test func restrictedAndDisabledServicesAreReported() async {
        provider.status = .restricted
        var attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.permissionRestricted) = attempt else { Issue.record("expected restricted"); return }
        provider.status = .authorized
        provider.servicesOn = false
        attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.servicesDisabled) = attempt else { Issue.record("expected servicesDisabled"); return }
        #expect(stamps == 0)
    }

    @Test func featureTurnedOffIsRespectedBeforeAnythingElse() async {
        let attempt = await service.verify(destination: destination, store: store, featureEnabled: false)
        guard case .failure(.featureDisabled) = attempt else { Issue.record("expected featureDisabled"); return }
        #expect(provider.promptCount == 0 && provider.readingRequests == 0)
    }

    @Test func permissionIsRequestedOnlyWhenNotDetermined() async {
        provider.status = .notDetermined
        provider.statusAfterPrompt = .authorized
        provider.result = .success(nearReading())
        _ = await service.verify(destination: destination, store: store, featureEnabled: true)
        #expect(provider.promptCount == 1)

        provider.status = .authorized
        _ = await service.verify(destination: Fixture.catalog.destination(id: "b")!, store: store, featureEnabled: true)
        #expect(provider.promptCount == 1, "An already-authorised device is never prompted again")
    }

    @Test func deniedAtThePromptIsHandled() async {
        provider.status = .notDetermined
        provider.statusAfterPrompt = .denied
        let attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.permissionDenied) = attempt else { Issue.record("expected denied"); return }
    }

    @Test func timeoutAndProviderErrorsBecomeFailures() async {
        provider.result = .failure(.timeout)
        var attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.timeout) = attempt else { Issue.record("expected timeout"); return }
        provider.result = .failure(.unavailable)
        attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.unavailable) = attempt else { Issue.record("expected unavailable"); return }
        #expect(stamps == 0)
    }

    @Test func staleAndInaccurateReadingsAreRejectedByThePolicy() async {
        provider.result = .success(LocationReading(latitude: destination.latitude, longitude: destination.longitude, horizontalAccuracy: 10, timestamp: now.addingTimeInterval(-600)))
        var attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.staleReading) = attempt else { Issue.record("expected stale"); return }
        provider.result = .success(LocationReading(latitude: destination.latitude, longitude: destination.longitude, horizontalAccuracy: 800, timestamp: now))
        attempt = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .failure(.poorAccuracy) = attempt else { Issue.record("expected poor accuracy"); return }
        #expect(stamps == 0)
    }

    @Test func repeatingAVerificationIsIdempotent() async {
        provider.result = .success(nearReading())
        _ = await service.verify(destination: destination, store: store, featureEnabled: true)
        let again = await service.verify(destination: destination, store: store, featureEnabled: true)
        guard case .success(.alreadyVerified) = again else { Issue.record("expected alreadyVerified"); return }
        #expect(stamps == 1)
    }
}
