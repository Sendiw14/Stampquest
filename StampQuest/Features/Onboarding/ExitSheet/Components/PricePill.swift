import SwiftUI

/// The pack's price pill: the price (idle), a spinner of the same size (purchasing), or a tinted "Added" / "Pending" with a check or a clock.
struct PricePill: View {
    let state: ExitSheetModel.PackState
    let reduceMotion: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var textSize = 15.0
    @State private var angle = 0.0

    var body: some View {
        Group {
            switch state {
            case .idle(let price): buy(price: price, spinning: false)
            case .purchasing: buy(price: "", spinning: true)
            case .owned: status(symbol: "checkmark", key: "exit.pack.added", id: "exitSheet.pack.added")
            case .pending: status(symbol: "clock", key: "exit.pack.pending", id: "exitSheet.pack.pending")
            }
        }
        .animation(.easeInOut(duration: 0.14), value: state)
    }

    private func buy(price: String, spinning: Bool) -> some View {
        Button(action: action) {
            ZStack {
                Text(verbatim: price).opacity(spinning ? 0 : 1)
                if spinning { spinner }
            }
            .font(.system(size: textSize, weight: .semibold))
            .tracking(-0.01 * textSize)
            .foregroundStyle(OnbColor.ctaLabel)
            .padding(.horizontal, 15)
            .frame(minHeight: 34)
            .background(OnbColor.ctaFill, in: Capsule())
            .shadow(color: OnbColor.ctaShadow, radius: 6, y: 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PillPressStyle(reduceMotion: reduceMotion))
        .disabled(spinning)
        .accessibilityIdentifier("exitSheet.pack.buy")
    }

    private var spinner: some View {
        ZStack {
            Circle().stroke(OnbColor.ctaLabel.opacity(0.25), lineWidth: 2.2)
            Circle().trim(from: 0, to: 0.25).stroke(OnbColor.ctaLabel, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .rotationEffect(.degrees(angle))
        }
        .frame(width: 16, height: 16)
        .onAppear { withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { angle = 360 } }
    }

    private func status(symbol: String, key: LocalizedStringKey, id: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(OnbColor.ctaFill)
            Text(key).font(.system(size: textSize, weight: .semibold)).foregroundStyle(OnbColor.inkPrimary)
        }
        .padding(.leading, 11)
        .padding(.trailing, 13)
        .frame(minHeight: 34)
        .background(OnbColor.selectedTint, in: Capsule())
        .transition(.opacity)
        .accessibilityIdentifier(id)
    }
}

/// 1 to .9 and back over 0.4 s while pressed.
struct PillPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
