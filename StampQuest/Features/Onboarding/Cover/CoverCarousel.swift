import SwiftUI

/// The horizontal cover flow: one cover per swipe, the centred one is the hero. Scale, brightness, saturation and the
/// page block follow each cover's distance from the centre continuously, so dragging and tapping a swatch look the same.
struct CoverCarousel: View {
    let covers: [CoverStyle]
    @Binding var selected: CoverStyle?
    let holderName: String
    let glossShift: CGFloat
    let sheenX: Double?
    let neighboursShown: Bool
    let hidesNeighbours: Bool

    @Environment(\.colorScheme) private var scheme
    /// Each cover's centre in the scroll view's own space, so its pose follows the scroll continuously.
    @State private var centres: [Int: CGFloat] = [:]

    private static let space = "coverScroll"
    private var selectedIndex: Int { covers.firstIndex { $0 == selected } ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.size.width
            let neighbourBrightness: CGFloat = scheme == .dark ? 0.72 : 0.9
            ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(covers.enumerated()), id: \.element) { index, style in
                        cell(style, index: index, viewport: viewport, brightness: neighbourBrightness)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, (viewport - CoverMetrics.pitch) / 2, for: .scrollContent)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $selected, anchor: .center)
            .coordinateSpace(name: Self.space)
            .onPreferenceChange(CoverCentreKey.self) { centres = $0 }
            .mask(edgeFade)
            // The scroll position binding alone leaves the carousel at the first cover on entry: centre the stored cover once the layout
            // exists, with no animation, so the hero, swatch ring and label always agree.
            .task(id: viewport) {
                try? await Task.sleep(for: .milliseconds(60))
                guard let selected else { return }
                var instant = Transaction()
                instant.disablesAnimations = true
                withTransaction(instant) { reader.scrollTo(selected, anchor: .center) }
            }
            }
        }
    }

    private func cell(_ style: CoverStyle, index: Int, viewport: CGFloat, brightness: CGFloat) -> some View {
        let isHero = style == selected
        let group = CoverMetrics.groupSize(width: CoverMetrics.heroWidth, showsPageBlock: true)
        return ZStack {
            PassportCover(style: style, holderName: holderName, showsPageBlock: true, width: CoverMetrics.heroWidth,
                          glossShift: isHero ? glossShift : 0, sheenX: isHero ? sheenX : nil)
        }
        .frame(width: CoverMetrics.pitch, height: group.height)
        .shadow(color: OnbColor.shadowSoft, radius: 12, y: 18)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: CoverCentreKey.self, value: [index: proxy.frame(in: .named(Self.space)).midX])
            }
        }
        .modifier(CoverPose(distance: distance(of: index, viewport: viewport), brightness: brightness, neighboursShown: neighboursShown,
                            hidesNeighbours: hidesNeighbours))
        .zIndex(10 - Double(abs(index - selectedIndex)) * 3)
        .accessibilityHidden(true)
    }

    private func distance(of index: Int, viewport: CGFloat) -> CGFloat {
        guard let centre = centres[index] else { return CGFloat(index - selectedIndex) }
        return (centre - viewport / 2) / CoverMetrics.pitch
    }

    /// The outer 22% of the width on each side fades to the background.
    private var edgeFade: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0), .init(color: .black, location: CoverMetrics.edgeFade),
            .init(color: .black, location: 1 - CoverMetrics.edgeFade), .init(color: .clear, location: 1),
        ], startPoint: .leading, endPoint: .trailing)
            .padding(.vertical, -60)
    }
}

private struct CoverCentreKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) { value.merge(nextValue()) { $1 } }
}

/// A cover's pose for its signed `distance` from the centre, in pitches: scale, brightness, saturation and whether it
/// shows at all (the neighbours slide in at the entrance and hide while the keyboard is up on a short screen).
private struct CoverPose: ViewModifier {
    let distance: CGFloat
    let brightness: CGFloat
    let neighboursShown: Bool
    let hidesNeighbours: Bool

    func body(content: Content) -> some View {
        let blend = CoverMetrics.blend(atDistance: distance)
        let away: CGFloat = neighboursShown ? 0 : (distance < 0 ? -38 : 38)
        let hidden = blend >= 0.01 && (!neighboursShown || hidesNeighbours)
        content
            .scaleEffect(CoverMetrics.scale(atDistance: distance))
            .brightness(Double(-(1 - brightness) * blend * 0.8))
            .saturation(Double(1 - 0.15 * blend))
            .offset(x: away, y: neighboursShown ? 0 : 8)
            .opacity(hidden ? 0 : 1)
    }
}
