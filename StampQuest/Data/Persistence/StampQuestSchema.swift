import Foundation
import SwiftData

/// A successful, on-device location check. Only what is needed to explain the
/// result is kept: **no coordinates** are stored, just how far away the person
/// was and how accurate the reading was.
nonisolated struct VisitVerification: Codable, Hashable, Sendable {
    var id: UUID
    var verifiedAt: Date
    /// Distance to the destination's reference point, rounded to whole metres.
    var distanceMeters: Double
    /// Horizontal accuracy of the reading, in metres.
    var horizontalAccuracyMeters: Double
    /// The radius that applied to this destination when verified.
    var radiusMeters: Double
    /// Version of the verification policy that accepted this reading.
    var policyVersion: Int
}

/// Schema version 1 of the user's local data.
///
/// Catalogue content (destinations, stamps, collections) is **not** stored here:
/// user records reference it by stable identifier. Anything snapshotted from the
/// catalogue (`titleSnapshot`, `countryCodeSnapshot`) exists only so a record can
/// still be shown if the catalogue later drops that destination.
///
/// Evolving the schema: add `StampQuestSchemaV2` with its own model copies, list
/// both in `StampQuestMigrationPlan.schemas`, and describe the stage. Never edit
/// V1 models in place once shipped.
enum StampQuestSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [UserStamp.self, WishlistItem.self, MemoryEntry.self, Trip.self]
    }

    @Model
    final class UserStamp {
        /// One record per stamp. Uniqueness is also enforced in `PassportStore`.
        @Attribute(.unique) var stampID: String
        var destinationID: String
        var titleSnapshot: String
        var countryCodeSnapshot: String
        var collectedAt: Date
        var methodRaw: String
        var verification: VisitVerification?
        var tripID: UUID?
        var isFavorite: Bool
        var caption: String?

        init(stampID: String, destinationID: String, titleSnapshot: String, countryCodeSnapshot: String,
             collectedAt: Date, method: CollectionMethod, verification: VisitVerification? = nil) {
            self.stampID = stampID
            self.destinationID = destinationID
            self.titleSnapshot = titleSnapshot
            self.countryCodeSnapshot = countryCodeSnapshot
            self.collectedAt = collectedAt
            self.methodRaw = method.rawValue
            self.verification = verification
            self.tripID = nil
            self.isFavorite = false
            self.caption = nil
        }
    }

    @Model
    final class WishlistItem {
        @Attribute(.unique) var destinationID: String
        var addedAt: Date

        init(destinationID: String, addedAt: Date) {
            self.destinationID = destinationID
            self.addedAt = addedAt
        }
    }

    @Model
    final class MemoryEntry {
        @Attribute(.unique) var id: UUID
        var title: String
        var text: String
        var createdAt: Date
        var updatedAt: Date
        /// The day the memory is about (start of day in the person's calendar).
        var eventDate: Date
        var destinationID: String?
        var stampID: String?
        var tripID: UUID?
        var tags: [String]
        /// File names inside the app's MemoryPhotos directory.
        var photoFilenames: [String]

        init(id: UUID = UUID(), title: String, text: String, createdAt: Date, eventDate: Date,
             destinationID: String? = nil, stampID: String? = nil, tripID: UUID? = nil,
             tags: [String] = [], photoFilenames: [String] = []) {
            self.id = id
            self.title = title
            self.text = text
            self.createdAt = createdAt
            self.updatedAt = createdAt
            self.eventDate = eventDate
            self.destinationID = destinationID
            self.stampID = stampID
            self.tripID = tripID
            self.tags = tags
            self.photoFilenames = photoFilenames
        }
    }

    @Model
    final class Trip {
        @Attribute(.unique) var id: UUID
        var title: String
        var startDate: Date?
        var endDate: Date?
        var notes: String
        var destinationIDs: [String]
        var createdAt: Date

        init(id: UUID = UUID(), title: String, startDate: Date? = nil, endDate: Date? = nil,
             notes: String = "", destinationIDs: [String] = [], createdAt: Date) {
            self.id = id
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.notes = notes
            self.destinationIDs = destinationIDs
            self.createdAt = createdAt
        }
    }
}

typealias UserStamp = StampQuestSchemaV1.UserStamp
typealias WishlistItem = StampQuestSchemaV1.WishlistItem
typealias MemoryEntry = StampQuestSchemaV1.MemoryEntry
typealias Trip = StampQuestSchemaV1.Trip

extension UserStamp {
    var method: CollectionMethod { CollectionMethod(rawValue: methodRaw) ?? .manual }
    var isVerified: Bool { verification != nil }
    var state: StampState { isVerified ? .verified : .collected }
}

/// Schema version 1.1: adds `PassportProfile` (onboarding progress, cover and name). The four V1 models are
/// unchanged, so they are shared with V1 and the migration is a lightweight, additive stage.
enum StampQuestSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] { StampQuestSchemaV1.models + [PassportProfile.self] }

    /// The person's passport: one row, keyed by `Self.primaryKey`.
    @Model
    final class PassportProfile {
        static let primaryKey = "primary"

        @Attribute(.unique) var key: String
        var name: String
        var coverStyleRaw: String
        var interestRaws: [String]
        var verificationRaw: String
        /// Furthest onboarding route reached (`OnboardingRoute.rawValue`); nil means Welcome.
        var reachedRouteRaw: String?
        var createdAt: Date
        var onboardingCompletedAt: Date?
        /// When the "passport ready" screen was first shown; set once.
        var passportIssuedAt: Date?

        init(createdAt: Date) {
            self.key = Self.primaryKey
            self.name = ""
            self.coverStyleRaw = CoverStyle.default.rawValue
            self.interestRaws = []
            self.verificationRaw = VerificationChoice.undecided.rawValue
            self.reachedRouteRaw = nil
            self.createdAt = createdAt
            self.onboardingCompletedAt = nil
            self.passportIssuedAt = nil
        }
    }
}

typealias PassportProfile = StampQuestSchemaV2.PassportProfile

enum StampQuestMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StampQuestSchemaV1.self, StampQuestSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: StampQuestSchemaV1.self, toVersion: StampQuestSchemaV2.self)] }
}
