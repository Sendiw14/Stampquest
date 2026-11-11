import SwiftUI

/// A stamp for the Welcome fan: a `StampCard` with the stamp's artwork and a serif caption.
struct FanStampView: View {
    let stamp: WelcomeStamp

    var body: some View {
        let size = stamp.slot.frame.size
        StampCard(size: size, paper: stamp.paper, pitch: size.width / 12) {
            artwork
        } caption: { band in
            SerifStampCaption(label: stamp.label, number: stamp.number, stampWidth: size.width, band: band)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        switch stamp.art {
        case .onboarding(let style): StampArtCanvas(style: style)
        case .catalog(let design): StampArtworkView(spec: design.artwork, seedKey: design.id)
        }
    }
}
