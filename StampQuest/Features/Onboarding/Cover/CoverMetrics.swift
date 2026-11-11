import CoreGraphics

/// Every number of the Cover screen that is not a colour, in points of the 402 x 874 reference. Pure.
nonisolated enum CoverMetrics {
    /// The cover is drawn in this design space.
    static let designSize = CGSize(width: 222, height: 304)
    /// The page block sticks out of the cover's frame by this much.
    static let pageBlockExtent = CGSize(width: 10, height: 7)
    static let heroWidth: CGFloat = 206
    static let pitch: CGFloat = 170
    static let neighbourScale: CGFloat = 0.728
    /// Fraction of the screen width, on each side, over which the neighbours fade out.
    static let edgeFade: CGFloat = 0.22
    static let heroHeight: CGFloat = 282
    static let minHeroScale: CGFloat = 0.78
    static let keyboardHeroScale: CGFloat = 0.72

    static let miniSize = CGSize(width: 36, height: 50)
    static let miniGap: CGFloat = 20
    static let ringSize = CGSize(width: 46, height: 60)
    static let nameLimit = 24

    /// Design units to points for a cover `width` points wide.
    static func unit(forWidth width: CGFloat) -> CGFloat { width / designSize.width }

    /// Frame of a cover group at `width`, with or without the page block.
    static func groupSize(width: CGFloat, showsPageBlock: Bool) -> CGSize {
        let unit = unit(forWidth: width)
        let extent = showsPageBlock ? pageBlockExtent : .zero
        return CGSize(width: (designSize.width + extent.width) * unit, height: (designSize.height + extent.height) * unit)
    }

    /// Pose of a cover at signed `distance` from the centre, in pitches: 1 at the centre, `neighbourScale` one pitch away.
    static func scale(atDistance distance: CGFloat) -> CGFloat { 1 - (1 - neighbourScale) * min(1, abs(distance)) }
    /// 0 at the centre, 1 one pitch away.
    static func blend(atDistance distance: CGFloat) -> CGFloat { min(1, abs(distance)) }
    /// The page block is fully there at the centre and gone half a pitch away.
    static func pageBlockOpacity(atDistance distance: CGFloat) -> CGFloat { max(0, 1 - abs(distance) * 2) }

    /// Font size of the holder's name on the cover: 14 up to 14 characters, 14 x 14 / count beyond, never below 8.5.
    static func nameFontSize(characterCount count: Int) -> CGFloat {
        count <= 14 ? 14 : max(8.5, 14 * 14 / CGFloat(count))
    }

    /// Left edge of swatch `index` in the dock.
    static func swatchOffset(_ index: Int) -> CGFloat { CGFloat(index) * (miniSize.width + miniGap) }
}
