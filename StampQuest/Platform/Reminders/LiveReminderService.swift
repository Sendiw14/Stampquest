import Foundation
import UserNotifications

/// `UNUserNotificationCenter` reminders. Read-only about permission: it never calls `requestAuthorization`.
@MainActor
final class LiveReminderService: ReminderService {
    private let center = UNUserNotificationCenter.current()

    func canDeliver() async -> Bool { Self.isAllowed(await center.notificationSettings().authorizationStatus) }

    func schedule(id: String, at date: Date, title: String, body: String) async throws {
        guard Self.isAllowed(await center.notificationSettings().authorizationStatus) else { throw ReminderError.unavailable }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        try await center.add(UNNotificationRequest(identifier: id, content: content,
                                                   trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
    }

    func cancel(id: String) async { center.removePendingNotificationRequests(withIdentifiers: [id]) }

    private static func isAllowed(_ status: UNAuthorizationStatus) -> Bool { status == .authorized || status == .provisional }
}
