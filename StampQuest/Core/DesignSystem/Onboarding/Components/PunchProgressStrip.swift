import SwiftUI

/// Dot size, spacing and colours of a `PunchProgressStrip`.
struct PunchStripStyle {
    var holeSize: CGFloat
    var ringWidth: CGFloat
    var holeGap: CGFloat
    var groupGap: CGFloat
    var on: Color
    var off: Color
    /// Scale a dot starts from when it fills.
    var popScale: CGFloat
    var pop: Animation = .easeOut(duration: 0.32)

    static let onboarding = PunchStripStyle(holeSize: 3.5, ringWidth: 0.8, holeGap: 2.5, groupGap: 8, on: OBColor.accent,
                                            off: OBColor.hole, popScale: 0.6)
    /// The Welcome poster: bigger dots on the terracotta or charcoal background.
    static let welcome = PunchStripStyle(holeSize: 4.4, ringWidth: 1.1, holeGap: 3, groupGap: 9, on: WelcomeColor.progressOn,
                                         off: WelcomeColor.progressOff, popScale: 0.2)
}

/// 25 tiny holes in 5 groups of 5 (spec 5.2). Completed groups are filled; the current group fills in order,
/// 0.32 s per hole with 0.07 s stagger. Total width is about 170 pt with the default style.
struct PunchProgressStrip: View {
    let step: Int
    let of: Int
    /// False when revisiting a completed step: show the final state with no replayed animation.
    var animated = true
    var style = PunchStripStyle.onboarding
    /// False holds the current group empty until it turns true (the Welcome intro pops the dots at a set time).
    var fillsCurrent = true
    /// A spoken label that replaces "Step n of 5" (the last screen says all steps are done).
    var accessibilityLabelKey: LocalizedStringKey?

    @Environment(\.obReducesMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var currentFilled: Bool

    static let holesPerGroup = 5

    init(step: Int, of: Int = 5, animated: Bool = true, style: PunchStripStyle = .onboarding, fillsCurrent: Bool = true,
         accessibilityLabelKey: LocalizedStringKey? = nil) {
        self.accessibilityLabelKey = accessibilityLabelKey
        self.step = step
        self.of = of
        self.animated = animated
        self.style = style
        self.fillsCurrent = fillsCurrent
        _currentFilled = State(initialValue: !animated)
    }

    var body: some View {
        HStack(spacing: style.groupGap) {
            ForEach(0..<of, id: \.self) { group in
                HStack(spacing: style.holeGap) {
                    ForEach(0..<Self.holesPerGroup, id: \.self) { hole in
                        punch(group: group, hole: hole)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelKey.map { Text($0) } ?? Text("onboarding.progress.label \(step) \(of)"))
        .accessibilityIdentifier("onboarding.progressStrip")
        .task(id: [step, fillsCurrent ? 1 : 0]) {
            guard animated, !reduceMotion else { currentFilled = fillsCurrent; return }
            currentFilled = false
            try? await Task.sleep(for: .milliseconds(30))
            currentFilled = fillsCurrent
        }
    }

    private func punch(group: Int, hole: Int) -> some View {
        let isCurrent = group == step - 1
        let filled = group < step - 1 || (isCurrent && currentFilled)
        let delay = Double(hole) * 0.07
        return Circle()
            .fill(filled ? style.on : .clear)
            .overlay { Circle().strokeBorder(style.off, lineWidth: contrast == .increased ? 1.1 : style.ringWidth).opacity(filled ? 0 : 1) }
            .frame(width: style.holeSize, height: style.holeSize)
            .scaleEffect(isCurrent && !filled ? style.popScale : 1)
            .animation(reduceMotion || !animated ? nil : style.pop.delay(delay), value: filled)
    }
}

extension PunchStripStyle {
    /// The Interests screen: the Welcome dot size on the paper background, popping with a spring.
    static let interests = PunchStripStyle(holeSize: 4.4, ringWidth: 1.1, holeGap: 3, groupGap: 9, on: OnbColor.accent,
                                           off: OnbColor.inkTertiary.opacity(0.34), popScale: 0.2,
                                           pop: .spring(response: 0.42, dampingFraction: 0.6))
}

#Preview("PunchProgressStrip") {
    PreviewMatrix {
        VStack(spacing: 12) {
            ForEach(1...5, id: \.self) { PunchProgressStrip(step: $0, animated: false) }
        }
        .padding().background(OBColor.paper)
    }
}
