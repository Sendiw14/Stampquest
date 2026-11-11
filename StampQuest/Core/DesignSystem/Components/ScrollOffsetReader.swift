import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Zero-height view placed first inside a scroll view's content; reports the scroll offset through `ScrollOffsetKey` in
/// the named coordinate space. The iOS 17 path of `ScrollOffsetReader`.
struct ScrollOffsetAnchor: View {
    var space = "scroll"

    var body: some View {
        Color.clear.frame(height: 1).background(GeometryReader { Color.clear.preference(key: ScrollOffsetKey.self, value: -$0.frame(in: .named(space)).minY) })
    }
}

/// Reports the scroll offset (0 at rest, growing as the content moves up): `onScrollGeometryChange` on iOS 18+, a
/// preference reader before that. `limit` clamps the value so a screen that only cares about the first stretch of the
/// scroll is not re-rendered after it.
struct ScrollOffsetReader: ViewModifier {
    @Binding var offset: CGFloat
    var space = "scroll"
    var limit: CGFloat = .infinity

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            let limit = limit
            content.onScrollGeometryChange(for: CGFloat.self) { min(limit, max(0, $0.contentOffset.y + $0.contentInsets.top)) } action: { _, new in offset = new }
        } else {
            content.coordinateSpace(name: space).onPreferenceChange(ScrollOffsetKey.self) { offset = min(limit, max(0, $0)) }
        }
    }
}
