import SwiftUI

/// The onboarding artwork of Paris, Kyoto or Santorini, scaled to fill its frame (the frame decides the crop).
struct StampArtCanvas: View {
    let style: StampArtStyle

    var body: some View {
        Canvas { context, size in
            let scale = max(size.width / StampArt.panel.width, size.height / StampArt.panel.height)
            context.translateBy(x: (size.width - StampArt.panel.width * scale) / 2, y: (size.height - StampArt.panel.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            StampArt.draw(style, in: &context)
        }
    }
}

/// The printed caption of a stamp in New York serif: the label on the left, an italic "No. NN" on the right.
struct SerifStampCaption: View {
    let label: String
    let number: String
    /// Width of the stamp; the type scales with it.
    let stampWidth: CGFloat
    let band: CGSize

    var body: some View {
        let fontSize = stampWidth * 0.078
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: fontSize, weight: .semibold, design: .serif))
                .tracking(fontSize * 0.08)
            Spacer(minLength: 4)
            Text(number)
                .font(.system(size: fontSize * 0.88, weight: .regular, design: .serif).italic())
        }
        .foregroundStyle(StampArt.ink(OBColor.stampLabelInk))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: band.width, height: band.height * 0.85)
    }
}
