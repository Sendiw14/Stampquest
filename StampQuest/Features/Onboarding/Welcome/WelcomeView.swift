import SwiftUI

/// Welcome (step 1 of 5): a poster whose headline words are stamped on one by one, followed by a fan of stamps, a
/// postmark and the call to action. Reads nothing but the model's progress and writes nothing.
struct WelcomeView: View {
    let model: OnboardingModel

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    @ScaledMetric(relativeTo: .largeTitle) private var headlineScaled = WelcomeMetrics.headlineSize
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @ScaledMetric(relativeTo: .headline) private var wordmarkSize = 17.0
    @ScaledMetric(relativeTo: .footnote) private var captionSize = 13.0

    @State private var player = WelcomeIntroPlayer()
    @State private var tilt = TiltParallax()
    @State private var stamps: [WelcomeStamp] = []
    @State private var visible = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private let postmarkDate = OnboardingFormat.stampDate(.now)

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var idleAllowed: Bool { !reduceMotion && !lowPower }
    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }
    private var idleSince: Date? { idleAllowed ? player.idleSince : nil }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                WelcomeBackground()
                if isAccessibilitySize {
                    accessibleLayout(width: proxy.size.width)
                } else {
                    posterLayout(proxy)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { player.skip() }
            .simultaneousGesture(tiltDrag)
        }
        .opacity(visible ? 1 : 0)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await start() }
        .onChange(of: idleSince) { _, since in
            if since == nil { tilt.stop() } else { tilt.start(env.parallax) }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { player.skip() } }
        .onDisappear { tilt.stop() }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    // MARK: Poster layout

    private func posterLayout(_ proxy: GeometryProxy) -> some View {
        // The proxy is inside the safe area; the scale is measured on the whole screen.
        let insets = proxy.safeAreaInsets
        let screen = CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                            height: proxy.size.height + insets.top + insets.bottom)
        let k = WelcomeMetrics.scale(for: screen)
        let originX = (proxy.size.width - WelcomeMetrics.canvas.width * k) / 2
        let topY = -WelcomeMetrics.designSafeTop * k
        let bottomInset = WelcomeMetrics.ctaBottomInset(scale: k) - WelcomeMetrics.finePrintBlockHeight * k
        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                topRow.frame(width: WelcomeMetrics.canvas.width - WelcomeMetrics.sideMargin * 2)
                    .offset(x: WelcomeMetrics.sideMargin, y: WelcomeMetrics.topRowY)
                headline(size: min(headlineScaled, WelcomeMetrics.headlineSize * 1.12), maxLines: WelcomeMetrics.headlineLineCount)
                    .offset(x: WelcomeMetrics.sideMargin, y: WelcomeMetrics.headlineY)
                fan(heroOnly: false).offset(y: WelcomeMetrics.fanTop)
            }
            .frame(width: WelcomeMetrics.canvas.width, height: WelcomeMetrics.fanTop + WelcomeMetrics.fanHeight, alignment: .topLeading)
            .scaleEffect(k, anchor: .topLeading)
            .offset(x: originX, y: topY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                subtitle.padding(.bottom, WelcomeMetrics.subtitleToCTA)
                cta
                finePrint.padding(.top, WelcomeMetrics.ctaToFinePrint)
            }
            .frame(width: WelcomeMetrics.canvas.width)
            .scaleEffect(k, anchor: .bottomLeading)
            .offset(x: originX, y: -bottomInset)
        }
    }

    // MARK: Accessibility-size layout

    private func accessibleLayout(width: CGFloat) -> some View {
        let fanScale = min(1, (width - WelcomeMetrics.sideMargin * 2) / WelcomeMetrics.canvas.width)
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits {
                    topRow
                    VStack(alignment: .leading, spacing: 12) { wordmark; progress }
                }
                headline(size: headlineScaled, maxLines: nil)
                fan(heroOnly: true)
                    .frame(width: WelcomeMetrics.canvas.width, height: WelcomeMetrics.fanHeight, alignment: .topLeading)
                    .scaleEffect(fanScale, anchor: .topLeading)
                    .frame(width: WelcomeMetrics.canvas.width * fanScale, height: WelcomeMetrics.fanHeight * fanScale,
                           alignment: .topLeading)
                subtitle
            }
            .padding(.horizontal, WelcomeMetrics.sideMargin)
            .padding(.top, 64)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: WelcomeMetrics.ctaToFinePrint) {
                cta
                finePrint
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    // MARK: Pieces

    private var topRow: some View {
        HStack(spacing: 0) {
            wordmark
            Spacer(minLength: 12)
            progress
        }
    }

    private var wordmark: some View {
        HStack(spacing: 8) {
            StarShape().fill(WelcomeColor.highlight).frame(width: 16, height: 16).accessibilityHidden(true)
            Text("onboarding.welcome.wordmark")
                .font(.system(size: wordmarkSize, weight: .semibold))
                .tracking(-0.01 * wordmarkSize)
                .foregroundStyle(WelcomeColor.textPrimary)
        }
        .modifier(FadeUp(shown: player.shown.contains(.topRow)))
        .accessibilitySortPriority(0)
        .accessibilityIdentifier("onboarding.welcome.wordmark")
    }

    private var progress: some View {
        PunchProgressStrip(step: OnboardingRoute.welcomeProgressStep, of: OnboardingRoute.progressStepCount,
                           style: .welcome, fillsCurrent: player.shown.contains(.progress))
            .modifier(FadeUp(shown: player.shown.contains(.topRow)))
            .accessibilitySortPriority(5)
    }

    private func headline(size: CGFloat, maxLines: Int?) -> some View {
        StampWordHeadline(markup: String(localized: "onboarding.welcome.headline"), size: size, maxLines: maxLines,
                          shown: player.shown, instant: player.instant, tilt: tilt)
            .frame(width: WelcomeMetrics.canvas.width - WelcomeMetrics.sideMargin * 2, alignment: .topLeading)
            .frame(maxWidth: isAccessibilitySize ? .infinity : nil, alignment: .topLeading)
            .accessibilitySortPriority(4)
    }

    private func fan(heroOnly: Bool) -> some View {
        StampFan(stamps: stamps, heroOnly: heroOnly, shown: player.shown, instant: player.instant, tilt: tilt,
                 date: postmarkDate, idleSince: idleSince)
            .animation(.smooth(duration: 0.12), value: tilt.tilt)
            .accessibilityHidden(true)
    }

    private var subtitle: some View {
        Text("onboarding.welcome.subtitle")
            .font(.system(size: bodySize))
            .tracking(-0.011 * bodySize)
            .lineSpacing(3.4)
            .foregroundStyle(WelcomeColor.textSecondary)
            .frame(maxWidth: isAccessibilitySize ? .infinity : WelcomeMetrics.canvas.width - WelcomeMetrics.sideMargin * 2,
                   alignment: .leading)
            .padding(.leading, isAccessibilitySize ? 0 : WelcomeMetrics.sideMargin)
            .modifier(FadeUp(shown: player.shown.contains(.subtitle)))
            .accessibilitySortPriority(3)
            .accessibilityIdentifier("onboarding.welcome.subtitle")
    }

    private var cta: some View {
        PrimaryCapsuleButton(title: "onboarding.welcome.cta", identifier: "onboarding.welcome.cta") { model.continueFrom(nil) }
            .padding(.horizontal, isAccessibilitySize ? 0 : 24)
            .modifier(FadeUp(shown: player.shown.contains(.cta)))
            .allowsHitTesting(player.shown.contains(.cta))
            .accessibilitySortPriority(2)
    }

    private var finePrint: some View {
        Text("onboarding.welcome.caption")
            .font(.system(size: captionSize, weight: .medium))
            .foregroundStyle(WelcomeColor.textTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .modifier(FadeUp(shown: player.shown.contains(.finePrint)))
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("onboarding.welcome.caption")
    }

    // MARK: Motion

    private var tiltDrag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard idleSince != nil, tilt.usesDragFallback else { return }
                tilt.drag(value.translation)
            }
            .onEnded { _ in
                guard tilt.usesDragFallback else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tilt.release() }
            }
    }

    /// Plays the intro; Reduce Motion and a returning visit show the rest state at once.
    private func start() async {
        stamps = WelcomeStamp.fan(catalog: env.catalog)
        let animated = !reduceMotion && !model.isRevisit(nil)
        if animated {
            visible = true
        } else {
            withAnimation(.easeInOut(duration: reduceMotion ? WelcomeIntroTimeline.reducedMotionFade : 0)) { visible = true }
        }
        await player.play(animated: animated, haptics: WelcomeHaptics(service: env.haptics, isEnabled: !reduceMotion))
    }
}
