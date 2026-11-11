import SwiftUI
import Observation

struct SearchIndexUnavailable: Error {}

/// The Search screen's state: the text, the scope chips and the results. Typing is debounced (150 ms), the lookup runs off
/// the main actor, every keystroke cancels the previous search, and a result that arrives late is dropped, so a stale
/// result can never replace a newer one.
@MainActor
@Observable
final class DiscoverSearchModel {
    enum Scope: String, CaseIterable, Identifiable {
        case all, places, landmarks, collections
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: String(localized: "All")
            case .places: String(localized: "Places")
            case .landmarks: String(localized: "Landmarks")
            case .collections: String(localized: "Collections")
            }
        }
    }

    enum Phase: Equatable {
        /// Nothing typed: Recent and Try.
        case idle
        case results(DiscoverSearchResults)
        case noResults
        /// The index could not be opened. Never shown as an empty result list.
        case unavailable
    }

    typealias Searcher = @Sendable (DiscoverSearchIndex, String) async -> DiscoverSearchResults

    private(set) var text = ""
    var scope: Scope = .all
    private(set) var phase: Phase = .idle
    private(set) var ideas: [String] = []
    /// The query the current `phase` answers (for highlighting).
    private(set) var answeredQuery = ""

    private let catalog: Catalog
    private let makeIndex: () throws -> DiscoverSearchIndex
    private let searcher: Searcher
    private let debounce: Duration
    private let announce: (String) -> Void
    private var index: DiscoverSearchIndex?
    private var task: Task<Void, Never>?
    private var generation = 0

    init(catalog: Catalog, debounce: Duration = .milliseconds(150),
         makeIndex: (() throws -> DiscoverSearchIndex)? = nil,
         searcher: @escaping Searcher = DiscoverSearchModel.backgroundSearch,
         announce: @escaping (String) -> Void = DiscoverSearchModel.voiceOverAnnouncement) {
        self.catalog = catalog
        self.debounce = debounce
        self.makeIndex = makeIndex ?? { Self.defaultIndex(for: catalog) }
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

    private static var hasFailedOnce = false

    private static func defaultIndex(for catalog: Catalog) -> DiscoverSearchIndex {
        DiscoverSearchIndex.shared(for: catalog)
    }

    /// Opens the index. On failure the screen shows the error state with "Try again".
    func prepare() {
        do {
            #if DEBUG
            if LaunchConfiguration.current.searchFailsOnce, !Self.hasFailedOnce { Self.hasFailedOnce = true; throw SearchIndexUnavailable() }
            #endif
            let built = try makeIndex()
            index = built
            ideas = DiscoverIdeas.make(catalog: catalog, index: built)
            if phase == .unavailable { phase = .idle }
            if !text.isEmpty { schedule(immediate: true) }
        } catch {
            index = nil
            ideas = []
            phase = .unavailable
        }
    }

    // MARK: Text

    /// Typing: results follow after the debounce.
    func setText(_ new: String, immediate: Bool = false) {
        guard new != text else { return }
        text = new
        schedule(immediate: immediate)
    }

    /// A term from Recent or an idea chip: runs now, without waiting for the debounce.
    func run(term: String) { setText(term, immediate: true) }

    func clear() { setText("", immediate: true) }

    /// The arrow on a Recent row: puts the term in the field without searching.
    func insert(_ term: String) {
        task?.cancel()
        generation += 1
        text = term
        answeredQuery = ""
        if phase != .unavailable { phase = .idle }
    }

    /// The Search key: shows the results for the current text now, without waiting for the debounce.
    func flush() { if !text.trimmingCharacters(in: .whitespaces).isEmpty { schedule(immediate: true) } }

    private func schedule(immediate: Bool) {
        task?.cancel()
        generation += 1
        let mine = generation
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            if phase != .unavailable { phase = .idle }
            answeredQuery = ""
            task = nil
            return
        }
        guard let index else { phase = .unavailable; return }
        let wait = immediate ? Duration.zero : debounce
        task = Task { [searcher] in
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard !Task.isCancelled, mine == generation else { return }
            let found = await searcher(index, query)
            // A newer keystroke has started another search: this answer is stale and is dropped.
            guard !Task.isCancelled, mine == generation else { return }
            answeredQuery = query
            phase = found.isEmpty ? .noResults : .results(found)
            announce(found.isEmpty ? String(localized: "No results") : String(localized: "\(found.count) results"))
        }
    }

    /// Waits for the search of the latest keystroke (for tests).
    func settle() async { await task?.value }

    // MARK: Derived

    func results(in scope: Scope) -> DiscoverSearchResults {
        guard case .results(let all) = phase else { return DiscoverSearchResults() }
        switch scope {
        case .all: return all
        case .places: return DiscoverSearchResults(places: all.places)
        case .landmarks: return DiscoverSearchResults(landmarks: all.landmarks)
        case .collections: return DiscoverSearchResults(collections: all.collections)
        }
    }
}
