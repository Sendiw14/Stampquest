import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A person's own backup of their passport.
///
/// Privacy by default: journal text, captions and trip notes are **excluded** unless the
/// person explicitly includes them. Photo files are never embedded in any case.
struct PassportExport: Codable, Equatable {
    struct Stamp: Codable, Equatable {
        var destinationID: String
        var title: String
        var countryCode: String
        var collectedAt: Date
        var verified: Bool
        var verifiedAt: Date?
        var isFavorite: Bool
        var tripID: UUID?
        /// Only present when private notes are included.
        var caption: String?
    }
    struct Wish: Codable, Equatable { var destinationID: String; var addedAt: Date }
    struct TripEntry: Codable, Equatable {
        var id: UUID
        var title: String
        var startDate: Date?
        var endDate: Date?
        var destinationIDs: [String]
        var notes: String?
    }
    struct Memory: Codable, Equatable {
        var id: UUID
        var title: String
        var text: String
        var eventDate: Date
        var destinationID: String?
        var tags: [String]
        var photoCount: Int
    }

    var format = "stampquest.passport"
    var version = 1
    var exportedAt: Date
    var catalogVersion: String
    var includesPrivateNotes: Bool
    var stamps: [Stamp]
    var wishlist: [Wish]
    var trips: [TripEntry]
    var memoryCount: Int
    /// nil unless private notes were included.
    var memories: [Memory]?
}

struct ExportOptions: Equatable {
    /// Memory text, stamp captions and trip notes. Off by default.
    var includePrivateNotes = false
}

enum PassportExporter {
    @MainActor
    static func make(stamps: [UserStamp], wishlist: [WishlistItem], trips: [Trip], memories: [MemoryEntry],
                     catalogVersion: String, options: ExportOptions = .init(), now: Date = .now) -> PassportExport {
        let priv = options.includePrivateNotes
        return PassportExport(
            exportedAt: now, catalogVersion: catalogVersion, includesPrivateNotes: priv,
            stamps: stamps.sorted { $0.collectedAt < $1.collectedAt }.map {
                .init(destinationID: $0.destinationID, title: $0.titleSnapshot, countryCode: $0.countryCodeSnapshot,
                      collectedAt: $0.collectedAt, verified: $0.isVerified, verifiedAt: $0.verification?.verifiedAt,
                      isFavorite: $0.isFavorite, tripID: $0.tripID, caption: priv ? $0.caption : nil)
            },
            wishlist: wishlist.sorted { $0.addedAt < $1.addedAt }.map { .init(destinationID: $0.destinationID, addedAt: $0.addedAt) },
            trips: trips.sorted { $0.createdAt < $1.createdAt }.map {
                .init(id: $0.id, title: $0.title, startDate: $0.startDate, endDate: $0.endDate,
                      destinationIDs: $0.destinationIDs, notes: priv ? $0.notes : nil)
            },
            memoryCount: memories.count,
            memories: priv ? memories.sorted { $0.eventDate < $1.eventDate }.map {
                .init(id: $0.id, title: $0.title, text: $0.text, eventDate: $0.eventDate,
                      destinationID: $0.destinationID, tags: $0.tags, photoCount: $0.photoFilenames.count)
            } : nil)
    }

    static func encode(_ export: PassportExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }
}

/// Shares the export as a JSON file via the system share sheet. The data is produced at
/// the moment the person chooses to share, not before.
struct PassportExportFile: Transferable {
    let makeData: @MainActor @Sendable () throws -> Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            try await file.makeData()
        }
        .suggestedFileName("StampQuest Passport.json")
    }
}
