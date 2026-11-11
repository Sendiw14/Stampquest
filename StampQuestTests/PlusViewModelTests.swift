import Testing
import Foundation
@testable import StampQuest

@MainActor
struct PlusViewModelTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)) ?? .now }

    final class Harness {
        let client: FakeSubscriptionClient
        let reminders = MockReminderService()
        let repository = InMemoryOnboardingRepository()
        var routes: [PlusRouteAction] = []
        var sleeps: [Duration] = []
        var shown = 0
        let model: OnboardingModel
        var viewModel: PlusViewModel!

        init(_ client: FakeSubscriptionClient = FakeSubscriptionClient(), voiceOver: Bool = false, clock: @escaping () -> Date,
             calendar: Calendar, hangs: Bool = false) {
            self.client = client
            let suite = "plus-vm-tests-\(UUID().uuidString)"
            model = OnboardingModel(repository: repository, collector: StubCollector(), purchases: MockPurchaseService(),
                                    flags: FeatureFlags(plusPaywallEnabled: true), now: clock, defaults: UserDefaults(suiteName: suite) ?? .standard,
                                    complete: { _ in })
            viewModel = PlusViewModel(client: client, reminders: reminders, now: clock, calendar: calendar, locale: Locale(identifier: "en_US"),
                                      sleeper: { [unowned self] duration in
                                          sleeps.append(duration)
                                          if hangs { try await Task.sleep(for: .seconds(60)) }
                                      },
                                      isVoiceOverRunning: { voiceOver },
                                      markOfferShown: { [unowned self] in shown += 1; model.markPlusOfferShown() },
                                      onRoute: { [unowned self] in routes.append($0) })
        }
    }

    func harness(_ client: FakeSubscriptionClient = FakeSubscriptionClient(), voiceOver: Bool = false, hangs: Bool = false) -> Harness {
        let date = now
        return Harness(client, voiceOver: voiceOver, clock: { date }, calendar: calendar, hangs: hangs)
    }

    // MARK: Loading

    @Test func loadsIntoReadyWithYearlyPreselected() async {
        let h = harness()
        #expect(h.viewModel.phase == .loading)
        await h.viewModel.appeared()
        #expect(h.viewModel.phase == .ready && h.viewModel.selected == .yearly && h.viewModel.content?.plans.count == 2)
        #expect(h.routes.isEmpty)
    }

    @Test func alreadyEntitledSkipsTheScreen() async {
        let h = harness(FakeSubscriptionClient(entitled: true))
        await h.viewModel.appeared()
        #expect(h.routes == [.finish(entitled: true)] && h.client.loadCount == 0)
    }

    @Test func aLoadFailureIsUnavailableAndRetryRecovers() async {
        let client = FakeSubscriptionClient()
        client.loadError = .unavailable
        let h = harness(client)
        await h.viewModel.appeared()
        #expect(h.viewModel.phase == .unavailable && h.viewModel.content == nil)
        h.viewModel.closeTapped()
        #expect(h.routes == [.exit], "close still works")
        client.loadError = nil
        await h.viewModel.retryTapped()
        #expect(h.viewModel.phase == .ready)
    }

    // MARK: Purchase outcomes

    @Test func cancellingTheSheetReturnsToReadyWithNoError() async {
        let client = FakeSubscriptionClient()
        client.purchaseResult = .success(.cancelled)
        let h = harness(client)
        await h.viewModel.appeared()
        await h.viewModel.purchaseTapped()
        #expect(h.viewModel.phase == .ready && h.viewModel.notice == nil && h.viewModel.failureCount == 0 && h.routes.isEmpty)
    }

    @Test func pendingShowsTheWaitingBannerAndCloseFinishes() async {
        let client = FakeSubscriptionClient()
        client.purchaseResult = .success(.pending)
        let h = harness(client)
        await h.viewModel.appeared()
        await h.viewModel.purchaseTapped()
        #expect(h.viewModel.phase == .pending)
        h.viewModel.closeTapped()
        #expect(h.routes == [.finish(entitled: false)])
    }

    @Test func aPendingPurchaseApprovedLaterAppliesThroughUpdates() async throws {
        let client = FakeSubscriptionClient()
        client.purchaseResult = .success(.pending)
        let h = harness(client)
        await h.viewModel.appeared()
        await h.viewModel.purchaseTapped()
        let listener = Task { await h.viewModel.observeUpdates() }
        await Task.yield()
        client.entitled = true
        client.emitUpdate()
        for _ in 0..<200 where h.routes.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        listener.cancel()
        #expect(h.viewModel.phase == .succeeded(.subscribed) && h.routes == [.finish(entitled: true)])
    }

    @Test func aFailureKeepsThePlansInteractive() async {
        let client = FakeSubscriptionClient()
        client.purchaseResult = .failure(.failed)
        let h = harness(client)
        await h.viewModel.appeared()
        await h.viewModel.purchaseTapped()
        #expect(h.viewModel.phase == .ready && h.viewModel.notice == .purchaseFailed && h.viewModel.failureCount == 1)
        #expect(h.viewModel.notice?.text == "Couldn’t complete the purchase. Try again.")
        h.viewModel.select(.monthly)
        #expect(h.viewModel.selected == .monthly && h.viewModel.notice == nil)
    }

    @Test func successShowsTheBannerThenFinishesAfterTwoSeconds() async {
        let h = harness()
        await h.viewModel.appeared()
        await h.viewModel.purchaseTapped()
        #expect(h.viewModel.phase == .succeeded(.trial) && h.sleeps == [.seconds(2)] && h.routes == [.finish(entitled: true)])
        #expect(PlusContent.banner(.trial) == "Trial started. Welcome to Plus." && h.viewModel.successCount == 1)
    }

    @Test func voiceOverHoldsTheBannerForFourSeconds() async {
        let h = harness(voiceOver: true)
        await h.viewModel.appeared()
        await h.viewModel.purchaseTapped()
        #expect(h.sleeps == [.seconds(4)])
    }

    @Test func aPlanWithoutATrialSaysWelcomeToPlus() async {
        let h = harness()
        await h.viewModel.appeared()
        h.viewModel.select(.monthly)
        await h.viewModel.purchaseTapped()
        #expect(h.viewModel.phase == .succeeded(.subscribed) && PlusContent.banner(.subscribed) == "Welcome to Plus.")
        #expect(h.reminders.scheduled.isEmpty)
    }

    @Test func aDoubleTapBuysOnce() async {
        let client = FakeSubscriptionClient()
        client.purchaseDelay = .milliseconds(40)
        let h = harness(client)
        await h.viewModel.appeared()
        async let first: Void = h.viewModel.purchaseTapped()
        async let second: Void = h.viewModel.purchaseTapped()
        _ = await (first, second)
        #expect(client.purchasedIDs == [PlusProductID.yearly])
    }

    @Test func plansAreLockedWhilePurchasing() async {
        let client = FakeSubscriptionClient()
        client.purchaseDelay = .milliseconds(80)
        let h = harness(client)
        await h.viewModel.appeared()
        let task = Task { await h.viewModel.purchaseTapped() }
        await Task.yield()
        #expect(h.viewModel.phase == .purchasing && !h.viewModel.isInteractive)
        h.viewModel.select(.monthly)
        #expect(h.viewModel.selected == .yearly)
        await task.value
    }

    // MARK: Close

    @Test func closeGoesToTheExitScreenWithoutPlusAndFinishesWithIt() async {
        let h = harness()
        await h.viewModel.appeared()
        h.viewModel.closeTapped()
        #expect(h.routes == [.exit])
        let entitled = harness(FakeSubscriptionClient(entitled: true))
        await entitled.viewModel.appeared()
        entitled.viewModel.closeTapped()
        #expect(entitled.routes == [.finish(entitled: true)], "routed once, on appear")
    }

    @Test func closeDuringTheSuccessBannerFinishesAtOnce() async throws {
        let h = harness(hangs: true)
        await h.viewModel.appeared()
        let task = Task { await h.viewModel.purchaseTapped() }
        for _ in 0..<200 where h.viewModel.phase != .succeeded(.trial) { try await Task.sleep(for: .milliseconds(10)) }
        h.viewModel.closeTapped()
        #expect(h.routes == [.finish(entitled: true)])
        task.cancel()
        await task.value
        #expect(h.routes.count == 1, "the delayed route does not fire a second time")
    }

    // MARK: Restore

    @Test func restoreWithNothingShowsTheMessage() async {
        let h = harness()
        await h.viewModel.appeared()
        await h.viewModel.restoreTapped()
        #expect(h.viewModel.notice == .nothingToRestore && h.viewModel.notice?.text == "No purchases to restore." && h.routes.isEmpty)
    }

    @Test func restoreThatFindsPlusRoutesOn() async {
        let h = harness(FakeSubscriptionClient(restoreResult: true))
        await h.viewModel.appeared()
        await h.viewModel.restoreTapped()
        #expect(h.viewModel.phase == .succeeded(.restored) && PlusContent.banner(.restored) == "Plus restored." && h.routes == [.finish(entitled: true)])
    }

    @Test func aFailedRestoreSaysSo() async {
        let h = harness(FakeSubscriptionClient(restoreResult: nil))
        await h.viewModel.appeared()
        await h.viewModel.restoreTapped()
        #expect(h.viewModel.notice == .restoreFailed && h.viewModel.failureCount == 1)
    }

    // MARK: Reminder

    @Test func theReminderIsScheduledOnlyAfterATrialPurchaseWithPermissionAlreadyGranted() async throws {
        let h = harness()
        h.reminders.isAuthorized = true
        await h.viewModel.appeared()
        #expect(h.reminders.scheduled.isEmpty, "nothing before the purchase")
        await h.viewModel.purchaseTapped()
        let item = try #require(h.reminders.scheduled.first)
        #expect(item.id == "plus.trial.reminder" && item.date == calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 10)))
    }

    @Test func withoutPermissionNothingIsScheduledAndTheTimelineHasTwoSteps() async {
        let h = harness()
        h.reminders.isAuthorized = false
        await h.viewModel.appeared()
        #expect(h.viewModel.content?.steps.count == 2)
        await h.viewModel.purchaseTapped()
        #expect(h.reminders.scheduled.isEmpty && h.viewModel.canRemind == false)
    }

    @Test func theTimelineHasThreeStepsOnlyWithPermissionInPlace() async {
        let h = harness()
        await h.viewModel.appeared()
        #expect(h.viewModel.content?.steps.count == 3)
    }

    // MARK: Writes and privacy

    @Test func theOnlyWriteIsPlusOfferShownAtAndOnlyOnce() async {
        let h = harness()
        let before = h.repository.stored
        await h.viewModel.appeared()
        await h.viewModel.appeared()
        #expect(h.model.plusOfferShownAt == now && h.shown == 1)
        #expect(h.repository.stored == before, "the passport store is not written by the paywall")
    }

    @Test func theHolderNameNeverLeavesTheScreenModel() async {
        let h = harness()
        h.model.coverName = "Alex Rivera"
        await h.viewModel.appeared()
        await h.viewModel.purchaseTapped()
        let spoken = h.reminders.scheduled.flatMap { [$0.title, $0.body] } + (h.viewModel.content.map { [$0.ctaTitle] + $0.finePrint } ?? [])
        #expect(!spoken.joined().contains("Alex") && h.client.purchasedIDs == [PlusProductID.yearly])
    }
}
