import Testing
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers
@testable import StampQuest

@MainActor
struct PhotoStoreTests {
    let directory: URL
    let store: PhotoStore

    init() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("sq-photos-\(UUID().uuidString)")
        store = PhotoStore(directory: directory)
    }

    /// A large JPEG that carries GPS metadata, like a photo straight from a camera.
    private func makeGeotaggedJPEG(width: Int, height: Int) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        }
        let data = NSMutableData()
        let dest = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 48.8584, kCGImagePropertyGPSLatitudeRef: "N",
                                    kCGImagePropertyGPSLongitude: 2.2945, kCGImagePropertyGPSLongitudeRef: "E"]
        CGImageDestinationAddImage(dest, try #require(image.cgImage), [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        #expect(CGImageDestinationFinalize(dest))
        return data as Data
    }

    @Test func importDownsamplesAndStripsLocationMetadata() async throws {
        let original = try makeGeotaggedJPEG(width: 4000, height: 3000)
        // Sanity: the fixture really contains GPS data.
        let originalSource = try #require(CGImageSourceCreateWithData(original as CFData, nil))
        let originalProps = try #require(CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) as? [CFString: Any])
        #expect(originalProps[kCGImagePropertyGPSDictionary] != nil)

        let name = try await store.importPhoto(data: original)
        #expect(name.hasSuffix(".jpg") && store.exists(name))

        let source = try #require(CGImageSourceCreateWithURL(store.url(for: name) as CFURL, nil))
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let w = try #require(props[kCGImagePropertyPixelWidth] as? Int), h = try #require(props[kCGImagePropertyPixelHeight] as? Int)
        #expect(max(w, h) <= 2048, "Stored photos are downsampled")
        #expect(props[kCGImagePropertyGPSDictionary] == nil, "Location metadata must not survive import")
    }

    @Test func unreadableDataIsRejectedWithoutLeavingAFile() async {
        await #expect(throws: PhotoStoreError.self) { try await store.importPhoto(data: Data("not an image".utf8)) }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        #expect(files.isEmpty)
    }

    @Test func thumbnailsAreDecodedAtDisplaySizeAndMissingFilesReturnNil() async throws {
        let name = try await store.importPhoto(data: try makeGeotaggedJPEG(width: 3000, height: 2000))
        let thumb = try #require(await store.thumbnail(for: name, maxPixel: 300))
        #expect(max(thumb.size.width * thumb.scale, thumb.size.height * thumb.scale) <= 300.5)
        #expect(await store.thumbnail(for: "missing.jpg", maxPixel: 300) == nil, "A missing/revoked photo degrades gracefully")
    }

    @Test func deletingAndOrphanCleanupRemoveFiles() async throws {
        let keep = try await store.importPhoto(data: try makeGeotaggedJPEG(width: 800, height: 600))
        let drop = try await store.importPhoto(data: try makeGeotaggedJPEG(width: 800, height: 600))
        let orphan = try await store.importPhoto(data: try makeGeotaggedJPEG(width: 800, height: 600))
        store.deletePhotos(named: [drop])
        #expect(!store.exists(drop) && store.exists(keep))
        store.removeOrphans(keeping: [keep])
        #expect(store.exists(keep) && !store.exists(orphan))
        try? FileManager.default.removeItem(at: directory)
    }
}
