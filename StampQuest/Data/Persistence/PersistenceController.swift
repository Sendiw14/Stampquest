import Foundation
import SwiftData
import OSLog

/// Where user data lives on disk.
enum StoragePaths {
    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("StampQuest", isDirectory: true)
    }
    static var storeURL: URL { applicationSupport.appendingPathComponent("Passport.store") }
    static var photosDirectory: URL { applicationSupport.appendingPathComponent("MemoryPhotos", isDirectory: true) }
    static var backupsDirectory: URL { applicationSupport.appendingPathComponent("Backups", isDirectory: true) }

    static func ensureDirectories() throws {
        for url in [applicationSupport, photosDirectory] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

enum PersistenceError: Error, LocalizedError {
    case cannotOpenStore(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpenStore(let detail):
            String(localized: "Your passport data could not be opened. Nothing has been deleted. \(detail)")
        }
    }
}

/// Builds the SwiftData container and handles the case where an existing store
/// cannot be opened. Migration or open failures **never** delete data: the store is
/// left untouched, and the person can retry or move it aside as a backup.
enum PersistenceController {
    private static let log = Logger(subsystem: "app.stampquest.ios", category: "persistence")

    static let schema = Schema(versionedSchema: StampQuestSchemaV2.self)

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        do {
            let configuration: ModelConfiguration
            if inMemory {
                configuration = ModelConfiguration("Passport", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            } else {
                try StoragePaths.ensureDirectories()
                configuration = ModelConfiguration("Passport", schema: schema, url: url ?? StoragePaths.storeURL, cloudKitDatabase: .none)
            }
            return try ModelContainer(for: schema, migrationPlan: StampQuestMigrationPlan.self, configurations: [configuration])
        } catch {
            log.error("Could not open store: \(error.localizedDescription, privacy: .public)")
            throw PersistenceError.cannotOpenStore(error.localizedDescription)
        }
    }

    /// Moves the store files into a timestamped backup folder so a fresh store can be
    /// created. The old files are preserved, never removed.
    @discardableResult
    static func moveStoreToBackup(url: URL = StoragePaths.storeURL, backupsRoot: URL = StoragePaths.backupsDirectory,
                                  now: Date = .now) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: now).replacingOccurrences(of: ":", with: "-")
        let folder = backupsRoot.appendingPathComponent(stamp, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            if FileManager.default.fileExists(atPath: source.path) {
                try FileManager.default.moveItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
            }
        }
        log.notice("Moved unreadable store to backup folder")
        return folder
    }

    /// Removes every store file. Only used by the explicit "delete all my data" action
    /// and by tests; never as a recovery path.
    static func eraseStoreFiles(url: URL = StoragePaths.storeURL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
