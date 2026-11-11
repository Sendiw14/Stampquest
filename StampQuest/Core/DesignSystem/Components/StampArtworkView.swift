import SwiftUI
import UIKit

/// Renders the illustration for one stamp.
///
/// If the catalog supplies `assetName` and the image exists in the asset catalog,
/// that painted artwork is used. Otherwise the vector illustration engine draws
/// the scene. Either way the view fills its frame; the frame decides the crop.
struct StampArtworkView: View {
    let spec: ArtworkSpec
    /// Stable seed so a given stamp always renders identically.
    let seed: UInt64

    init(spec: ArtworkSpec, seedKey: String) {
        self.spec = spec
        self.seed = ArtRandom.seed(from: seedKey)
    }

    var body: some View {
        if let name = spec.assetName, UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
        } else {
            Canvas { context, size in
                ArtScene.draw(spec: spec, seed: seed, in: &context, size: size)
            }
        }
    }
}
