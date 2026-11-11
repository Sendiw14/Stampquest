import SwiftUI

/// The terracotta action pill used by the Today card and Near you: a 52 pt (or 40 pt) capsule with the CTA shadow.
struct HomePill: View {
    let title: LocalizedStringKey
    var height: CGFloat = 52
    var width: CGFloat = 102
    var isBusy = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).font(.system(size: height > 44 ? 17 : 15, weight: .bold)).opacity(isBusy ? 0 : 1)
                if isBusy { ProgressView().tint(HomeColor.ctaText) }
            }
            .foregroundStyle(HomeColor.ctaText)
            .frame(minWidth: width, minHeight: height)
            .background(HomeColor.cta.opacity(isEnabled ? 1 : 0.5), in: Capsule())
            .shadow(color: HomeColor.cta.opacity(0.45), radius: 10, y: 6)
        }
        .buttonStyle(HomePillPressStyle())
        .frame(minHeight: 44)
    }
}

private struct HomePillPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
