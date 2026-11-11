import SwiftUI

/// The five stamps of the Welcome fan with the postmark, cancellation waves and sparkles, laid out in the 402 pt wide
/// design canvas (`WelcomeMetrics`). `idleSince` is when the intro finished; nil while it plays or when motion is off.
struct StampFan: View {
    let stamps: [WelcomeStamp]
    /// True when only the hero stamp and its postmark show (accessibility sizes).
    var heroOnly = false
    let shown: Set<WelcomeIntroTimeline.Beat>
    let instant: Bool
    let tilt: TiltParallax
    let date: String
    var idleSince: Date?

    var body: some View {
        TimelineView(.animation(paused: idleSince == nil)) { context in
            let time = idleTime(at: context.date)
            ZStack(alignment: .topLeading) {
                ForEach(visibleStamps) { stamp in
                    stampView(stamp, time: time)
                }
                if !heroOnly { sparkles(time: time) }
                postmark
                waves
            }
        }
        .frame(width: WelcomeMetrics.canvas.width, height: WelcomeMetrics.fanHeight, alignment: .topLeading)
    }

    private var visibleStamps: [WelcomeStamp] { heroOnly ? stamps.filter { $0.slot.isHero } : stamps }

    private func idleTime(at date: Date) -> TimeInterval? { idleSince.map { date.timeIntervalSince($0) } }

    private func beat(for slot: WelcomeMetrics.FanSlot) -> WelcomeIntroTimeline.Beat {
        switch slot {
        case .rome: .rome
        case .newYork: .newYork
        case .santorini: .santorini
        case .kyoto: .kyoto
        case .paris: .paris
        }
    }

    private func stampView(_ stamp: WelcomeStamp, time: TimeInterval?) -> some View {
        let slot = stamp.slot
        let frame = slot.containerFrame
        let float = time.map { WelcomeIntroTimeline.Idle.floatOffset(at: $0, order: slot.order) } ?? 0
        let sweep = slot.isHero ? time.map { WelcomeIntroTimeline.Idle.sweepProgress(at: $0) } ?? -1 : -1
        return FanStampView(stamp: stamp)
            .foilSheen(progress: sweep, in: PerforatedStampShape(perforationsAcrossWidth: 12))
            .shadow(color: slot.isHero ? WelcomeColor.stampShadowHero : WelcomeColor.stampShadow, radius: slot.isHero ? 9 : 6,
                    y: slot.isHero ? 14 : 10)
            .rotationEffect(.degrees(slot.rotation))
            .modifier(FanDropEffect(played: shown.contains(beat(for: slot)), instant: instant))
            .offset(x: TiltParallax.offset(tilt.tilt.x, limit: slot.parallax),
                    y: float + TiltParallax.offset(tilt.tilt.y, limit: slot.parallax))
            .offset(x: frame.minX, y: frame.minY)
            .zIndex(slot.depth == .back ? 0 : slot.depth == .mid ? 1 : 2)
    }

    private var postmark: some View {
        let frame = WelcomeMetrics.postmarkFrame.offsetBy(dx: 0, dy: -WelcomeMetrics.fanTop)
        return StampPostmark(top: stamps.first { $0.slot.isHero }?.label ?? "", bottom: date, style: .welcome,
                             size: WelcomeMetrics.postmarkFrame.width, ink: WelcomeColor.postmark)
            .opacity(0.95)
            .rotationEffect(.degrees(WelcomeMetrics.postmarkRotation))
            .modifier(PostmarkPressEffect(played: shown.contains(.postmark), instant: instant))
            .offset(x: TiltParallax.offset(tilt.tilt.x, limit: WelcomeMetrics.postmarkParallax),
                    y: TiltParallax.offset(tilt.tilt.y, limit: WelcomeMetrics.postmarkParallax))
            .offset(x: frame.minX, y: frame.minY)
            .zIndex(3)
    }

    private var waves: some View {
        let frame = WelcomeMetrics.wavesFrame.offsetBy(dx: 0, dy: -WelcomeMetrics.fanTop)
        return CancellationWaves(progress: shown.contains(.waves) ? 1 : 0)
            .rotationEffect(.degrees(WelcomeMetrics.wavesRotation))
            .offset(x: frame.minX, y: frame.minY)
            .zIndex(3)
    }

    private func sparkles(time: TimeInterval?) -> some View {
        ForEach(Array(WelcomeMetrics.sparkles.enumerated()), id: \.offset) { index, rect in
            let frame = rect.offsetBy(dx: 0, dy: -WelcomeMetrics.fanTop)
            Sparkle(size: rect.width, opacity: shown.contains(.paris) ? time.map { WelcomeIntroTimeline.Idle.twinkle(at: $0, order: index) } ?? 1 : 0)
                .offset(x: frame.minX, y: frame.minY)
                .zIndex(3)
        }
    }
}
