import SwiftUI
import UIKit
import Testing

/// Draws a SwiftUI view in a real window of the host app's scene (so ScrollView, sheets' content and safe areas lay out as on device) and
/// saves or compares PNGs under `StampQuestTests/Snapshots`. A missing image is written; an existing one must match within a small
/// tolerance. `RECORD_SNAPSHOTS=1` rewrites them. These catch layout regressions; they do not replace looking at a device.
@MainActor
enum SnapshotSupport {
    static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Snapshots")

    static func image(of view: some View, size: CGSize, dark: Bool) async throws -> UIImage {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = dark ? .dark : .light
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first, "needs the host app's window scene")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = .alert + 1
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(700))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }

    /// True when every sampled pixel equals the first one.
    static func isBlank(_ image: UIImage) -> Bool {
        guard let data = image.cgImage?.dataProvider?.data as Data?, data.count > 8 else { return true }
        let first = data[0..<3]
        return stride(from: 0, to: data.count - 3, by: 4 * 97).allSatisfy { data[$0..<$0 + 3] == first }
    }

    /// The image as 8-bit sRGB RGBA, so a PNG read from disk and a fresh render compare byte for byte.
    static func pixels(_ image: UIImage) -> [UInt8]? {
        guard let cg = image.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                          space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            return true
        }
        return drawn ? bytes : nil
    }

    /// Mean absolute difference of the red and green channels, 0 (identical) to 1; 1 as well when the sizes differ.
    static func distance(_ a: UIImage, _ b: UIImage) -> Double {
        guard let x = pixels(a), let y = pixels(b), x.count == y.count, !x.isEmpty else { return 1 }
        var total = 0
        for index in stride(from: 0, to: x.count, by: 4) { total += abs(Int(x[index]) - Int(y[index])) + abs(Int(x[index + 1]) - Int(y[index + 1])) }
        return Double(total) / Double(x.count / 4 * 2) / 255
    }

    static func verify(_ image: UIImage, named name: String, size: CGSize) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name + ".png")
        let data = try #require(image.pngData())
        #expect(image.size == size && !isBlank(image), "\(name): the render is empty")
        if !FileManager.default.fileExists(atPath: file.path) || ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" {
            try data.write(to: file)
            return
        }
        let reference = try #require(UIImage(contentsOfFile: file.path))
        let gap = distance(image, reference)
        #expect(gap < 0.01, "\(name) changed by \(gap): re-record with RECORD_SNAPSHOTS=1 if intended")
    }
}
