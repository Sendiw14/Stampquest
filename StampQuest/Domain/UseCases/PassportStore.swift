import Foundation
import SwiftData
import OSLog

enum PassportError: Error, LocalizedError, Equatable {
    case unknownDestination(String)
    case saveFailed
    case invalidTrip(String)
    case invalidMemory(String)

    var errorDescription: String? {
        switch self {
        case .unknownDestination:
            String(localized: "That place is no longer in the catalog.")
        case .saveFailed:
            String(localized: "Your change couldn’t be saved, so nothing was changed. Please try again.")
        case .invalidTrip(let reason), .invalidMemory(let reason):
            reason
        }
    }
}

/// Removes stored photo files when the memory that owns them is deleted.
protocol PhotoFileDeleting {
    func deletePhotos(named filenames: [String])
}

struct NoPhotoFiles: PhotoFileDeleting {
    func deletePhotos(named filenames: [String]) {}
}

enum CollectOutcome {
    /// A new stamp was added to the passport.
    case collected(UserStamp)
    /// The stamp was already in the passport; nothing changed.
    case alreadyCollected(UserStamp)

    var stamp: UserStamp {
        switch self {
        case .collected(let s), .alreadyCollected(let s): s
        }
    }
    var isNew: Bool { if case .collected = self { true } else { false } }
}

enum VerificationOutcome {
    /// The destination had no stamp; a verified stamp was created.
    case collectedAndVerified(UserStamp)
    /// An existing manually collected stamp was upgraded to a verified visit.
    case upgraded(UserStamp)
    /// The stamp was already verified; nothing changed.
    case alreadyVerified(UserStamp)

    var stamp: UserStamp {
        switch self {
        case .collectedAndVerified(let s), .upgraded(let s), .alreadyVerified(let s): s
        }
    }
}

/// Everything needed to put a removed stamp back (powers Undo).
struct StampBackup: Sendable {
    let stampID: String
    let destinationID: String
    let titleSnapshot: String
    let countryCodeSnapshot: String
    let collectedAt: Date
    let method: CollectionMethod
    let verification: VisitVerification?
    let tripID: UUID?
    let isFavorite: Bool
    let caption: String?
}

struct MemoryDraft {
    var title: String = ""
    var text: String = ""
    var eventDate: Date = Calendar.current.startOfDay(for: .now)
    var destinationID: String?
    var stampID: String?
    var tripID: UUID?
    var tags: [String] = []
    var photoFilenames: [String] = []
}

struct TripDraft {
    var title: String = ""
    var startDate: Date?
    var endDate: Date?
    var notes: String = ""
    var destinationIDs: [String] = []
}

/// The single place where passport business rules are enforced.
///
/// Rules (all covered by tests):
/// - Collecting is idempotent: one stamp per destination, ever.
/// - Manual collection never implies a verified visit; verification is a separate fact.
/// - Verifying an existing stamp upgrades it in place; it never duplicates it.
/// - A wishlist entry is not a collected stamp; collecting clears the wishlist entry.
/// - Failed saves roll back, so memory never disagrees with the database.
/// - Deleting a memory or a trip never deletes stamps; deleting a trip detaches
///   its stamps and memories rather than destroying them.
@MainActor
final class PassportStore {
    let context: ModelContext
    let catalog: Catalog
    private let now: () -> Date
    private let photoFiles: PhotoFileDeleting
    private let log = Logger(subsystem: "app.stampquest.ios", category: "passport")

    init(context: ModelContext, catalog: Catalog, photoFiles: PhotoFileDeleting = NoPhotoFiles(),
         now: @escaping () -> Date = { .now }) {
        self.context = context
        self.catalog = catalog
        self.photoFiles = photoFiles
        self.now = now
    }

    // MARK: Reads

    func stamp(forDestination id: String) -> UserStamp? {
        var descriptor = FetchDescriptor<UserStamp>(predicate: #Predicate { $0.destinationID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func isWishlisted(_ id: String) -> Bool {
        var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.destinationID == id })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func state(of id: String) -> StampState {
        if let stamp = stamp(forDestination: id) { return stamp.state }
        return isWishlisted(id) ? .wishlisted : .notCollected
    }

    func snapshot() -> PassportSnapshot {
        let stamps = (try? context.fetch(FetchDescriptor<UserStamp>())) ?? []
        let wishlist = (try? context.fetch(FetchDescriptor<WishlistItem>())) ?? []
        let memories = (try? context.fetch(FetchDescriptor<MemoryEntry>())) ?? []
        let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        return PassportSnapshot(userStamps: stamps, wishlist: wishlist, memories: memories, trips: trips)
    }

    // MARK: Collecting

    /// Adds the destination's stamp to the passport without any location check.
    @discardableResult
    func collect(destinationID: String) throws -> CollectOutcome {
        let destination = try requireDestination(destinationID)
        if let existing = stamp(forDestination: destinationID) { return .alreadyCollected(existing) }
        let stamp = UserStamp(stampID: destination.stampID, destinationID: destination.id,
                              titleSnapshot: destination.name, countryCodeSnapshot: destination.countryCode,
                              collectedAt: now(), method: .manual)
        context.insert(stamp)
        deleteWishlistItem(destinationID)
        try commit()
        log.notice("Collected stamp \(destinationID, privacy: .public)")
        return .collected(stamp)
    }

    /// Records a successful verification. Call only after the verification policy accepted the reading.
    @discardableResult
    func recordVerification(destinationID: String, verification: VisitVerification) throws -> VerificationOutcome {
        let destination = try requireDestination(destinationID)
        if let existing = stamp(forDestination: destinationID) {
            if existing.verification != nil { return .alreadyVerified(existing) }
            existing.verification = verification
            try commit()
            return .upgraded(existing)
        }
        let stamp = UserStamp(stampID: destination.stampID, destinationID: destination.id,
                              titleSnapshot: destination.name, countryCodeSnapshot: destination.countryCode,
                              collectedAt: now(), method: .verified, verification: verification)
        context.insert(stamp)
        deleteWishlistItem(destinationID)
        try commit()
        return .collectedAndVerified(stamp)
    }

    /// Removes a stamp from the passport and returns what is needed to undo it.
    @discardableResult
    func removeStamp(destinationID: String) throws -> StampBackup? {
        guard let stamp = stamp(forDestination: destinationID) else { return nil }
        let backup = StampBackup(stampID: stamp.stampID, destinationID: stamp.destinationID,
                                 titleSnapshot: stamp.titleSnapshot, countryCodeSnapshot: stamp.countryCodeSnapshot,
                                 collectedAt: stamp.collectedAt, method: stamp.method, verification: stamp.verification,
                                 tripID: stamp.tripID, isFavorite: stamp.isFavorite, caption: stamp.caption)
        context.delete(stamp)
        try commit()
        return backup
    }

    /// Puts a removed stamp back exactly as it was. No-op if the destination is already collected.
    func restoreStamp(_ backup: StampBackup) throws {
        guard stamp(forDestination: backup.destinationID) == nil else { return }
        let stamp = UserStamp(stampID: backup.stampID, destinationID: backup.destinationID,
                              titleSnapshot: backup.titleSnapshot, countryCodeSnapshot: backup.countryCodeSnapshot,
                              collectedAt: backup.collectedAt, method: backup.method, verification: backup.verification)
        stamp.tripID = backup.tripID
        stamp.isFavorite = backup.isFavorite
        stamp.caption = backup.caption
        context.insert(stamp)
        try commit()
    }

    func setFavorite(destinationID: String, _ value: Bool) throws {
        guard let stamp = stamp(forDestination: destinationID), stamp.isFavorite != value else { return }
        stamp.isFavorite = value
        try commit()
    }

    func setCaption(destinationID: String, _ caption: String?) throws {
        guard let stamp = stamp(forDestination: destinationID) else { return }
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        stamp.caption = (trimmed?.isEmpty ?? true) ? nil : trimmed
        try commit()
    }

    func setTrip(destinationID: String, tripID: UUID?) throws {
        guard let stamp = stamp(forDestination: destinationID), stamp.tripID != tripID else { return }
        stamp.tripID = tripID
        try commit()
    }

    // MARK: Wishlist

    /// Saves a place for later. Returns false (and changes nothing) if it is already
    /// collected or already saved: a wishlist entry never shadows a collected stamp.
    @discardableResult
    func addToWishlist(destinationID: String) throws -> Bool {
        _ = try requireDestination(destinationID)
        guard stamp(forDestination: destinationID) == nil, !isWishlisted(destinationID) else { return false }
        context.insert(WishlistItem(destinationID: destinationID, addedAt: now()))
        try commit()
        return true
    }

    /// When the place was saved, so Undo can put it back with its original date.
    func wishlistDate(_ id: String) -> Date? {
        var descriptor = FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.destinationID == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.addedAt
    }

    /// Puts a removed wishlist entry back with its original saved date. Does nothing if the place is collected or saved.
    @discardableResult
    func restoreWishlistItem(destinationID: String, addedAt: Date) throws -> Bool {
        _ = try requireDestination(destinationID)
        guard stamp(forDestination: destinationID) == nil, !isWishlisted(destinationID) else { return false }
        context.insert(WishlistItem(destinationID: destinationID, addedAt: addedAt))
        try commit()
        return true
    }

    @discardableResult
    func removeFromWishlist(destinationID: String) throws -> Bool {
        guard isWishlisted(destinationID) else { return false }
        deleteWishlistItem(destinationID)
        try commit()
        return true
    }

    // MARK: Memories

    @discardableResult
    func saveMemory(_ draft: MemoryDraft, replacing existing: MemoryEntry? = nil) throws -> MemoryEntry {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !text.isEmpty || !draft.photoFilenames.isEmpty else {
            throw PassportError.invalidMemory(String(localized: "Add a title, some words or a photo to save this memory."))
        }
        // A memory may keep pointing at a place that has since left the catalog (rule 9), so editing it must still save.
        if let id = draft.destinationID, catalog.destination(id: id) == nil, id != existing?.destinationID {
            throw PassportError.unknownDestination(id)
        }
        let tags = draft.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let uniqueTags = Array(NSOrderedSet(array: tags)) as? [String] ?? tags

        let memory: MemoryEntry
        var removedPhotos: [String] = []
        if let existing {
            memory = existing
            removedPhotos = existing.photoFilenames.filter { !draft.photoFilenames.contains($0) }
            memory.updatedAt = now()
        } else {
            memory = MemoryEntry(title: title, text: text, createdAt: now(), eventDate: draft.eventDate)
            context.insert(memory)
        }
        memory.title = title
        memory.text = text
        memory.eventDate = draft.eventDate
        memory.destinationID = draft.destinationID
        memory.stampID = draft.stampID
        memory.tripID = draft.tripID
        memory.tags = uniqueTags
        memory.photoFilenames = draft.photoFilenames
        try commit()
        if !removedPhotos.isEmpty { photoFiles.deletePhotos(named: removedPhotos) }
        return memory
    }

    /// Deletes a memory and its photos. Never touches stamps or trips.
    func deleteMemory(_ memory: MemoryEntry) throws {
        let photos = memory.photoFilenames
        context.delete(memory)
        try commit()
        photoFiles.deletePhotos(named: photos)
    }

    // MARK: Trips

    @discardableResult
    func saveTrip(_ draft: TripDraft, replacing existing: Trip? = nil) throws -> Trip {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        try TripRules.validate(title: title, start: draft.startDate, end: draft.endDate)
        for id in draft.destinationIDs where catalog.destination(id: id) == nil { throw PassportError.unknownDestination(id) }
        let trip: Trip
        if let existing { trip = existing } else {
            trip = Trip(title: title, createdAt: now())
            context.insert(trip)
        }
        trip.title = title
        trip.startDate = draft.startDate
        trip.endDate = draft.endDate
        trip.notes = draft.notes
        trip.destinationIDs = draft.destinationIDs.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        try commit()
        return trip
    }

    /// Deletes only the trip. Its stamps and memories are detached, not removed.
    func deleteTrip(_ trip: Trip) throws {
        let id = trip.id
        let stamps = (try? context.fetch(FetchDescriptor<UserStamp>(predicate: #Predicate { $0.tripID == id }))) ?? []
        let memories = (try? context.fetch(FetchDescriptor<MemoryEntry>(predicate: #Predicate { $0.tripID == id }))) ?? []
        stamps.forEach { $0.tripID = nil }
        memories.forEach { $0.tripID = nil }
        context.delete(trip)
        try commit()
    }

    // MARK: Data management

    /// Permanently deletes every user record and stored photo. Catalogue data is untouched.
    func deleteAllData() throws {
        let memories = (try? context.fetch(FetchDescriptor<MemoryEntry>())) ?? []
        let photos = memories.flatMap(\.photoFilenames)
        try context.delete(model: UserStamp.self)
        try context.delete(model: WishlistItem.self)
        try context.delete(model: MemoryEntry.self)
        try context.delete(model: Trip.self)
        try commit()
        photoFiles.deletePhotos(named: photos)
    }

    // MARK: Internals

    private func requireDestination(_ id: String) throws -> Destination {
        guard let destination = catalog.destination(id: id) else { throw PassportError.unknownDestination(id) }
        return destination
    }

    private func deleteWishlistItem(_ id: String) {
        let items = (try? context.fetch(FetchDescriptor<WishlistItem>(predicate: #Predicate { $0.destinationID == id }))) ?? []
        items.forEach(context.delete)
    }

    /// Saves, rolling back on failure so callers never see a half-applied change.
    private func commit() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            log.error("Save failed: \(error.localizedDescription, privacy: .public)")
            throw PassportError.saveFailed
        }
    }
}

enum TripRules {
    static func validate(title: String, start: Date?, end: Date?) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PassportError.invalidTrip(String(localized: "Give your trip a name."))
        }
        if let start, let end, end < start {
            throw PassportError.invalidTrip(String(localized: "The trip can’t end before it starts."))
        }
    }
}
