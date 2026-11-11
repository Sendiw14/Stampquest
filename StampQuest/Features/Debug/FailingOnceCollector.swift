#if DEBUG
import Foundation

/// Wraps a collector so its first `collect` throws and every later one is delegated. Selected by `-simulateCollectFailure`.
@MainActor
final class FailingOnceCollector: StampCollecting {
    struct SimulatedFailure: Error {}

    private let base: StampCollecting
    private var hasFailed = false

    init(wrapping base: StampCollecting) { self.base = base }

    func collect(_ destination: StampDestination) async throws -> UserStamp {
        guard hasFailed else {
            hasFailed = true
            throw SimulatedFailure()
        }
        return try await base.collect(destination)
    }

    func existing(_ destination: StampDestination) -> UserStamp? { base.existing(destination) }
}
#endif
