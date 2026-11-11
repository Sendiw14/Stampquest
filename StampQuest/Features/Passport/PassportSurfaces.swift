import SwiftUI

/// A glass surface on the terracotta poster: material, a warm tint, and a light edge. Solid under Reduce Transparency.
struct PosterGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                if reduceTransparency { shape.fill(scheme == .dark ? Color(hex: 0x3A3733) : Color(hex: 0x6A3420)) }
                else {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(HomeColor.glassFill.opacity(scheme == .dark ? 0.10 : 0.30))
                }
                shape.strokeBorder(.white.opacity(scheme == .dark ? 0.22 : 0.34), lineWidth: 1)
            }
        }
    }
}

/// A glass surface on the page: material with a cream (light) or charcoal (dark) tint. Solid card plus a line under
/// Reduce Transparency.
struct CardGlass<S: InsettableShape>: ViewModifier {
    let shape: S
    var tint: Double = 0.86
    var lined = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                if reduceTransparency { shape.fill(HomeColor.card) }
                else {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(HomeColor.card.opacity(scheme == .dark ? min(1, tint + 0.04) : tint))
                }
                if lined || reduceTransparency { shape.strokeBorder(PassportColor.cardLine, lineWidth: 1) }
            }
        }
    }
}

extension View {
    func posterGlass<S: InsettableShape>(_ shape: S) -> some View { modifier(PosterGlass(shape: shape)) }
    func cardGlass<S: InsettableShape>(_ shape: S, tint: Double = 0.86, lined: Bool = true) -> some View { modifier(CardGlass(shape: shape, tint: tint, lined: lined)) }
}

/// A horizontal or vertical row of round dots, the dotted rule of the design.
nonisolated struct DottedLine: Shape {
    var vertical = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if vertical { path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) }
        else { path.move(to: CGPoint(x: rect.minX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
        return path
    }
}

struct DottedRule: View {
    var vertical = false
    var color: Color = PassportColor.cardLine

    var body: some View {
        DottedLine(vertical: vertical)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 5]))
            .frame(width: vertical ? 2 : nil, height: vertical ? nil : 2)
            .accessibilityHidden(true)
    }
}

/// "Your stamps", "Your page" and the Discover sections: the 26 pt section title with its dotted rule and, optionally, a link
/// on the right.
struct PassportSectionHeader: View {
    let title: LocalizedStringKey
    var identifier: String?
    var actionTitle: LocalizedStringKey?
    var actionIdentifier: String?
    var action: (() -> Void)?
    @ScaledMetric(relativeTo: .title) private var size = 26.0
    @ScaledMetric(relativeTo: .subheadline) private var linkSize = 14.5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.system(size: size, weight: .heavy)).tracking(-0.035 * size).foregroundStyle(HomeColor.ink)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier(identifier ?? "")
                Spacer(minLength: 8)
                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle).font(.system(size: linkSize, weight: .semibold)).foregroundStyle(HomeColor.label)
                            .frame(minWidth: 44, minHeight: 44, alignment: .trailing).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).padding(.vertical, -10).accessibilityIdentifier(actionIdentifier ?? "")
                }
            }
            DottedRule()
        }
    }
}

/// "PAGE 1 OF 2" on the left, the date span of the page on the right, then a dotted rule.
struct PassportPageHeader: View {
    let number: Int
    let total: Int
    let span: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("PAGE \(number) OF \(total)").font(.system(size: 11, weight: .bold)).tracking(0.14 * 11).foregroundStyle(HomeColor.label)
                Spacer(minLength: 8)
                Text(span).font(.system(size: 11.5, weight: .medium)).foregroundStyle(HomeColor.sub)
            }
            DottedRule()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The artwork stand-in for a stamp whose design is not in the catalogue: the same perforation, a quiet pattern and the
/// destination name, never a blank hole.
struct MissingStampArtwork: View {
    let name: String

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack {
                PerforatedStampShape().fill(HomeColor.tint)
                Canvas { context, size in
                    var path = Path()
                    var x = -size.height
                    while x < size.width { path.move(to: CGPoint(x: x, y: size.height)); path.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 9 }
                    context.stroke(path, with: .color(HomeColor.ink3.opacity(0.14)), lineWidth: 1)
                }
                .clipShape(Rectangle()).padding(w * StampMetrics.insetRatio)
                Text(name).font(.system(size: max(9, w * 0.12), weight: .bold, design: .serif)).foregroundStyle(HomeColor.ink3)
                    .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.6).padding(w * 0.16)
            }
        }
        .accessibilityHidden(true)
    }
}
