import SwiftUI

/// The passport as one tappable object in one frame: closed (the cover) or open at page 1. The cover swings about its
/// spine edge while the page grows out of the middle. Both are bitmaps; only transforms and opacity animate.
struct PassportHero: View {
    let isOpen: Bool
    let content: ReadyContent
    let cover: CoverStyle
    let entrance: BeatPlayer<ReadyTimeline.Beat>
    let reduceMotion: Bool
    let onTap: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    static let frameSize = CGSize(width: 316, height: 352)
    private static let swing = Animation.timingCurve(0.45, 0.05, 0.25, 1, duration: 0.8)

    var body: some View {
        Button(action: onTap) {
            ZStack {
                page
                coverView
            }
            .frame(width: Self.frameSize.width, height: Self.frameSize.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(isOpen ? "onboarding.ready.a11y.value.open" : "onboarding.ready.a11y.value.closed"))
        .accessibilityHint(Text(isOpen ? "onboarding.ready.a11y.hint.close" : "onboarding.ready.a11y.hint.open"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("onboarding.ready.hero")
    }

    // MARK: Layers

    private var page: some View {
        PassportHolderPage(content: content, entrance: entrance, reduceMotion: reduceMotion)
            .overlay { hairline(cornerRadius: 20) }
            .shadow(color: OnbColor.shadowDeep, radius: 11, y: 24)
            .scaleEffect(isOpen || reduceMotion ? 1 : 0.65)
            .opacity(isOpen ? 1 : 0)
            .animation(pageAnimation, value: isOpen)
    }

    private var coverView: some View {
        PassportCover(style: cover, holderName: content.holderName ?? "", showsPageBlock: true)
            .overlay { hairline(cornerRadius: 12) }
            .shadow(color: OnbColor.shadowDeep, radius: 12, y: 26)
            .rotation3DEffect(.degrees(isOpen && !reduceMotion ? -112 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 1.1)
            .animation(reduceMotion ? nil : Self.swing.delay(isOpen ? 0 : 0.15), value: isOpen)
            .opacity(isOpen ? 0 : 1)
            .animation(coverFade, value: isOpen)
            .opacity(entrance.has(.cover) ? 1 : 0)
            .offset(y: entrance.has(.cover) || reduceMotion ? 0 : 46)
            .allowsHitTesting(false)
    }

    private var pageAnimation: Animation? {
        if reduceMotion { return .easeInOut(duration: 0.25) }
        return isOpen ? .timingCurve(0.3, 1.25, 0.4, 1, duration: 0.85).delay(0.3) : .easeIn(duration: 0.55)
    }

    private var coverFade: Animation {
        if reduceMotion { return .easeInOut(duration: 0.25) }
        return isOpen ? .easeIn(duration: 0.28).delay(0.36) : .easeOut(duration: 0.26).delay(0.30)
    }

    /// Under Increase Contrast a 1.5 pt hairline outlines the page and the cover.
    @ViewBuilder
    private func hairline(cornerRadius: CGFloat) -> some View {
        if contrast == .increased {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(OnbColor.inkPrimary.opacity(0.45), lineWidth: 1.5)
        }
    }

    private var label: Text {
        let coverName = Bundle.main.localizedString(forKey: cover.nameKey, value: nil, table: nil)
        if isOpen {
            var text = Text("onboarding.ready.a11y.open \(content.holderName ?? String(localized: "onboarding.ready.name.placeholder")) \(content.stampCount)")
            if let stamp = content.firstStamp { text = text + Text(verbatim: " ") + Text("onboarding.ready.a11y.slot \(stamp.destination.name)") }
            return text
        }
        if let name = content.holderName { return Text("onboarding.ready.a11y.closed.name \(coverName) \(name)") }
        return Text("onboarding.ready.a11y.closed \(coverName)")
    }
}
