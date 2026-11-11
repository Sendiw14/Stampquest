import SwiftUI

/// Look of a stamp-word frame: colours, tilt and the size of its perforated outline, derived from the text size.
struct StampWordStyle {
    let fill: Color
    let ink: Color
    let shadow: Color
    let rotation: Double
    let height: CGFloat
    let horizontalPadding: CGFloat
    let pitch: CGFloat
    let inset: CGFloat
    let insetRadius: CGFloat
    let shadowOffset: CGFloat

    /// Welcome: "world" (index 0) tilts +3 degrees, "stamp" -4, on frames sized from a 56 pt headline.
    static func welcome(index: Int, size: CGFloat) -> StampWordStyle {
        let unit = size / WelcomeMetrics.headlineSize
        let first = index.isMultiple(of: 2)
        return StampWordStyle(fill: first ? WelcomeColor.wordWorldFill : WelcomeColor.wordStampFill,
                              ink: first ? WelcomeColor.wordWorldText : WelcomeColor.wordStampText, shadow: WelcomeColor.stampShadow,
                              rotation: first ? 3 : -4, height: 74 * unit, horizontalPadding: 26 * unit, pitch: 9 * unit, inset: 7 * unit,
                              insetRadius: 0, shadowOffset: 10 * unit)
    }

    /// A frame of any colour and tilt, 1.56 times the text size tall (50 pt at 32 pt text).
    static func custom(size: CGFloat, fill: Color, ink: Color, rotation: Double) -> StampWordStyle {
        StampWordStyle(fill: fill, ink: ink, shadow: OnbColor.shadowSoft, rotation: rotation, height: size * 1.5625,
                       horizontalPadding: size * 0.5, pitch: 9, inset: 7, insetRadius: 2, shadowOffset: 10)
    }

    /// Verification: "yours" in terracotta tilted -3 degrees, "earned" in gold tilted +2.5.
    static func verification(index: Int, size: CGFloat) -> StampWordStyle {
        index == 0 ? custom(size: size, fill: OnbColor.stampWordFill, ink: OnbColor.stampWordLabel, rotation: -3)
                   : custom(size: size, fill: OnbColor.goldWordFill, ink: OnbColor.goldWordLabel, rotation: 2.5)
    }

    /// Interests: one frame tilted -3 degrees, 58 pt tall at 40 pt text.
    static func interests(size: CGFloat) -> StampWordStyle {
        StampWordStyle(fill: OnbColor.stampWordFill, ink: OnbColor.stampWordLabel, shadow: OnbColor.shadowSoft, rotation: -3,
                       height: size * 1.45, horizontalPadding: size * 0.475, pitch: 9, inset: 7, insetRadius: 2, shadowOffset: 10)
    }
}

/// A word on a perforated stamp: perforation notches at 0.29 of the pitch, a keyline inset from the edge, tilted.
struct StampWordFrame: View {
    let word: String
    let size: CGFloat
    let style: StampWordStyle

    var body: some View {
        Text(word)
            .font(.system(size: size, weight: .heavy))
            .tracking(-0.045 * size)
            .foregroundStyle(style.ink)
            .fixedSize()
            .padding(.horizontal, style.horizontalPadding)
            .frame(height: style.height)
            .background {
                FixedPitchPerforatedShape(pitch: style.pitch, notchRatio: 0.29)
                    .fill(style.fill)
                    .shadow(color: style.shadow, radius: 6, y: style.shadowOffset)
            }
            .overlay {
                RoundedRectangle(cornerRadius: style.insetRadius).inset(by: style.inset).stroke(style.ink.opacity(0.32), lineWidth: 1.4)
            }
            .rotationEffect(.degrees(style.rotation))
    }
}

nonisolated struct SpaceBeforeKey: LayoutValueKey {
    static let defaultValue = true
}

nonisolated struct LineBreakBeforeKey: LayoutValueKey {
    static let defaultValue = false
}

/// Lays words out left to right (right to left in RTL), wrapping at the proposed width and at explicit breaks. Lines
/// have a fixed height unless `growsForTallItems`; otherwise a taller item, like a stamp frame, stays centred on its
/// line and overlaps the neighbours.
nonisolated struct HeadlineFlowLayout: Layout {
    var lineHeight: CGFloat
    var spaceWidth: CGFloat
    var growsForTallItems = false
    /// Space before a token that sits tight against the one before it (a full stop after a frame).
    var tightGap: CGFloat = 0

    private struct Arrangement {
        var xs: [CGFloat] = []
        var lines: [Int] = []
        var heights: [CGFloat] = []
        var width: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: result.width, height: result.heights.reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        let mirrored = subviews.layoutDirection == .rightToLeft
        var tops: [CGFloat] = []
        var top = bounds.minY
        for height in result.heights {
            tops.append(top)
            top += height
        }
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let x = mirrored ? bounds.maxX - result.xs[index] - size.width : bounds.minX + result.xs[index]
            let line = result.lines[index]
            subview.place(at: CGPoint(x: x, y: tops[line] + (result.heights[line] - size.height) / 2), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> Arrangement {
        var result = Arrangement()
        var x: CGFloat = 0, line = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let gap = x > 0 ? (subview[SpaceBeforeKey.self] ? spaceWidth : tightGap) : 0
            if x > 0, subview[LineBreakBeforeKey.self] || x + gap + size.width > width {
                line += 1
                x = 0
            } else {
                x += gap
            }
            if result.heights.count <= line { result.heights.append(lineHeight) }
            if growsForTallItems { result.heights[line] = max(result.heights[line], size.height) }
            result.xs.append(x)
            result.lines.append(line)
            x += size.width
            result.width = max(result.width, x)
        }
        return result
    }
}
