import SwiftUI

/// The open passport page: the holder, when it was issued and how many stamps it holds, a 3 x 2 grid of slots with the
/// first stamp and its postmark in the first, and "Page 1". It shows only what `ReadyContent` says.
struct PassportHolderPage: View {
    let content: ReadyContent
    let entrance: BeatPlayer<ReadyTimeline.Beat>
    let reduceMotion: Bool

    static let size = CGSize(width: 316, height: 352)
    private static let slotSize = CGSize(width: 66, height: 80)

    var body: some View {
        PassportPageView(width: Self.size.width, height: Self.size.height, pageNumber: "", showsHeaders: false, contentInsets: EdgeInsets()) {
            ZStack(alignment: .topLeading) {
                header
                Path { path in
                    path.move(to: CGPoint(x: 28, y: 124))
                    path.addLine(to: CGPoint(x: 292, y: 124))
                }
                .stroke(OnbColor.passportDash, style: StrokeStyle(lineWidth: 1.1, dash: [2, 4]))
                ForEach(0..<ReadyTimeline.slotCount, id: \.self) { index in slot(index) }
                if let stamp = content.firstStamp { firstStamp(stamp) }
                Text("onboarding.ready.page")
                    .font(.system(size: 11.5, design: .serif).italic())
                    .foregroundStyle(OnbColor.inkSecondary)
                    .frame(width: Self.size.width)
                    .offset(y: 323)
                    .modifier(FadeUp(shown: entrance.has(.footer), rise: 8))
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHidden(true)
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                Circle().stroke(OnbColor.accent.opacity(0.75), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [1.6, 3.2]))
                    .frame(width: 40, height: 40)
                StarShape().fill(OnbColor.accent).frame(width: 20, height: 20)
            }
            .frame(width: 44, height: 44)
            .opacity(entrance.has(.emblem) ? 1 : 0)
            .scaleEffect(entrance.has(.emblem) ? 1 : 0.8)
            .offset(x: 34, y: 28)
            Text("onboarding.ready.holder")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundStyle(OnbColor.inkSecondary)
                .modifier(FadeUp(shown: entrance.has(.holderLabel), rise: 8))
                .offset(x: 90, y: 26)
            nameText
                .modifier(FadeUp(shown: entrance.has(.name), rise: 8))
                .offset(x: 90, y: 40)
            Text("onboarding.ready.issued \(content.issuedText)")
                .font(.system(size: 12.5))
                .foregroundStyle(OnbColor.inkSecondary)
                .modifier(FadeUp(shown: entrance.has(.issued), rise: 8))
                .offset(x: 90, y: 76)
            Text("onboarding.ready.count \(content.stampCount)")
                .font(.system(size: 12.5))
                .foregroundStyle(OnbColor.inkSecondary)
            .modifier(FadeUp(shown: entrance.has(.count), rise: 8))
            .offset(x: 90, y: 92)
        }
    }

    @ViewBuilder
    private var nameText: some View {
        if let name = content.holderName {
            Text(name).font(.system(size: 27, weight: .semibold, design: .serif).italic()).tracking(-0.27).foregroundStyle(OnbColor.inkPrimary)
                .lineLimit(1).minimumScaleFactor(0.6).frame(width: 200, alignment: .leading)
        } else {
            // No name: a muted dotted writing line in the name's slot, never placeholder text.
            Path { path in
                path.move(to: CGPoint(x: 1, y: 30))
                path.addLine(to: CGPoint(x: 199, y: 30))
            }
            .stroke(OnbColor.inkPrimary.opacity(0.25), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [0.1, 4]))
            .frame(width: 200, height: 34, alignment: .topLeading)
            .accessibilityIdentifier("onboarding.ready.nameLine")
        }
    }

    // MARK: Slots

    private func origin(_ index: Int) -> CGPoint {
        CGPoint(x: 39 + CGFloat(index % 3) * (Self.slotSize.width + 20), y: 136 + CGFloat(index / 3) * (Self.slotSize.height + 14))
    }

    private func slot(_ index: Int) -> some View {
        let point = origin(index)
        let nextIndex = content.firstStamp == nil ? 0 : 1
        return PassportSlotView(kind: index == nextIndex ? .hot(pulsing: false) : .empty, size: Self.slotSize, pitch: 8)
            .modifier(FadeUp(shown: index == 0 || entrance.has(.slot(index)), rise: 8))
            .offset(x: point.x, y: point.y)
    }

    private func firstStamp(_ stamp: StarterStamp) -> some View {
        let point = origin(0)
        return ZStack(alignment: .topLeading) {
            if entrance.has(.stamp) {
                StarterStampCard(starter: stamp, size: Self.slotSize, showsNumber: !entrance.has(.postmark))
                    .modifier(StampLandingEffect(instant: entrance.isInstant || reduceMotion, idleSheen: -1))
                    .rotationEffect(.degrees(-2))
                    .shadow(color: OnbColor.shadowSoft, radius: 7, y: 14)
                    .frame(width: Self.slotSize.width, height: Self.slotSize.height)
            }
            if entrance.has(.postmark) {
                RoundedRectangle(cornerRadius: 8).stroke(OnbColor.postmark, lineWidth: 2)
                    .frame(width: Self.slotSize.width + 8, height: Self.slotSize.height + 8)
                    .modifier(RippleEffect(trigger: reduceMotion ? 0 : 1, delay: 0))
                    .offset(x: -4, y: -4)
                StampPostmark(top: content.postmarkTop, bottom: content.postmarkDate, style: .picked, size: 56, ink: OnbColor.postmark)
                    .opacity(0.93)
                    .modifier(PostmarkThumpEffect(instant: entrance.isInstant || reduceMotion, delay: 0))
                    .rotationEffect(.degrees(14))
                    .offset(x: Self.slotSize.width - 29 + StampPostmark.labelClearance.width, y: Self.slotSize.height - 49 + StampPostmark.labelClearance.height)
            }
        }
        .offset(x: point.x, y: point.y)
    }
}
