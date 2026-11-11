import Foundation

/// Local reminders that back the "We remind you" claim on the Plus screen. The app never asks for notification permission
/// here: `canDeliver` only reads the current status, and `schedule` refuses when notifications are not already allowed.
@MainActor
protocol ReminderService {
    /// True only when a reminder can really be delivered: notification authorization is already authorized or provisional.
    func canDeliver() async -> Bool
    func schedule(id: String, at date: Date, title: String, body: String) async throws
    func cancel(id: String) async
}

nonisolated enum ReminderError: Error, Equatable { case unavailable }

@MainActor
struct UnavailableReminderService: ReminderService {
    func canDeliver() async -> Bool { false }
    func schedule(id: String, at date: Date, title: String, body: String) async throws { throw ReminderError.unavailable }
    func cancel(id: String) async {}
}

@MainActor
final class MockReminderService: ReminderService {
    struct Scheduled: Equatable { let id: String; let date: Date; let title: String; let body: String }

    var isAuthorized = true
    private(set) var scheduled: [Scheduled] = []
    private(set) var cancelled: [String] = []

    func canDeliver() async -> Bool { isAuthorized }

    func schedule(id: String, at date: Date, title: String, body: String) async throws {
        guard isAuthorized else { throw ReminderError.unavailable }
        scheduled.removeAll { $0.id == id }
        scheduled.append(Scheduled(id: id, date: date, title: title, body: body))
    }

    func cancel(id: String) async {
        cancelled.append(id)
        scheduled.removeAll { $0.id == id }
    }
}
