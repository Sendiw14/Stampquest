import SwiftUI

/// The stamp of one interest: a `StampCard` in its pastel with the interest's artwork in the window. The ghost
/// version is grey and faint, for the empty slot.
struct InterestStampView: View {
    let interest: Interest
    var isGhost = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        StampCard(size: InterestsMetrics.stampSize, paper: interest.paper, pitch: InterestsMetrics.stampPitch,
                  minBorder: InterestsMetrics.stampMinBorder, minCaption: InterestsMetrics.stampMinCaption,
                  grainOpacity: InterestsMetrics.grainOpacity, grainTile: InterestsMetrics.grainTile, staticSheen: false) {
            InterestArt(interest: interest)
        }
        .grayscale(isGhost ? 1 : 0)
        .opacity(isGhost ? (contrast == .increased ? InterestsMetrics.ghostOpacityIncreasedContrast : InterestsMetrics.ghostOpacity) : 1)
    }
}
