import CoreGraphics

/// Pure layout numbers of the Welcome poster, in points of the 402 x 874 design canvas (iPhone 16 Pro).
/// The screen scales them by `scale(for:)` and anchors them to the safe areas.
nonisolated enum WelcomeMetrics {
    static let canvas = CGSize(width: 402, height: 874)
    static let scaleRange: ClosedRange<CGFloat> = 0.72...1.15
    /// Safe area of the design canvas: the top and bottom insets of an iPhone 16 Pro.
    static let designSafeTop: CGFloat = 59
    static let sideMargin: CGFloat = 28

    /// `k = clamp(min(w / 402, h / 874), 0.72...1.15)`.
    static func scale(for size: CGSize) -> CGFloat {
        let raw = min(size.width / canvas.width, size.height / canvas.height)
        return min(max(raw, scaleRange.lowerBound), scaleRange.upperBound)
    }

    // MARK: Top block (canvas y, from the top safe area)

    static let topRowY: CGFloat = 70
    static let headlineY: CGFloat = 104
    static let headlineLineHeight: CGFloat = 60
    static let headlineSize: CGFloat = 56
    static let headlineLineCount = 3
    static var headlineBottom: CGFloat { headlineY + headlineLineHeight * CGFloat(headlineLineCount) }
    /// The stamp fan's container starts this far under the headline.
    static let fanGap: CGFloat = 24
    static var fanTop: CGFloat { headlineBottom + fanGap }
    static let fanHeight: CGFloat = 300

    // MARK: Bottom block (canvas distances above the bottom safe area)

    static let ctaHeight: CGFloat = 58
    static let ctaTopAboveSafeBottom: CGFloat = 94
    /// Space between the subtitle's two lines and the CTA, between the CTA and the fine print, and the fine print's height.
    static let subtitleToCTA: CGFloat = 51
    static let ctaToFinePrint: CGFloat = 4
    static let finePrintBlockHeight: CGFloat = 22
    /// A bottom gap smaller than this above the home indicator is not allowed.
    static let minCTABottomGap: CGFloat = 24
    static var ctaBottomGap: CGFloat { ctaTopAboveSafeBottom - ctaHeight }

    /// Distance of the bottom of the CTA from the bottom safe area at scale `k`, never under the minimum.
    static func ctaBottomInset(scale k: CGFloat) -> CGFloat { max(minCTABottomGap, ctaBottomGap * k) }

    // MARK: Fan

    /// Border of a fan stamp as a fraction of its width, and the caption zone as a fraction of its height.
    static let stampBorderRatio: CGFloat = 0.072
    static let stampCaptionRatio: CGFloat = 0.15

    enum Depth: Sendable { case back, mid, front }

    /// The five stamps of the fan with their frame (top-left, before rotation), rotation and depth.
    enum FanSlot: CaseIterable, Sendable {
        case rome, newYork, santorini, kyoto, paris

        var destinationID: String {
            switch self {
            case .rome: "rome-colosseum"
            case .newYork: "new-york-statue-of-liberty"
            case .santorini: "santorini-oia"
            case .kyoto: "kyoto-fushimi-inari"
            case .paris: "paris-eiffel-tower"
            }
        }
        var frame: CGRect {
            switch self {
            case .rome: CGRect(x: 62, y: 352, width: 112, height: 149)
            case .newYork: CGRect(x: 228, y: 348, width: 112, height: 149)
            case .santorini: CGRect(x: 8, y: 414, width: 128, height: 170)
            case .kyoto: CGRect(x: 266, y: 414, width: 128, height: 170)
            case .paris: CGRect(x: 116, y: 362, width: 170, height: 226)
            }
        }
        var rotation: Double {
            switch self {
            case .rome: -7
            case .newYork: 8
            case .santorini: -14
            case .kyoto: 13
            case .paris: -2
            }
        }
        var depth: Depth {
            switch self {
            case .rome, .newYork: .back
            case .santorini, .kyoto: .mid
            case .paris: .front
            }
        }
        var isHero: Bool { self == .paris }
        /// Place in the drop order and in the float stagger.
        var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
        /// Largest tilt-parallax offset in points.
        var parallax: CGFloat {
            switch depth {
            case .back: 3
            case .mid: 5
            case .front: 8
            }
        }
        /// Frame in the fan container's own coordinates.
        var containerFrame: CGRect { frame.offsetBy(dx: 0, dy: -WelcomeMetrics.fanTop) }
    }

    static let postmarkFrame = CGRect(x: 222, y: 356, width: 98, height: 98)
    static let postmarkRotation: Double = 14
    static let postmarkParallax: CGFloat = 10
    static let wavesFrame = CGRect(x: 138, y: 380, width: 64, height: 36)
    static let wavesRotation: Double = 8
    static let headlineFrameParallax: CGFloat = 3
    static let sparkles = [CGRect(x: 352, y: 334, width: 10, height: 10), CGRect(x: 26, y: 364, width: 9, height: 9)]
}
