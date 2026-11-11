import Foundation
import Observation
import OSLog
import UIKit

/// Where the paywall sends the person next.
enum PlusRouteAction: Equatable {
    /// Onboarding ends. `entitled` is whether Plus is active.
    case finish(entitled: Bool)
    /// Close without Plus: the exit sheet (or, once it has been shown, finish). Not latched: "See Plus again" comes back here.
    case exit
}

/// State machine of the Plus paywall: loading, ready (a selection), purchasing, succeeded, pending or unavailable, plus an inline
/// notice for a failed purchase or restore. It knows nothing about the holder's name.
@MainActor
@Observable
final class PlusViewModel {
    enum Phase: Equatable { case loading, unavailable, ready, purchasing, succeeded(PlusContent.Success), pending }
    enum Notice: Equatable { case purchaseFailed, nothingToRestore, restoreFailed }
    struct Announcement: Equatable {
        let id: Int
        let text: String
        var isHighPriority = false
    }

    private(set) var phase = Phase.loading
    private(set) var products: [PlusProduct] = []
    private(set) var selected = PlusPlanKind.yearly
    private(set) var notice: Notice?
    private(set) var isRestoring = false
    private(set) var isEntitled = false
    /// Notification authorization was already granted when the screen loaded (and still is after a trial purchase).
    private(set) var canRemind = false
    /// Counters the view turns into haptics.
    private(set) var successCount = 0
    private(set) var failureCount = 0
    private(set) var announcement: Announcement?

    let perks: [PlusPerk]
    private let client: SubscriptionClient
    private let reminders: ReminderService
    private let now: () -> Date
    private let calendar: Calendar
    private let locale: Locale
    private let sleeper: (Duration) async throws -> Void
    private let isVoiceOverRunning: () -> Bool
    private let markOfferShown: () -> Void
    private let onRoute: (PlusRouteAction) -> Void
    private var didAppear = false
    private var didRoute = false
    private let log = Logger(subsystem: "app.stampquest.ios", category: "plus")

    /// Seconds the success banner stays before onboarding ends (longer with VoiceOver, so the announcement is heard).
    static let successHold: Duration = .seconds(2)
    static let successHoldVoiceOver: Duration = .seconds(4)

    init(client: SubscriptionClient, reminders: ReminderService, perks: [PlusPerk] = PlusPerk.available(), now: @escaping () -> Date = { .now },
         calendar: Calendar = .current, locale: Locale = .current,
         sleeper: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
         isVoiceOverRunning: @escaping () -> Bool = { UIAccessibility.isVoiceOverRunning },
         markOfferShown: @escaping () -> Void, onRoute: @escaping (PlusRouteAction) -> Void) {
        self.client = client
        self.reminders = reminders
        self.perks = perks
        self.now = now
        self.calendar = calendar
        self.locale = locale
        self.sleeper = sleeper
        self.isVoiceOverRunning = isVoiceOverRunning
        self.markOfferShown = markOfferShown
        self.onRoute = onRoute
    }

    // MARK: Derived

    /// What the screen says; nil until plans are loaded.
    var content: PlusContent? {
        guard !products.isEmpty else { return nil }
        return PlusContent(products: products, selected: selected, canRemind: canRemind, now: now(), calendar: calendar, locale: locale)
    }

    var selectedProduct: PlusProduct? { products.first { $0.kind == selected } }
    /// Plans can be changed and the CTA pressed.
    var isInteractive: Bool { phase == .ready && !isRestoring }

    // MARK: Lifecycle

    /// Records that the paywall was shown (once), skips the screen for someone who already has Plus, otherwise loads plans.
    func appeared() async {
        guard !didAppear else { return }
        didAppear = true
        markOfferShown()
        await load()
    }

    func retryTapped() async {
        guard phase == .unavailable else { return }
        await load()
    }

    private func load() async {
        phase = .loading
        if await client.isEntitled() {
            isEntitled = true
            route(.finish(entitled: true))
            return
        }
        canRemind = await reminders.canDeliver()
        do {
            products = try await client.loadProducts()
        } catch {
            products = []
        }
        guard !products.isEmpty else { phase = .unavailable; return }
        if !products.contains(where: { $0.kind == selected }), let first = products.first { selected = first.kind }
        phase = .ready
    }

    /// A purchase approved elsewhere (Ask to Buy) or a renewal arrives: Plus applies, and a waiting screen finishes.
    func observeUpdates() async {
        for await _ in client.updates() {
            guard await client.isEntitled() else { continue }
            isEntitled = true
            if phase == .pending { await succeed(.subscribed, product: nil) }
        }
    }

    // MARK: Actions

    func select(_ kind: PlusPlanKind) {
        guard isInteractive, kind != selected, products.contains(where: { $0.kind == kind }) else { return }
        selected = kind
        notice = nil
        if let content, let plan = content.plans.first(where: { $0.kind == kind }) {
            announce(String(localized: "onboarding.plus.a11y.selected \(plan.title) \(content.ctaTitle)"))
        }
    }

    func purchaseTapped() async {
        guard isInteractive, let product = selectedProduct else { return }
        phase = .purchasing
        notice = nil
        let outcome: PurchaseOutcome
        do { outcome = try await client.purchase(product) } catch {
            phase = .ready
            fail(.purchaseFailed)
            return
        }
        switch outcome {
        case .cancelled: phase = .ready
        case .pending:
            phase = .pending
            announce(String(localized: "onboarding.plus.banner.pending"), high: true)
        case .purchased: await succeed(product.eligibleTrial != nil ? .trial : .subscribed, product: product)
        }
    }

    func restoreTapped() async {
        guard (phase == .ready || phase == .unavailable), !isRestoring else { return }
        isRestoring = true
        notice = nil
        defer { isRestoring = false }
        do {
            if try await client.restore() { await succeed(.restored, product: nil) } else {
                notice = .nothingToRestore
                announce(String(localized: "onboarding.plus.restore.none"))
            }
        } catch {
            fail(.restoreFailed)
        }
    }

    /// Close is never blocked or delayed: with Plus (or after a success) onboarding ends, while waiting for approval it ends free,
    /// otherwise the exit screen opens.
    func closeTapped() {
        switch phase {
        case .succeeded: route(.finish(entitled: true))
        case .pending: route(.finish(entitled: isEntitled))
        default: route(isEntitled ? .finish(entitled: true) : .exit)
        }
    }

    // MARK: Internals

    private func succeed(_ kind: PlusContent.Success, product: PlusProduct?) async {
        phase = .succeeded(kind)
        isEntitled = true
        successCount += 1
        announce(PlusContent.banner(kind), high: true)
        if kind == .trial, let product { canRemind = await scheduleReminder(for: product) }
        try? await sleeper(isVoiceOverRunning() ? Self.successHoldVoiceOver : Self.successHold)
        route(.finish(entitled: true))
    }

    /// Only after a trial really started, and only when notifications are already allowed: this never asks for permission.
    private func scheduleReminder(for product: PlusProduct) async -> Bool {
        guard await reminders.canDeliver(), let plan = PlusContent.reminder(for: product, start: now(), calendar: calendar) else { return false }
        do {
            try await reminders.schedule(id: PlusContent.reminderID, at: plan.date, title: plan.title, body: plan.body)
            return true
        } catch {
            log.error("Could not schedule the trial reminder")
            return false
        }
    }

    private func fail(_ notice: Notice) {
        self.notice = notice
        failureCount += 1
        announce(notice.text)
    }

    private func announce(_ text: String, high: Bool = false) {
        announcement = Announcement(id: (announcement?.id ?? 0) + 1, text: text, isHighPriority: high)
    }

    private func route(_ action: PlusRouteAction) {
        if action == .exit { return onRoute(action) }
        guard !didRoute else { return }
        didRoute = true
        onRoute(action)
    }
}

extension PlusViewModel.Notice {
    var text: String {
        switch self {
        case .purchaseFailed: String(localized: "onboarding.plus.error.purchase")
        case .nothingToRestore: String(localized: "onboarding.plus.restore.none")
        case .restoreFailed: String(localized: "onboarding.plus.restore.failed")
        }
    }
}
