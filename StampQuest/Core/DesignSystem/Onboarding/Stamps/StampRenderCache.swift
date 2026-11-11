import SwiftUI

/// Renders a bare stamp to an image once per (stamp, width, scale) so trays, stacks and animations move an
/// image instead of redrawing the Canvas every frame.
@MainActor
final class StampRenderCache {
    static let shared = StampRenderCache()

    private struct Key: Hashable { let id: String; let width: CGFloat; let scale: CGFloat }
    private var images: [Key: UIImage] = [:]

    func image(for destination: StampDestination, width: CGFloat, scale: CGFloat) -> UIImage? {
        let key = Key(id: destination.id, width: width, scale: scale)
        if let hit = images[key] { return hit }
        let renderer = ImageRenderer(content: StampView(destination: destination, width: width, showsShadow: false))
        renderer.scale = scale
        renderer.isOpaque = false
        guard let image = renderer.uiImage else { return nil }
        images[key] = image
        return image
    }

    func removeAll() { images.removeAll() }
    var count: Int { images.count }
}
