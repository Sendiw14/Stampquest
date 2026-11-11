import SwiftUI

enum PostmarkKind {
    case collected
    case verified

    var word: String {
        switch self {
        case .collected: String(localized: "COLLECTED")
        case .verified: String(localized: "VISITED")
        }
    }
}

/// A cancellation mark: double ring, curved lettering, the date, and wavy lines.
/// "Visited" is only ever drawn for stamps that were genuinely verified.
struct StampPostmarkView: View {
    let place: String
    let date: Date
    var kind: PostmarkKind = .collected
    /// Stamp detail draws just the ring (no cancellation waves), with its own ink and wording.
    var showsWaves = true
    var topText: String?
    var inkOverride: Color?

    private var dateLines: (day: String, year: String) {
        let day = date.formatted(.dateTime.day(.twoDigits).month(.abbreviated)).uppercased()
        let year = date.formatted(.dateTime.year())
        return (day, year)
    }

    var body: some View {
        Canvas { context, size in
            let d = min(size.height, showsWaves ? size.width / 1.8 : size.width)
            let center = CGPoint(x: showsWaves ? size.width - d / 2 : size.width / 2, y: size.height / 2)
            let ink = inkOverride ?? (kind == .verified ? SQColor.verified : SQColor.ink)
            // Leave room for half the outer stroke so the ring is never clipped.
            let r = d / 2 - d * 0.03

            // Wavy cancellation lines trailing to the left.
            for i in 0..<(showsWaves ? 4 : 0) {
                let y = center.y - r * 0.55 + Double(i) * r * 0.37
                var wave = Path()
                let startX = center.x - r - d * 0.78
                wave.move(to: CGPoint(x: startX, y: y))
                var x = startX
                while x < center.x - r * 0.92 {
                    x += 2
                    wave.addLine(to: CGPoint(x: x, y: y + sin((x - startX) * 0.32) * r * 0.07))
                }
                context.stroke(wave, with: .color(ink), style: StrokeStyle(lineWidth: max(0.8, d * 0.028), lineCap: .round))
            }

            // Double ring.
            context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: d, height: d)),
                           with: .color(ink), lineWidth: max(1, d * 0.05))
            let inner = r * 0.74
            context.stroke(Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)),
                           with: .color(ink), lineWidth: max(0.6, d * 0.022))

            // Curved text: place on top arc, word on the bottom arc.
            let textRadius = r * 0.86
            let fontSize = max(5, d * 0.115)
            drawArcText(&context, text: String((topText ?? place).uppercased().prefix(topText == nil ? 14 : 18)), center: center, radius: textRadius,
                        fontSize: fontSize, ink: ink, top: true)
            drawArcText(&context, text: kind.word, center: center, radius: textRadius,
                        fontSize: fontSize, ink: ink, top: false)

            // Centre date.
            let lines = dateLines
            let day = context.resolve(Text(lines.day).font(.system(size: d * 0.17, weight: .bold, design: .monospaced)).foregroundColor(ink))
            let year = context.resolve(Text(lines.year).font(.system(size: d * 0.15, weight: .medium, design: .monospaced)).foregroundColor(ink))
            context.draw(day, at: CGPoint(x: center.x, y: center.y - d * 0.07), anchor: .center)
            context.draw(year, at: CGPoint(x: center.x, y: center.y + d * 0.1), anchor: .center)
        }
        .aspectRatio(showsWaves ? 1.8 : 1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func drawArcText(_ context: inout GraphicsContext, text: String, center: CGPoint, radius: CGFloat,
                             fontSize: CGFloat, ink: Color, top: Bool) {
        let chars = Array(text)
        guard !chars.isEmpty else { return }
        let step = fontSize * 0.74 / radius
        let total = step * Double(chars.count - 1)
        for (i, ch) in chars.enumerated() {
            let offset = -total / 2 + step * Double(i)
            var layer = context
            layer.translateBy(x: center.x, y: center.y)
            // Top text reads clockwise along the top; bottom text reads left to right
            // along the bottom, with glyph tops facing the centre of the ring.
            layer.rotate(by: .radians(top ? offset : -offset))
            let glyph = layer.resolve(Text(String(ch)).font(.system(size: fontSize, weight: .bold, design: .monospaced)).foregroundColor(ink))
            layer.draw(glyph, at: CGPoint(x: 0, y: top ? -radius : radius), anchor: .center)
        }
    }
}

/// A stamp with its postmark, as it appears pressed into a passport page.
struct PassportStamp: View {
    let design: StampDesign
    var presentation: StampPresentation = .full
    var postmark: (place: String, date: Date, kind: PostmarkKind)?
    var showsTitle: Bool = true
    var isDecorative: Bool = false

    var body: some View {
        PerforatedStampView(design: design, presentation: presentation, showsTitle: showsTitle, isDecorative: isDecorative)
            .overlay(alignment: .bottomTrailing) {
                if let postmark, presentation == .full {
                    GeometryReader { geo in
                        // Too small to read at thumbnail sizes: leave it off rather than show a smudge.
                        if geo.size.width >= 120 {
                            StampPostmarkView(place: postmark.place, date: postmark.date, kind: postmark.kind)
                                .frame(width: geo.size.width * 0.66)
                                .rotationEffect(.degrees(-9))
                                .opacity(0.62)
                                .position(x: geo.size.width * 0.655, y: geo.size.height * 0.79)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}
