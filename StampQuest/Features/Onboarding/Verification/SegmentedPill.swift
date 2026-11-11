import SwiftUI

/// The Collected / Verified preview control: a rounded track with a sliding thumb and two layered labels. VoiceOver,
/// Switch Control and keyboards get a native segmented picker.
struct SegmentedPill: View {
    let selection: VerificationViewModel.Preview
    var isFullWidth = false
    let onChange: @MainActor @Sendable (VerificationViewModel.Preview) -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.obReducesMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var labelSize = 15.0

    private static let height: CGFloat = 44
    private static let inset: CGFloat = 4
    static let width: CGFloat = 264

    var body: some View {
        GeometryReader { proxy in
            let thumbWidth = (proxy.size.width - Self.inset * 2) / 2
            ZStack(alignment: .leading) {
                Capsule().fill(OnbColor.segTrack).overlay { border }
                Capsule().fill(OnbColor.segThumb)
                    .overlay { border }
                    .frame(width: thumbWidth, height: Self.height - Self.inset * 2)
                    .offset(x: Self.inset + (selection == .verified ? thumbWidth : 0))
                    .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.25), value: selection)
                HStack(spacing: 0) {
                    segment(.collected, title: "onboarding.verification.control.collected", id: "collected", width: thumbWidth)
                    segment(.verified, title: "onboarding.verification.control.verified", id: "verified", width: thumbWidth)
                }
                .padding(.horizontal, Self.inset)
            }
        }
        .frame(width: isFullWidth ? nil : Self.width, height: Self.height)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("onboarding.verification.control.a11y"))
        .accessibilityIdentifier("onboarding.verification.control")
    }

    private var border: some View {
        Capsule().strokeBorder(OnbColor.inkPrimary.opacity(contrast == .increased ? 0.45 : 0), lineWidth: 1)
    }

    /// Both an "on" and an "off" label sit in each segment and cross-fade; a colour is never animated directly. Each
    /// segment is a button that VoiceOver, Switch Control and keyboards reach, with the selected trait on the chosen one.
    private func segment(_ value: VerificationViewModel.Preview, title: LocalizedStringKey, id: String, width: CGFloat) -> some View {
        let on = selection == value
        return Button { onChange(value) } label: {
            ZStack {
                Text(title).foregroundStyle(OnbColor.inkPrimary).opacity(on ? 1 : 0)
                Text(title).foregroundStyle(OnbColor.segLabelOff).opacity(on ? 0 : 1)
            }
            .font(.system(size: labelSize, weight: .semibold))
            .frame(width: width, height: Self.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: on)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("onboarding.verification.control." + id)
    }
}
