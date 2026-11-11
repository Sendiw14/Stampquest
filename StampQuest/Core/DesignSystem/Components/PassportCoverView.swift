import SwiftUI

/// The StampQuest passport cover: a foil-stamped booklet in the person's chosen colour.
struct PassportBookView: View {
    var style: PassportStyle = .terracotta
    var width: CGFloat = 104

    var body: some View {
        let height = width * 1.4
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
                .fill(LinearGradient(colors: [style.color.opacity(0.92), style.color], startPoint: .topLeading, endPoint: .bottomTrailing))
            // Spine
            HStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: width * 0.12)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: width * 0.07, style: .continuous))
            // Foil frame
            RoundedRectangle(cornerRadius: width * 0.04, style: .continuous)
                .strokeBorder(style.foil.opacity(0.7), lineWidth: max(0.8, width * 0.01))
                .padding(width * 0.08)
                .padding(.leading, width * 0.05)
            VStack(spacing: width * 0.05) {
                Text("STAMPQUEST")
                    .font(.system(size: width * 0.078, weight: .semibold, design: .serif))
                    .tracking(width * 0.014)
                PassportEmblem(foil: style.foil)
                    .frame(width: width * 0.36, height: width * 0.44)
                Text("PASSPORT")
                    .font(.system(size: width * 0.095, weight: .bold, design: .serif))
                    .tracking(width * 0.02)
            }
            .foregroundStyle(style.foil)
            .padding(.leading, width * 0.05)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.22), radius: width * 0.06, x: 2, y: width * 0.04)
        .accessibilityHidden(true)
    }
}

/// A perforated stamp outline around an eight-point compass star: the app's emblem.
struct PassportEmblem: View {
    var foil: Color

    var body: some View {
        ZStack {
            PerforatedStampShape(perforationsAcrossWidth: 7)
                .stroke(foil, lineWidth: 1.2)
            CompassStar()
                .fill(foil)
                .padding(.horizontal, 7)
                .padding(.vertical, 9)
        }
    }
}

private nonisolated struct CompassStar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.34
        for i in 0..<16 {
            let isPoint = i % 2 == 0
            let longPoint = i % 4 == 0
            let radius = isPoint ? (longPoint ? outer : outer * 0.72) : inner
            let angle = Double(i) * .pi / 8 - .pi / 2
            let p = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

/// The compact passport header used on the Passport tab.
struct PassportCoverCard: View {
    let style: PassportStyle
    let stamps: Int
    let countries: Int
    let verified: Int
    let since: Date?

    var body: some View {
        HStack(alignment: .center, spacing: SQSpace.md) {
            PassportBookView(style: style, width: 96)
            VStack(alignment: .leading, spacing: SQSpace.xs) {
                Text("Your passport").sqEyebrow()
                if stamps == 0 {
                    Text("No stamps yet").font(SQFont.title).foregroundStyle(SQColor.textPrimary)
                    Text("Collect your first stamp to begin.").font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
                } else {
                    Text(stamps == 1 ? "1 stamp" : "\(stamps) stamps").font(SQFont.title).foregroundStyle(SQColor.textPrimary)
                    Text("\(countries) \(countries == 1 ? "country" : "countries") · \(verified) verified")
                        .font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
                    if let since {
                        Text("Since \(since.formatted(.dateTime.month(.wide).year()))")
                            .font(SQFont.caption).foregroundStyle(SQColor.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(SQSpace.md)
        .background(SQColor.surface, in: RoundedRectangle(cornerRadius: SQRadius.hero, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SQRadius.hero, style: .continuous).strokeBorder(SQColor.separator, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stamps == 0 ? "Your passport, no stamps yet"
                            : "Your passport, \(stamps) stamps from \(countries) countries, \(verified) verified visits")
    }
}
