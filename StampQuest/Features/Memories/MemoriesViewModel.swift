import SwiftUI
import SwiftData
import Observation

/// Hand-offs between screens that do not share a view: Detail asks the timeline to filter by a tag, and the Memories
/// search asks Discover to run a place query. Only a tag or a query term is ever passed, never memory text.
@MainActor
@Observable
final class MemoryNavigation {
    static let shared = MemoryNavigation()
    var pendingTag: String?
    /// "Memories here" on Stamp detail: show the timeline filtered to this place.
    var pendingPlaceID: String?
    var pendingDiscoverQuery: String?
}

/// The Memories search: debounced (150 ms), off the main actor, cancelled on every keystroke, and a late answer is dropped,
/// so a stale result can never replace a newer one.
@MainActor
@Observable
final class MemorySearchModel {
    enum Phase: Equatable {
        case idle
        case results([UUID])
        case noResults
    }

    typealias Searcher = @Sendable (MemorySearchIndex, String) async -> [UUID]

    private(set) var text = ""
    private(set) var phase: Phase = .idle
    /// The query the current `phase` answers (for highlighting).
    private(set) var answeredQuery = ""
    private(set) var index: MemorySearchIndex

    private let searcher: Searcher
    private let debounce: Duration
    private let announce: (String) -> Void
    private var task: Task<Void, Never>?
    private var generation = 0

    init(index: MemorySearchIndex = MemorySearchIndex(items: [], catalog: .empty), debounce: Duration = .milliseconds(150),
         searcher: @escaping Searcher = MemorySearchModel.backgroundSearch,
         announce: @escaping (String) -> Void = MemorySearchModel.voiceOverAnnouncement) {
        self.index = index
        self.debounce = debounce
        self.searcher = searcher
        self.announce = announce
    }

    static let backgroundSearch: Searcher = { index, query in
        await Task.detached(priority: .userInitiated) { index.search(query) }.value
    }

    static let voiceOverAnnouncement: (String) -> Void = { message in
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// A new index after the memories changed; the current query is answered again.
    func setIndex(_ new: MemorySearchIndex) {
        index = new
        if !text.trimmingCharacters(in: .whitespaces).isEmpty { schedule(immediate: true) }
    }

    func setText(_ new: String, immediate: Bool = false) {
        guard new != text else { return }
        text = new
        schedule(immediate: immediate)
    }

    func run(term: String) { setText(term, immediate: true) }
    func clear() { setText("", immediate: true) }

    /// The Search key: results now, without waiting for the debounce.
    func flush() { if !text.trimmingCharacters(in: .whitespaces).isEmpty { schedule(immediate: true) } }

    /// Puts a term in the field without searching.
    func insert(_ term: String) {
        task?.cancel()
        generation += 1
        text = term
        answeredQuery = ""
        phase = .idle
    }

    private func schedule(immediate: Bool) {
        task?.cancel()
        generation += 1
        let mine = generation
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            phase = .idle
            answeredQuery = ""
            task = nil
            return
        }
        let wait = immediate ? Duration.zero : debounce
        let index = index
        task = Task { [searcher] in
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard !Task.isCancelled, mine == generation else { return }
            let found = await searcher(index, query)
            guard !Task.isCancelled, mine == generation else { return }
            answeredQuery = query
            phase = found.isEmpty ? .noResults : .results(found)
            announce(found.isEmpty ? String(localized: "No memories found") : String(localized: "\(found.count) memories found"))
        }
    }

    /// Waits for the search of the latest keystroke (for tests).
    func settle() async { await task?.value }
}

/// Actions of the Memories tab: delete, recent searches. What the screen shows comes from `MemoryDerived` and the records.
@MainActor
@Observable
final class MemoriesViewModel {
    var errorMessage: String?

    private let env: AppEnvironment

    init(env: AppEnvironment) { self.env = env }

    func entry(_ id: UUID) -> MemoryEntry? {
        var descriptor = FetchDescriptor<MemoryEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? env.store.context.fetch(descriptor))?.first
    }

    /// Deletes only the memory and the app's private copies of its photos. Call after the person confirmed.
    @discardableResult
    func delete(_ id: UUID) -> Bool {
        guard let entry = entry(id) else { return false }
        do {
            try env.store.deleteMemory(entry)
            env.toasts.show(String(localized: "Memory deleted"))
            return true
        } catch {
            errorMessage = (error as? PassportError)?.errorDescription ?? String(localized: "Your memory couldn’t be deleted.")
            return false
        }
    }

    func noteSearch(_ term: String) { env.preferences.noteMemorySearch(term) }

    func clearRecentSearches() {
        let before = env.preferences.recentMemorySearches
        guard !before.isEmpty else { return }
        env.preferences.clearRecentMemorySearches()
        env.toasts.show(String(localized: "Cleared")) { [prefs = env.preferences] in prefs.restoreRecentMemorySearches(before) }
    }
}
