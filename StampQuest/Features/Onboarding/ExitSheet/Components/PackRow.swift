import SwiftUI

/// The pack card: the stack, the pack's name and price pill, and the blurb. From accessibility text sizes it stacks vertically with a
/// full-width pill.
struct PackRow: View {
    let pack: Pack
    let product: PackProduct
    let state: ExitSheetModel.PackState
    let isForInterest: Bool
    let ownedCount: Int
    let player: BeatPlayer<ExitBeat>
    let reduceMotion: Bool
    let isStacked: Bool
    let buy: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .headline) private var titleSize = 16.0
    @ScaledMetric(relativeTo: .caption) private var blurbSize = 12.5

    private var name: String { String(localized: "exit.pack.title \(product.displayName)") }
    private var blurb: String { PackOffer.blurb(for: pack, isForInterest: isForInterest) }

    var body: some View {
        Group {
            if isStacked {
                VStack(alignment: .leading, spacing: 12) { stack; text; pill.frame(maxWidth: .infinity, minHeight: 44) }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    stack
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { title; Spacer(minLength: 8); pill }.frame(minHeight: 34)
                        blurbText
                    }
                }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnbColor.passportPaper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(contrast == .increased ? OnbColor.inkPrimary.opacity(0.35) : OnbColor.cardHairline, lineWidth: 1)
        }
        .shadow(color: OnbColor.shadowSoft.opacity(0.5), radius: 8, y: 10)
        .exitBeat(.packCard, player, reduceMotion: reduceMotion)
        .accessibilityElement(children: .contain)
    }

    private var stack: some View {
        PackStack(pack: pack, isOwned: state == .owned, ownedCount: ownedCount, player: player, reduceMotion: reduceMotion)
    }

    private var title: some View {
        Text(verbatim: name).font(.system(size: titleSize, weight: .semibold)).tracking(-0.014 * titleSize)
            .foregroundStyle(OnbColor.inkPrimary).lineLimit(1).truncationMode(.tail)
            .exitBeat(.packTitle, player, reduceMotion: reduceMotion)
    }

    private var blurbText: some View {
        Text(verbatim: blurb).font(.system(size: blurbSize)).foregroundStyle(OnbColor.inkSecondary).lineLimit(2).lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
            .exitBeat(.blurb, player, reduceMotion: reduceMotion)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 4) { title; blurbText }
    }

    private var pill: some View {
        PricePill(state: state, reduceMotion: reduceMotion, action: buy)
            .exitBeat(.pill, player, style: .popIn, reduceMotion: reduceMotion)
            .accessibilityLabel(label)
            .accessibilityAddTraits(state == .purchasing ? .updatesFrequently : [])
    }

    private var label: Text {
        switch state {
        case .idle(let price): Text("exit.a11y.buy \(name) \(price)")
        case .purchasing: Text("exit.a11y.buying \(name)")
        case .owned: Text("exit.a11y.added \(name)")
        case .pending: Text("exit.a11y.pending \(name)")
        }
    }
}
