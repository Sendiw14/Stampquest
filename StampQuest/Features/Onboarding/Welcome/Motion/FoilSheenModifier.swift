import Metal
import SwiftUI

/// A light band that sweeps across a view, clipped to `shape`. Uses the `foilSheen` Metal colour effect and falls back
/// to a gradient band when the app's Metal library or device is unavailable.
nonisolated struct FoilSheenModifier<S: Shape>: ViewModifier {
    /// 0...1 while the band travels, negative while it rests.
    let progress: Double
    let shape: S
    var peak = 0.6
    var warmth = 1.0

    private static var shaderAvailable: Bool { FoilSheen.isShaderAvailable }

    func body(content: Content) -> some View {
        if Self.shaderAvailable {
            content.visualEffect { [progress, peak, warmth] view, proxy in
                view.colorEffect(ShaderLibrary.foilSheen(.float2(proxy.size), .float(progress), .float(peak), .float(warmth)))
            }
        } else {
            content.overlay { fallbackBand }
        }
    }

    private var fallbackBand: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(colors: [.clear, .white.opacity(peak * 0.75), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width * 0.45)
                .rotationEffect(.degrees(20))
                .offset(x: -width * 0.5 + width * 1.5 * CGFloat(max(progress, 0)))
                .opacity(progress < 0 ? 0 : 1)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

nonisolated enum FoilSheen {
    static let isShaderAvailable: Bool = {
        guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else { return false }
        return library.functionNames.contains("foilSheen")
    }()
}

extension View {
    /// `peak` is the band's strength, `warmth` 0...1 how far it shifts from white to gold and pink.
    nonisolated func foilSheen(progress: Double, in shape: some Shape, peak: Double = 0.6, warmth: Double = 1) -> some View {
        modifier(FoilSheenModifier(progress: progress, shape: shape, peak: peak, warmth: warmth))
    }
}
