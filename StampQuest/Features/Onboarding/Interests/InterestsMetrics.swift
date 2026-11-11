import CoreGraphics

/// Every number of the Interests screen, in points of the 402 x 874 reference.
nonisolated enum InterestsMetrics {
    static let stampSize = CGSize(width: 84, height: 106)
    static let stampPitch: CGFloat = 8
    static let stampMinBorder: CGFloat = 9
    static let stampMinCaption: CGFloat = 24
    static let grainOpacity = 0.26
    static let grainTile: CGFloat = 128

    static let sideMargin: CGFloat = 24
    static let contentMaxWidth: CGFloat = 520
    static let topBarTop: CGFloat = 2
    static let headlineTop: CGFloat = 6
    static let headlineSize: CGFloat = 40
    static let headlineLineHeight: CGFloat = 44
    static let subtitleTop: CGFloat = 16
    static let subtitleMaxWidth: CGFloat = 340
    static let pageTop: CGFloat = 20
    static let pageMargin: CGFloat = 20
    static let pageCorner: CGFloat = 20
    static let pagePadding: CGFloat = 17
    static let gridTop: CGFloat = 40
    static let cellHeight: CGFloat = 172
    static let labelGap: CGFloat = 7
    static let counterTop: CGFloat = 14
    static let ctaBottomGap: CGFloat = 28

    static let slotLineWidth: CGFloat = 1.5
    static let slotDash: [CGFloat] = [3, 4]
    static let slotOpacity = 0.6
    static let ghostOpacity = 0.30
    static let ghostOpacityIncreasedContrast = 0.45
    static let selectedScale: CGFloat = 1.04
    static let selectedTilt: Double = 2
    static let badgeSize: CGFloat = 24
    static let badgeInset = CGSize(width: 17, height: 9)
    static let postmarkSize: CGFloat = 54
    static let postmarkOffset = CGSize(width: 42, height: 45)
    static let postmarkRotation: Double = 14

    /// Width of the passport page on a screen `width` points wide.
    static func pageWidth(screenWidth width: CGFloat) -> CGFloat { min(width, contentMaxWidth) - pageMargin * 2 }

    static func columnWidth(pageWidth: CGFloat, columns: Int) -> CGFloat { (pageWidth - pagePadding * 2) / CGFloat(columns) }

    /// Scale of a stamp in a column of `columnWidth`: down to fit a narrow phone, up to 1.2x on a wide screen.
    static func stampScale(columnWidth: CGFloat) -> CGFloat {
        min(1.2, columnWidth / 109)
    }

    /// Tilt of a selected stamp: -2 degrees for even positions, +2 for odd.
    static func tilt(forIndex index: Int) -> Double { index.isMultiple(of: 2) ? -selectedTilt : selectedTilt }
}
