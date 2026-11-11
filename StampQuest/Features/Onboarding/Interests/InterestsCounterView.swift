import SwiftUI

/// "{n} picked. You can change this any time." with the number rolling on every change, or the prompt while nothing is
/// picked.
struct InterestsCounterView: View {
    let picked: Int

    @ScaledMetric(relativeTo: .footnote) private var size = 13.0

    var body: some View {
        Group {
            if picked == 0 {
                Text("onboarding.interests.hint.none")
            } else {
                Text("onboarding.interests.hint.count \(picked)")
                    .contentTransition(.numericText(value: Double(picked)))
            }
        }
        .font(.system(size: size, weight: .medium))
        .tracking(-0.006 * size)
        .foregroundStyle(OnbColor.inkTertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: picked)
        .accessibilityIdentifier("onboarding.interests.hint")
    }
}
