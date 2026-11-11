import SwiftUI

/// Your atlas: a dot grid of the world where only places you collected are lit, with a ring for each verified visit.
/// It lights collected places (nearest dot to each stamp), not whole countries, because the app has no country outlines.
struct AtlasCard: View {
    let stamps: [Destination]
    let verified: [Destination]
    let countryCount: Int
    let verifiedCount: Int
    let onOpenMap: () -> Void

    private let columns = 72
    private let rows = 30

    var body: some View {
        VStack(spacing: 0) {
            map.frame(height: 134).padding(.top, 8).accessibilityHidden(true)
            Rectangle().fill(HomeColor.cream.opacity(0.14)).frame(height: 1).padding(.horizontal, 18)
            HStack(alignment: .bottom) {
                stat(value: countryCount, label: "countries collected", color: HomeColor.cream)
                if verifiedCount > 0 { stat(value: verifiedCount, label: "verified", color: HomeColor.verifiedGold).padding(.leading, 24) }
                Spacer()
                Button(action: onOpenMap) {
                    HStack(spacing: 4) { Text("Open map"); Image(systemName: "chevron.right") }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(HomeColor.litCountry)
                }
                .frame(minHeight: 44).accessibilityIdentifier("home-atlas-open")
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
        }
        .background(LinearGradient(colors: [HomeColor.atlasTop, HomeColor.atlasBottom], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(HomeColor.cream.opacity(0.14), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func stat(value: Int, label: LocalizedStringKey, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)").font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(color)
            Text(label).font(.system(size: 12.5)).foregroundStyle(HomeColor.cream.opacity(0.78))
        }
    }

    private func cell(_ destination: Destination) -> (Int, Int) {
        let x = Int(((destination.longitude + 180) / 360 * Double(columns)).rounded(.down))
        let y = Int(((90 - destination.latitude) / 180 * Double(rows)).rounded(.down))
        return (min(max(x, 0), columns - 1), min(max(y, 0), rows - 1))
    }

    private var map: some View {
        Canvas { context, size in
            let lit = Set(stamps.map { "\(cell($0).0),\(cell($0).1)" })
            let step = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let originX = (size.width - step * CGFloat(columns)) / 2
            for row in 0..<rows { for column in 0..<columns {
                let centre = CGPoint(x: originX + (CGFloat(column) + 0.5) * step, y: (CGFloat(row) + 0.5) * step)
                let on = lit.contains("\(column),\(row)")
                let radius = step * (on ? 0.42 : 0.2)
                context.fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(on ? HomeColor.litCountry : HomeColor.cream.opacity(0.27)))
            } }
            for destination in verified {
                let (column, row) = cell(destination)
                let centre = CGPoint(x: originX + (CGFloat(column) + 0.5) * step, y: (CGFloat(row) + 0.5) * step)
                context.stroke(Path(ellipseIn: CGRect(x: centre.x - step * 0.9, y: centre.y - step * 0.9, width: step * 1.8, height: step * 1.8)),
                               with: .color(HomeColor.verifiedGold), lineWidth: 1.4)
            }
        }
    }
}
