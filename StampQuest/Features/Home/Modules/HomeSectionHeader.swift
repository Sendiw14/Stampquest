import SwiftUI

/// Section title, a dotted rule and an optional link at the right.
struct HomeSectionHeader: View {
    let title: LocalizedStringKey
    var link: LocalizedStringKey?
    var linkIdentifier = ""
    var action: (() -> Void)?
    @ScaledMetric(relativeTo: .title2) private var size = 26.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: size, weight: .heavy)).tracking(-0.035 * size).foregroundStyle(HomeColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let link, let action {
                    Button(action: action) { Text(link).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(HomeColor.label) }
                        .frame(minHeight: 44).accessibilityIdentifier(linkIdentifier)
                }
            }
            Rectangle().fill(.clear).frame(height: 2.5)
                .overlay { Line().stroke(HomeColor.ink3.opacity(0.4), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [0.1, 5])) }
                .accessibilityHidden(true)
        }
    }

    private nonisolated struct Line: Shape {
        func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p }
    }
}
