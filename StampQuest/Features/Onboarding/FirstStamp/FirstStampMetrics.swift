import CoreGraphics
import Foundation

/// Every number of the First stamp screen, in points of the 402 pt wide design canvas. The "desk" is the block from
/// the top of the tilted passport page down to the name pills; its coordinates start at the page's top edge.
nonisolated enum FirstStampMetrics {
    static let canvasWidth: CGFloat = 402
    static let deskHeight: CGFloat = 456
    static let scaleRange: ClosedRange<CGFloat> = 0.82...1.2
    static let contentMaxWidth: CGFloat = 520
    static let headlineSize: CGFloat = 36
    static let headlineLineHeight: CGFloat = 40
    static let headlineTop: CGFloat = 4
    static let subtitleTop: CGFloat = 12
    static let deskTop: CGFloat = 52
    static let noteTop: CGFloat = 4
    static let ctaBottomGap: CGFloat = 36

    // MARK: Page and slots

    static let pageFrame = CGRect(x: 14, y: 0, width: 374, height: 262)
    static let pageTilt: Double = -2.2
    static let pageNumberKey = "onboarding.firstStamp.page.number"
    static let slotSize = CGSize(width: 82, height: 102)
    static let slotPitch: CGFloat = 8
    static let slotColumns = 3
    static let slotCount = 6
    static let slotLeft: CGFloat = 17
    static let firstRowTop: CGFloat = 38
    static let rowPitch: CGFloat = 114
    static let hotLineWidth: CGFloat = 1.7
    static let slotLineWidth: CGFloat = 1.4
    static let slotDash: [CGFloat] = [3, 4]
    static let hotStarRadius: CGFloat = 11

    static var columnWidth: CGFloat { (pageFrame.width - 34) / CGFloat(slotColumns) }

    /// Slot `index` (0 is the hot slot) in the page's own coordinates, before the tilt.
    static func slotFrame(_ index: Int) -> CGRect {
        let column = index % slotColumns, row = index / slotColumns
        return CGRect(x: slotLeft + CGFloat(column) * columnWidth + (columnWidth - slotSize.width) / 2,
                      y: firstRowTop + CGFloat(row) * rowPitch, width: slotSize.width, height: slotSize.height)
    }

    /// Centre of slot `index` in desk coordinates: the page tilts about its centre.
    static func slotCenter(_ index: Int, tilt degrees: Double = pageTilt) -> CGPoint {
        let center = CGPoint(x: pageFrame.midX, y: pageFrame.midY)
        let local = slotFrame(index)
        let dx = local.midX + pageFrame.minX - center.x, dy = local.midY + pageFrame.minY - center.y
        let angle = degrees * .pi / 180
        return CGPoint(x: center.x + dx * cos(angle) - dy * sin(angle), y: center.y + dx * sin(angle) + dy * cos(angle))
    }

    // MARK: Starters

    static let starterSize = CGSize(width: 94, height: 122)
    static let starterPitch: CGFloat = 9
    /// Top-left corners of the three desk positions, left to right, in desk coordinates.
    static let starterOrigins = [CGPoint(x: 26, y: 284), CGPoint(x: 154, y: 296), CGPoint(x: 282, y: 284)]
    static let pillTop: CGFloat = 127
    static let pressedScale: CGFloat = 1.1
    static let collectedScale: CGFloat = 0.90
    static let dimmedOpacity = 0.5
    static let dimmedOpacityIncreasedContrast = 0.6
    static let postmarkSize: CGFloat = 66
    static let postmarkRotation: Double = 14
    static let busyIndicatorDelay: TimeInterval = 0.6

    /// The desk scale on a screen: down to .82 on a small phone, up to 1.2 on a tablet.
    static func scale(for size: CGSize) -> CGFloat {
        min(max(min(size.width / canvasWidth, size.height / 874), scaleRange.lowerBound), scaleRange.upperBound)
    }

    // MARK: Flight

    /// Where the collected stamp ends up: the centre of slot 1 and the stamp's final scale and absolute rotation.
    static func landing(from origin: CGPoint) -> FlightTarget {
        let center = CGPoint(x: origin.x + starterSize.width / 2, y: origin.y + starterSize.height / 2)
        let slot = slotCenter(0)
        return FlightTarget(end: CGSize(width: slot.x - center.x, height: slot.y - center.y))
    }
}

/// Offsets of the flight, from the stamp's desk position: the arc apex above slot 1, the contact and the end.
nonisolated struct FlightTarget: Equatable, Sendable {
    let end: CGSize
    var apex: CGSize { CGSize(width: end.width - 0.15, height: end.height - 10.4) }
    var contact: CGSize { CGSize(width: end.width - 0.15, height: end.height + 5.6) }
}
