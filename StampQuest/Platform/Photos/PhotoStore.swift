import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum PhotoStoreError: Error, LocalizedError {
    case unreadable
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "That photo couldn’t be read.")
        case .writeFailed: String(localized: "The photo couldn’t be saved.")
        }
    }
}

/// Stores the photos attached to memories inside the app's own container.
///
/// - Photos are downsampled to at most 2,048 px on the long edge and re-encoded as
///   JPEG. Re-encoding drops EXIF metadata (including GPS), so a memory never leaks
///   where a photo was taken.
/// - Decoding and encoding happen off the main actor.
/// - Thumbnails are decoded at display size and cached with a memory limit.
@MainActor
final class PhotoStore: PhotoFileDeleting {
    private let directory: URL
    private let cache = NSCache<NSString, UIImage>()

    init(directory: URL = StoragePaths.photosDirectory) {
        self.directory = directory
        cache.totalCostLimit = 48 * 1024 * 1024
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for filename: String) -> URL { directory.appendingPathComponent(filename) }

    func exists(_ filename: String) -> Bool { FileManager.default.fileExists(atPath: url(for: filename).path) }

    /// Saves a picked photo and returns its file name.
    func importPhoto(data: Data) async throws -> String {
        let filename = UUID().uuidString + ".jpg"
        let destination = url(for: filename)
        try await Self.writeDownsampled(data: data, to: destination, maxPixel: 2048)
        return filename
    }

    /// A display-sized image, or nil if the file is missing or unreadable (e.g. deleted).
    func thumbnail(for filename: String, maxPixel: Int) async -> UIImage? {
        let key = "\(filename)@\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let url = url(for: filename)
        guard let image = await Self.decodeThumbnail(at: url, maxPixel: maxPixel) else { return nil }
        cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
        return image
    }

    nonisolated func deletePhotos(named filenames: [String]) {
        let directory = self.directory
        for name in filenames {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        Task { @MainActor [weak self] in self?.cache.removeAllObjects() }
    }

    /// Removes files in the photos directory that no memory refers to.
    func removeOrphans(keeping referenced: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !referenced.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    // MARK: Off-main-actor image work

    @concurrent
    private static func writeDownsampled(data: Data, to url: URL, maxPixel: Int) async throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw PhotoStoreError.unreadable }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw PhotoStoreError.unreadable }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoStoreError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoStoreError.writeFailed }
    }

    @concurrent
    private static func decodeThumbnail(at url: URL, maxPixel: Int) async -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}
