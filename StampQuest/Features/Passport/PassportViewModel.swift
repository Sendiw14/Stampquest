import Foundation
import Observation

enum PassportLayout: String, CaseIterable, Identifiable {
    case grid, pages, list

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .grid: "Grid"
        case .pages: "Pages"
        case .list: "List"
        }
    }
}

/// The groups of the Sort & filter sheet, so a ticket cell can open the sheet scrolled to one.
enum PassportFilterGroup: String, Hashable {
    case sort, show, country, collection
}

/// Holds what the screen keeps beyond the records: the query (sort and filters), the layout, and the remove/undo state.
/// Sort and layout persist across launches; filters never do, so the screen always opens unfiltered.
@MainActor
@Observable
final class PassportViewModel {
    var query: PassportQuery { didSet { if query.sort != oldValue.sort { defaults.set(query.sort.rawValue, forKey: Key.sort) } } }
    var layout: PassportLayout { didSet { defaults.set(layout.rawValue, forKey: Key.layout) } }
    /// The stamp the person asked to remove; the confirmation dialog is up while this is set.
    var pendingRemoval: PassportEntry?
    /// Just removed: the toast offers Undo for `undoWindow` seconds.
    private(set) var removed: StampBackup?
    var errorMessage: String?

    static let undoWindow: Duration = .seconds(6)

    private let env: AppEnvironment
    private let defaults: UserDefaults
    private var undoTask: Task<Void, Never>?

    enum Key {
        static let sort = "passport.sort"
        static let layout = "passport.layout"
    }

    init(env: AppEnvironment, defaults: UserDefaults = .standard) {
        self.env = env
        self.defaults = defaults
        query = PassportQuery(sort: defaults.string(forKey: Key.sort).flatMap(PassportSort.init(rawValue:)) ?? .recentlyCollected)
        layout = defaults.string(forKey: Key.layout).flatMap(PassportLayout.init(rawValue:)) ?? .grid
    }

    /// Forget the saved sort and layout (`-uitest-reset`).
    static func eraseStoredState(_ defaults: UserDefaults) {
        for key in [Key.sort, Key.layout] { defaults.removeObject(forKey: key) }
    }

    // MARK: Filters

    func select(_ layout: PassportLayout) {
        guard layout != self.layout else { return }
        env.haptics.selection()
        self.layout = layout
    }

    func setSort(_ sort: PassportSort) {
        guard sort != query.sort else { return }
        env.haptics.selection()
        query.sort = sort
    }

    /// Verified filter on, or off when it is already on (ticket "verified").
    func toggleVerifiedFilter() {
        env.haptics.selection()
        query.onlyVerified.toggle()
    }

    func toggleFilter(_ kind: PassportFilterChip.Kind) {
        env.haptics.selection()
        switch kind {
        case .verified: query.onlyVerified.toggle()
        case .favorites: query.onlyFavorites.toggle()
        case .country(let code): if !query.countryCodes.insert(code).inserted { query.countryCodes.remove(code) }
        case .collection(let id): if !query.collectionIDs.insert(id).inserted { query.collectionIDs.remove(id) }
        }
    }

    func resetAll() {
        env.haptics.selection()
        query = PassportQuery()
    }

    // MARK: Favorite, remove, undo

    func toggleFavorite(_ entry: PassportEntry) {
        do {
            try env.store.setFavorite(destinationID: entry.destinationID, !entry.isFavorite)
            env.haptics.selection()
        } catch { errorMessage = (error as? PassportError)?.errorDescription }
    }

    func requestRemoval(_ entry: PassportEntry) { pendingRemoval = entry }

    func confirmRemoval() {
        guard let entry = pendingRemoval else { return }
        pendingRemoval = nil
        do {
            guard let backup = try env.store.removeStamp(destinationID: entry.destinationID) else { return }
            removed = backup
            undoTask?.cancel()
            undoTask = Task { [weak self] in
                try? await Task.sleep(for: Self.undoWindow)
                guard !Task.isCancelled else { return }
                self?.removed = nil
            }
        } catch { errorMessage = (error as? PassportError)?.errorDescription }
    }

    func undoRemoval() {
        guard let backup = removed else { return }
        undoTask?.cancel()
        removed = nil
        do { try env.store.restoreStamp(backup) } catch { errorMessage = (error as? PassportError)?.errorDescription }
    }

    /// The name for the toast: the snapshot taken when the stamp was collected, or the catalogue name.
    func removedName(catalog: Catalog) -> String? {
        removed.map { catalog.destination(id: $0.destinationID)?.name ?? $0.titleSnapshot }
    }
}
