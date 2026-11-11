import SwiftUI

/// Price and period first, then the cancellation line; a failure replaces only the second line, so the price never disappears. While plans
/// cannot be loaded the single line says so.
struct PlusFinePrint: View {
    let phase: PlusViewModel.Phase
    let content: PlusContent?
    let notice: PlusViewModel.Notice?
    let reduceMotion: Bool

    @ScaledMetric(relativeTo: .footnote) private var size = 13.0

    var body: some View {
        VStack(spacing: 0) {
            if phase == .unavailable {
                line(String(localized: "onboarding.plus.error.unavailable"), primary: true)
            } else if let content, !content.finePrint.isEmpty, phase != .loading {
                line(content.finePrint[0], primary: true)
                if let notice {
                    line(notice.text, primary: false).accessibilityIdentifier("onboarding.plus.notice")
                } else {
                    line(content.finePrint[1], primary: false)
                }
            } else {
                line(" ", primary: false)
            }
        }
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: reduceMotion ? 0.15 : 0.22), value: content?.finePrint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.plus.finePrint")
    }

    private func line(_ text: String, primary: Bool) -> some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: primary ? .medium : .regular))
            .foregroundStyle(primary ? OnbColor.inkPrimary : OnbColor.inkSecondary)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
    }
}
