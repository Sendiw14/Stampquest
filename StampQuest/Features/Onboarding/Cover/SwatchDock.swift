import SwiftUI

/// The five mini covers under the carousel, with one ring that moves to the chosen one. Each swatch is a button.
struct SwatchDock: View {
    let covers: [CoverStyle]
    let selected: CoverStyle
    let showsPlus: Bool
    let shownCount: Int
    let ringShown: Bool
    let reduceMotion: Bool
    let onSelect: (CoverStyle) -> Void

    @State private var previous: CoverStyle?

    private var selectedIndex: Int { covers.firstIndex(of: selected) ?? 0 }
    private var width: CGFloat { CoverMetrics.swatchOffset(covers.count - 1) + CoverMetrics.miniSize.width }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(OnbColor.inkPrimary, lineWidth: 2)
                .frame(width: CoverMetrics.ringSize.width, height: CoverMetrics.ringSize.height)
                .offset(x: CoverMetrics.swatchOffset(selectedIndex) - 5, y: 0)
                .opacity(ringShown ? 1 : 0)
                .animation(ringAnimation, value: selected)
                .accessibilityHidden(true)
            ForEach(Array(covers.enumerated()), id: \.element) { index, style in
                swatch(style, index: index)
                    .offset(x: CoverMetrics.swatchOffset(index) - 10, y: 0)
            }
        }
        .frame(width: width, height: CoverMetrics.ringSize.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("onboarding.cover.a11y.swatches"))
        .onChange(of: selected) { old, _ in previous = old }
    }

    /// A spring for a neighbouring swatch; a longer jump glides over 0.7 s.
    private var ringAnimation: Animation {
        if reduceMotion { return .easeInOut(duration: 0.2) }
        let distance = abs(selectedIndex - (previous.flatMap { covers.firstIndex(of: $0) } ?? selectedIndex))
        return distance > 1 ? .timingCurve(0.32, 0.78, 0.2, 1, duration: 0.7) : .spring(duration: 0.5, bounce: 0.25)
    }

    private func swatch(_ style: CoverStyle, index: Int) -> some View {
        let isSelected = style == selected
        let name = Bundle.main.localizedString(forKey: style.nameKey, value: nil, table: nil)
        return Button { onSelect(style) } label: {
            MiniCover(style: style)
                .overlay(alignment: .bottomTrailing) { if showsPlus && style.isPlus { PlusDot().offset(x: 7, y: 7) } }
                .frame(width: CoverMetrics.miniSize.width, height: CoverMetrics.miniSize.height)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 56, minHeight: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(FadeUp(shown: index < shownCount))
        .accessibilityLabel(showsPlus && style.isPlus ? Text("onboarding.cover.a11y.swatch.plus \(name)") : Text("onboarding.cover.a11y.swatch \(name)"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.cover.swatch.\(style.rawValue)")
    }
}

/// A 36 x 50 cover: the leather, a darker spine strip, a foil frame and a star.
struct MiniCover: View {
    let style: CoverStyle

    var body: some View {
        let size = CoverMetrics.miniSize
        ZStack(alignment: .topLeading) {
            LinearGradient(stops: style.gradient.stops, startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle().fill(StampArt.ink(style.leather.deep).opacity(0.32)).frame(width: size.width * 0.14)
            Color.white.opacity(0.07)
            RoundedRectangle(cornerRadius: 2).stroke(StampArt.ink(0xE9C877).opacity(0.75), lineWidth: 0.8)
                .frame(width: size.width * 0.62, height: size.height * 0.76)
                .offset(x: size.width * 0.3, y: size.height * 0.12)
            StarShape().fill(StampArt.ink(0xF0D590)).frame(width: size.width * 0.4, height: size.width * 0.4)
                .offset(x: size.width * 0.61 - size.width * 0.2, y: size.height * 0.5 - size.width * 0.2)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: OnbColor.shadowSoft, radius: 2.5, y: 4)
        .accessibilityHidden(true)
    }
}

/// The small "+" marking a Plus cover. Never a lock.
struct PlusDot: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(OnbColor.ctaLabel)
            .frame(width: 16, height: 16)
            .background(OnbColor.ctaFill, in: Circle())
            .overlay { Circle().stroke(OnbColor.background, lineWidth: 1.5) }
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
            .accessibilityHidden(true)
    }
}
