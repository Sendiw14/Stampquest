import SwiftUI

/// A perforated stamp of any size: paper border, an artwork window with a keyline, a caption band, paper grain and an
/// optional diagonal sheen. The static layers are flattened once (`drawingGroup`), so moving a card moves a bitmap.
struct StampCard<Art: View, Caption: View>: View {
    let size: CGSize
    let paper: Color
    /// Distance between perforation notches in points.
    let pitch: CGFloat
    var borderRatio: CGFloat = 0.072
    var minBorder: CGFloat = 0
    var captionRatio: CGFloat = 0.15
    var minCaption: CGFloat = 0
    var grainOpacity = 0.16
    /// Width in points of one repeat of the grain texture.
    var grainTile: CGFloat = 256
    var staticSheen = true
    @ViewBuilder let art: Art
    /// Receives the size of the caption band.
    @ViewBuilder let caption: (CGSize) -> Caption

    @Environment(\.colorSchemeContrast) private var contrast

    /// Artwork window and caption band, in the card's own coordinates.
    static func layout(size: CGSize, borderRatio: CGFloat = 0.072, minBorder: CGFloat = 0, captionRatio: CGFloat = 0.15,
                       minCaption: CGFloat = 0) -> (art: CGRect, caption: CGRect) {
        let border = max(minBorder, size.width * borderRatio)
        let band = max(minCaption, size.height * captionRatio)
        let art = CGRect(x: border, y: border, width: size.width - border * 2, height: size.height - border - band)
        return (art, CGRect(x: art.minX, y: art.maxY, width: art.width, height: band))
    }

    var body: some View {
        let frame = Self.layout(size: size, borderRatio: borderRatio, minBorder: minBorder, captionRatio: captionRatio,
                                minCaption: minCaption)
        let shape = FixedPitchPerforatedShape(pitch: pitch, notchRatio: 0.29)
        ZStack(alignment: .topLeading) {
            shape.fill(paper)
            shape.fill(LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.06)], startPoint: .topLeading,
                                      endPoint: .bottomTrailing))
            art
                .frame(width: frame.art.width, height: frame.art.height)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 1.5).stroke(.black.opacity(contrast == .increased ? 0.5 : 0.28), lineWidth: 1)
                }
                .offset(x: frame.art.minX, y: frame.art.minY)
            caption(frame.caption.size)
                .frame(width: frame.caption.width, height: frame.caption.height)
                .offset(x: frame.caption.minX, y: frame.caption.minY)
            grain
            if staticSheen {
                LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.15), .init(color: .white.opacity(0.22), location: 0.5),
                                       .init(color: .white.opacity(0), location: 0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blendMode(.overlay)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .drawingGroup()
    }

    @ViewBuilder
    private var grain: some View {
        if let image = GrainNoise.image {
            Image(decorative: image, scale: CGFloat(GrainNoise.tileSize) / grainTile)
                .resizable(resizingMode: .tile)
                .opacity(grainOpacity)
                .blendMode(.multiply)
        }
    }
}

extension StampCard where Caption == EmptyView {
    init(size: CGSize, paper: Color, pitch: CGFloat, borderRatio: CGFloat = 0.072, minBorder: CGFloat = 0,
         captionRatio: CGFloat = 0.15, minCaption: CGFloat = 0, grainOpacity: Double = 0.16, grainTile: CGFloat = 256,
         staticSheen: Bool = true, @ViewBuilder art: () -> Art) {
        self.init(size: size, paper: paper, pitch: pitch, borderRatio: borderRatio, minBorder: minBorder,
                  captionRatio: captionRatio, minCaption: minCaption, grainOpacity: grainOpacity, grainTile: grainTile,
                  staticSheen: staticSheen, art: art, caption: { _ in EmptyView() })
    }
}
