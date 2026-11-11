import SwiftUI

/// Pages view: paper pages of four stamps, in the active sort. The last page shows dashed open slots; the first has a plus
/// that adds a stamp by hand.
struct PassportPagesView: View {
    let entries: [PassportEntry]
    let width: CGFloat
    let actions: PassportStampActions
    let onAdd: () -> Void
    var firstPageID: String

    var body: some View {
        let pages = PassportPaging.pages(entries)
        LazyVStack(spacing: 24) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                PassportPageCard(page: page, number: index + 1, total: pages.count, width: width - 40, actions: actions, onAdd: onAdd)
                    .id(index == 0 ? firstPageID : "page-\(index)")
            }
        }
        .padding(.horizontal, 20)
    }
}

struct PassportPageCard: View {
    let page: [PassportEntry]
    let number: Int
    let total: Int
    let width: CGFloat
    let actions: PassportStampActions
    let onAdd: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var stampWidth: CGFloat { min(104 / 362 * width, (width - 72) / 2 - 8) }
    private var singleColumn: Bool { typeSize >= .accessibility3 }

    var body: some View {
        VStack(spacing: 18) {
            PassportPageHeader(number: number, total: total, span: PassportPaging.dateSpan(page))
            let slots = (0..<PassportPaging.pageSize).map { $0 < page.count ? page[$0] : nil }
            let firstEmpty = slots.firstIndex(where: { $0 == nil })
            Group {
                if singleColumn {
                    VStack(spacing: 18) { ForEach(0..<slots.count, id: \.self) { slot(slots[$0], at: $0, isFirstEmpty: $0 == firstEmpty) } }
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        column([0, 2], slots, firstEmpty).padding(.top, 0)
                        column([1, 3], slots, firstEmpty).padding(.top, 18)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 26)
        .frame(width: width)
        .background {
            ZStack {
                PerforatedStampShape(perforationsAcrossWidth: 26, notchRatio: 0.3).fill(HomeColor.postcard)
                Guilloche().clipShape(RoundedRectangle(cornerRadius: 4)).padding(12)
                RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1).padding(9)
            }
            .shadow(color: HomeColor.shadow1.opacity(scheme == .dark ? 0.5 : 0.18), radius: 10, y: 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport-page-\(number)")
    }

    private func column(_ indices: [Int], _ slots: [PassportEntry?], _ firstEmpty: Int?) -> some View {
        VStack(spacing: 18) { ForEach(indices, id: \.self) { slot(slots[$0], at: $0, isFirstEmpty: $0 == firstEmpty) } }
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func slot(_ entry: PassportEntry?, at index: Int, isFirstEmpty: Bool) -> some View {
        if let entry {
            PassportStampButton(entry: entry, actions: actions) { PassportStampCell(entry: entry, width: stampWidth, tilt: PassportTilt.page(index)) }
        } else {
            PassportEmptySlot(width: stampWidth, showsPlus: isFirstEmpty, onAdd: onAdd)
        }
    }
}

/// A dashed open slot. The first one on the last page is a button that adds a stamp by hand.
struct PassportEmptySlot: View {
    let width: CGFloat
    let showsPlus: Bool
    let onAdd: () -> Void

    var body: some View {
        let slot = RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(HomeColor.ink3.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(width: width, height: width * 4 / 3)
            .overlay { if showsPlus { Image(systemName: "plus").font(.system(size: 22, weight: .regular)).foregroundStyle(HomeColor.sub) } }
        if showsPlus {
            Button(action: onAdd) { slot.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                .buttonStyle(.plain).accessibilityLabel(Text("Add a stamp by hand")).accessibilityIdentifier("passport-add-slot")
        } else { slot.accessibilityHidden(true) }
    }
}

/// A very faint guilloche: interlaced sine lines, like the security pattern of a real passport page.
struct Guilloche: View {
    var body: some View {
        Canvas { context, size in
            for band in 0..<9 {
                var path = Path()
                let y0 = size.height * (CGFloat(band) + 0.5) / 9
                path.move(to: CGPoint(x: 0, y: y0))
                for x in stride(from: 0, through: size.width, by: 4) {
                    path.addLine(to: CGPoint(x: x, y: y0 + 9 * sin(x / 22 + CGFloat(band) * 0.8)))
                }
                context.stroke(path, with: .color(PassportColor.guilloche), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}
