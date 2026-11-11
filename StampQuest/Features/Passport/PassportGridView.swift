import SwiftUI

/// Grid view: three columns (two from the third accessibility size), every stamp 3:4, a row pitch that does not depend
/// on the artwork, so a long collection scrolls without jumping.
struct PassportGridView: View {
    let entries: [PassportEntry]
    let width: CGFloat
    let actions: PassportStampActions
    /// Drives the landing of the first screenful; true once it has run (or when it never will).
    let landed: Bool

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: Int { typeSize >= .accessibility3 ? 2 : 3 }
    private var columnWidth: CGFloat { (width - 40) / CGFloat(columns) }
    private var stampWidth: CGFloat { columns == 3 ? min(104 / 402 * width, columnWidth - 12) : min(columnWidth - 28, 168) }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(columnWidth), spacing: 0, alignment: .top), count: columns), spacing: 22) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                PassportStampButton(entry: entry, actions: actions) {
                    PassportStampCell(entry: entry, width: stampWidth, tilt: PassportTilt.grid(index))
                }
                .modifier(StampLanding(index: index, landed: landed, reduceMotion: reduceMotion))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// The first screenful presses in: from 12 pt above at 1.1x to rest, 70 ms apart. Reduce Motion only fades.
struct StampLanding: ViewModifier {
    let index: Int
    let landed: Bool
    let reduceMotion: Bool
    static let count = 9

    func body(content: Content) -> some View {
        if index < Self.count {
            content
                .opacity(landed ? 1 : 0)
                .scaleEffect(landed || reduceMotion ? 1 : 1.1)
                .offset(y: landed || reduceMotion ? 0 : -12)
                .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.78).delay(0.3 + Double(index) * 0.07), value: landed)
        } else { content }
    }
}
