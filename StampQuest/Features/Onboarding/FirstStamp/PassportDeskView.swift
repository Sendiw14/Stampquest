import SwiftUI

/// The tilted passport page with its six slots and, below it, the three starter stamps on the desk, laid out in the
/// 402 pt design canvas (`FirstStampMetrics`). The collected stamp is one view that flies from the desk to slot 1 in an
/// overlay above the page and stays there.
struct PassportDeskView: View {
    let desk: [StarterStamp]
    let viewModel: FirstStampViewModel
    let choreo: FirstStampChoreographer
    let reduceMotion: Bool
    /// Float and pulse run only while true (not under Reduce Motion or Low Power Mode, nothing collected yet).
    let idleAllowed: Bool
    /// The page and the collected stamp only: the starters are listed elsewhere (accessibility sizes).
    var pageOnly = false
    let postmarkDate: String
    let onTouchDown: () -> Void
    let onTap: (StarterStamp) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var instant: Bool { reduceMotion || choreo.isInstant }

    var body: some View {
        TimelineView(.animation(paused: !idleAllowed || viewModel.isCollected)) { context in
            let time = context.date.timeIntervalSince(choreo.entranceStart)
            ZStack(alignment: .topLeading) {
                glow
                page
                if !pageOnly { starters(time: time) }
                if let collected = viewModel.collected { flyer(collected) }
            }
        }
        .frame(width: FirstStampMetrics.canvasWidth, height: pageOnly ? FirstStampMetrics.pageFrame.height + 30 : FirstStampMetrics.deskHeight,
               alignment: .topLeading)
    }

    // MARK: Page

    private var page: some View {
        PassportPageView(width: FirstStampMetrics.pageFrame.width, height: FirstStampMetrics.pageFrame.height,
                         pageNumber: String(localized: "onboarding.firstStamp.page.number"),
                         tilt: .degrees(FirstStampMetrics.pageTilt), contentInsets: EdgeInsets()) {
            ZStack(alignment: .topLeading) {
                ForEach(0..<FirstStampMetrics.slotCount, id: \.self) { index in
                    slot(index)
                }
                ripple
            }
        }
        .modifier(PagePressEffect(trigger: reduceMotion ? 0 : choreo.contactCount))
        .offset(x: FirstStampMetrics.pageFrame.minX, y: FirstStampMetrics.pageFrame.minY)
        .modifier(FadeUp(shown: choreo.has(.page)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("onboarding.firstStamp.a11y.page"))
        .accessibilityValue(Text("onboarding.firstStamp.a11y.pageValue \(viewModel.isCollected ? 1 : 0)"))
        .accessibilityIdentifier("onboarding.firstStamp.page")
    }

    private func slot(_ index: Int) -> some View {
        let frame = FirstStampMetrics.slotFrame(index)
        let kind: PassportSlotView.Kind = index == 0 ? .hot(pulsing: pulses) : .empty
        return PassportSlotView(kind: kind)
            .opacity(index == 0 && choreo.has(.contact) ? 0 : 1)
            .modifier(FadeUp(shown: choreo.has(.slot(index)), rise: 0))
            .offset(x: frame.minX, y: frame.minY)
    }

    /// The hot ring pulses while nothing has been picked.
    private var pulses: Bool { idleAllowed && viewModel.active == nil && choreo.has(.slot(0)) }

    private var ripple: some View {
        let frame = FirstStampMetrics.slotFrame(0)
        return RoundedRectangle(cornerRadius: 7)
            .stroke(OnbColor.accent, lineWidth: 2)
            .frame(width: frame.width, height: frame.height)
            .modifier(RippleEffect(trigger: reduceMotion ? 0 : choreo.contactCount, delay: 0))
            .offset(x: frame.minX, y: frame.minY)
            .allowsHitTesting(false)
    }

    private var glow: some View {
        let center = FirstStampMetrics.slotCenter(0)
        return Circle()
            .fill(RadialGradient(colors: [OnbColor.screenGlow, OnbColor.screenGlow.opacity(0)], center: .center, startRadius: 0, endRadius: 105))
            .frame(width: 210, height: 210)
            .offset(x: center.x - 105, y: center.y - 105)
            .opacity(choreo.has(.contact) ? 1 : 0)
            .accessibilityHidden(true)
    }

    // MARK: Starters

    private func origin(of starter: StarterStamp) -> CGPoint {
        let rank = desk.firstIndex(of: starter) ?? 0
        return FirstStampMetrics.starterOrigins[min(rank, FirstStampMetrics.starterOrigins.count - 1)]
    }

    private func starters(time: TimeInterval) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(desk) { starter in
                let point = origin(of: starter)
                let isCollected = viewModel.collected == starter
                ghostSlot(starter).offset(x: point.x, y: point.y)
                starterButton(starter, time: time)
                    .offset(x: point.x - 8, y: point.y)
                    .zIndex(isCollected ? 0 : 1)
            }
        }
    }

    private func starterButton(_ starter: StarterStamp, time: TimeInterval) -> some View {
        let index = desk.firstIndex(of: starter) ?? 0
        let dimmed = viewModel.isCollected && viewModel.collected != starter
        let ownCollected = viewModel.collected == starter
        let floatOrder = [StarterStamp.kyoto, .santorini].firstIndex(of: starter)
        let float = floatOrder.map { WelcomeIntroTimeline.Idle.floatOffset(at: max(0, time - FirstStampEntrance.floatStarts[$0]), order: $0 + 1) } ?? 0
        return StarterStampButton(
            starter: starter, isBusy: viewModel.phase == .saving(starter), showsStamp: !ownCollected,
            isDimmed: dimmed && choreo.has(.recede), pillDimmed: viewModel.isCollected && choreo.has(.pillsDim),
            failureCount: viewModel.active == starter ? viewModel.failureCount : 0,
            reduceMotion: reduceMotion, stampShown: choreo.has(.starter(index)), pillShown: choreo.has(.pill(index)),
            instant: instant, onTouchDown: onTouchDown, onTap: { onTap(starter) })
            .offset(y: idleAllowed && !viewModel.isCollected ? float : 0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(dimmed ? "onboarding.firstStamp.a11y.starterDimmed \(starter.destination.name) \(starter.destination.country)"
                                            : "onboarding.firstStamp.a11y.starter \(starter.destination.name) \(starter.destination.country)"))
            .accessibilityHint(Text("onboarding.firstStamp.a11y.starterHint \(starter.destination.name)"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(starter.accessibilityIdentifier)
            .disabled(!viewModel.canTap)
    }

    /// The empty slot the collected stamp leaves behind on the desk.
    private func ghostSlot(_ starter: StarterStamp) -> some View {
        PassportSlotView(kind: .empty, size: FirstStampMetrics.starterSize, pitch: FirstStampMetrics.starterPitch)
            .rotationEffect(.degrees(starter.deskRotation))
            .opacity(viewModel.collected == starter && choreo.has(.ghostSlot) ? 1 : 0)
    }

    // MARK: Flight

    private func flyer(_ starter: StarterStamp) -> some View {
        let point = origin(of: starter)
        return StarterStampCard(starter: starter, showsNumber: !choreo.has(.postmark))
            .rotationEffect(.degrees(starter.deskRotation))
            .modifier(StampFlightEffect(trigger: choreo.flightTrigger, instant: instant, target: FirstStampMetrics.landing(from: point),
                                        finalScale: FirstStampMetrics.collectedScale,
                                        finalRotation: StarterStamp.collectedRotation - starter.deskRotation))
            .frame(width: FirstStampMetrics.starterSize.width, height: FirstStampMetrics.starterSize.height)
            .overlay(alignment: .topLeading) { if choreo.has(.postmark) { postmark(starter) } }
            .offset(x: point.x, y: point.y)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("onboarding.firstStamp.a11y.slotFilled \(starter.destination.name)"))
            .accessibilityIdentifier("onboarding.firstStamp.slot1")
    }

    private func postmark(_ starter: StarterStamp) -> some View {
        let slot = FirstStampMetrics.slotCenter(0), point = origin(of: starter)
        let size = FirstStampMetrics.postmarkSize
        let x = slot.x + FirstStampMetrics.slotSize.width / 2 - 34 - point.x + StampPostmark.labelClearance.width
        let y = slot.y + FirstStampMetrics.slotSize.height / 2 - 58 - point.y + StampPostmark.labelClearance.height
        return StampPostmark(top: starter.destination.label, bottom: postmarkDate, style: .picked, size: size, ink: OnbColor.postmark)
            .opacity(0.93)
            .modifier(PostmarkThumpEffect(instant: instant, delay: 0))
            .rotationEffect(.degrees(FirstStampMetrics.postmarkRotation))
            .offset(x: x, y: y)
    }
}
