import Testing
import SwiftUI
import UIKit
@testable import StampQuest

/// Renders the paywall at 402 x 874 in a hosting controller (a real hierarchy, so ScrollView and safe-area insets lay out as on device) and
/// saves a PNG under `StampQuestTests/Snapshots`. A missing image is written; an existing one must match within a small tolerance.
/// Set `RECORD_SNAPSHOTS=1` to rewrite them. These are layout regressions, not a replacement for looking at the device.
@MainActor
@Suite(.serialized)
struct PlusSnapshotTests {
    static let size = CGSize(width: 402, height: 874)
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    enum Scenario: String, CaseIterable {
        case yearly, monthly, success, loading, unavailable, twoStep, noTrial, accessibility3
    }

    func makeView(_ scenario: Scenario) async -> PlusPaywallView {
        let client = FakeSubscriptionClient(products: FakeSubscriptionClient.standardProducts(eligible: scenario != .noTrial))
        let reminders = MockReminderService()
        reminders.isAuthorized = scenario != .twoStep
        if scenario == .unavailable { client.loadError = .unavailable }
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)) ?? .now
        let viewModel = PlusViewModel(client: client, reminders: reminders, now: { date }, calendar: calendar, locale: Locale(identifier: "en_GB"),
                                      sleeper: { _ in try await Task.sleep(for: .seconds(120)) }, isVoiceOverRunning: { false },
                                      markOfferShown: {}, onRoute: { _ in })
        if scenario != .loading { await viewModel.appeared() }
        if scenario == .monthly { viewModel.select(.monthly) }
        if scenario == .success { Task { await viewModel.purchaseTapped() }; await Task.yield() }
        return PlusPaywallView(viewModel: viewModel, holderName: "Alex Rivera", showsFinishedEntrance: true)
    }

    func render(_ scenario: Scenario, dark: Bool) async throws -> UIImage {
        let view = await makeView(scenario)
            .environment(\.obReducesMotion, true)
            .environment(\.locale, Locale(identifier: "en_GB"))
            .environment(\.dynamicTypeSize, scenario == .accessibility3 ? .accessibility3 : .large)
        return try await SnapshotSupport.image(of: view, size: Self.size, dark: dark)
    }

    @Test(arguments: Scenario.allCases, [false, true])
    func snapshot(scenario: Scenario, dark: Bool) async throws {
        try SnapshotSupport.verify(try await render(scenario, dark: dark), named: "plus-\(scenario.rawValue)-\(dark ? "dark" : "light")", size: Self.size)
    }
}
