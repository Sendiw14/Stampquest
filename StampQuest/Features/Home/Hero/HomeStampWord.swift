import SwiftUI

/// The "stamp" / "stamps" word chip: a perforated paper chip, rotated -3 degrees.
struct HomeStampWord: View {
    let text: LocalizedStringKey
    var fontSize: CGFloat = 30

    var body: some View {
        let height = fontSize * 1.45
        Text(text)
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(-0.045 * fontSize)
            .foregroundStyle(HomeColor.chipInk)
            .padding(.horizontal, fontSize * 0.475)
            .frame(height: height)
            .background {
                ZStack {
                    FixedPitchPerforatedShape(pitch: 9, notchRatio: 0.29).fill(HomeColor.chipFill)
                    Rectangle().inset(by: min(7, fontSize * 0.17)).strokeBorder(HomeColor.chipInk.opacity(0.32), lineWidth: 1.4)
                }
                .shadow(color: HomeColor.shadow1.opacity(0.34), radius: 3.6, y: 4.8)
            }
            .rotationEffect(.degrees(-3))
            .fixedSize()
    }
}
