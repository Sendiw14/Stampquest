import SwiftUI

/// The call to action: a capsule with the plan's label. While plans load it says so and is disabled; while a purchase is open it shows a
/// spinner (the screen ignores a second tap). The press feel and haptic come from the shared `.paper` capsule style.
struct PurchaseButton: View {
    let title: String
    var isLoadingPlans = false
    var isPurchasing = false
    let action: () -> Void

    @Environment(\.obReducesMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(verbatim: isLoadingPlans ? String(localized: "onboarding.plus.cta.loading") : title).opacity(isPurchasing ? 0 : 1)
                if isPurchasing { ProgressView().tint(OnbColor.ctaLabel) }
            }
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? .easeInOut(duration: 0.25) : .easeOut(duration: 0.2), value: isPurchasing)
        }
        .buttonStyle(PrimaryCapsuleButtonStyle(style: .paper))
        .disabled(isLoadingPlans)
        .accessibilityValue(isPurchasing ? Text("onboarding.plus.a11y.loading") : Text(verbatim: ""))
        .accessibilityIdentifier("onboarding.plus.cta")
    }
}
