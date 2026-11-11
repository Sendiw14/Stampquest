import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// A 256 x 256 tileable, desaturated noise, generated once and cached.
enum GrainNoise {
    static let tileSize = 256
    static let image: CGImage? = make()

    private static func make() -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: tileSize, height: tileSize)
        guard let noise = CIFilter.randomGenerator().outputImage else { return nil }
        let gray = noise.cropped(to: rect).applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        return CIContext().createCGImage(gray, from: rect)
    }
}

/// Paper grain overlay: light .05 multiply, dark .04 screen. Skipped under Reduce Transparency.
struct GrainTexture: View {
    var lightOpacity = 0.05
    var darkOpacity = 0.04

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if !reduceTransparency, let grain = GrainNoise.image {
            Image(decorative: grain, scale: 2)
                .resizable(resizingMode: .tile)
                .opacity(scheme == .dark ? darkOpacity : lightOpacity)
                .blendMode(scheme == .dark ? .screen : .multiply)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Screen background: `paper` plus grain.
struct PaperBackground: View {
    var body: some View {
        OBColor.paper
            .overlay { GrainTexture() }
            .ignoresSafeArea()
    }
}

#Preview("PaperBackground") { PreviewMatrix { PaperBackground().frame(height: 120) } }
