import SwiftUI

/// First stamp (step 3 of 5): pick a stamp, it is saved, and only then does it fly onto the passport page. Any tap
/// during the reveal jumps to the final state.
struct FirstStampScreen: View {
    enum Focus: Hashable { case headline, retry }

    @State private var viewModel: FirstStampViewModel
    @State private var choreo = FirstStampChoreographer()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @AccessibilityFocusState private var focus: Focus?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 16.0

    private let model: OnboardingModel
    private let postmarkDate = OnboardingFormat.stampDate(.now)

    init(model: OnboardingModel) {
        self.model = model
        _viewModel = State(initialValue: FirstStampViewModel(model: model))
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }
    private var idleAllowed: Bool { !reduceMotion && !lowPower }
    private var textVisible: Bool { !choreo.has(.textOut) || choreo.has(.textIn) }
    private var collectedText: Bool { choreo.has(.textIn) }
    private var ctaEnabled: Bool { viewModel.isCollected && choreo.has(.ctaEnabled) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperGlowBackground(glowHeight: 0.28, glowCenterY: 0.55)
                VStack(spacing: 0) {
                    topBar
                    ScrollView {
                        content(screen: proxy.size)
                            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: interrupt)
        }
        .task { await start() }
        .onChange(of: viewModel.phase) { old, new in phaseChanged(from: old, to: new) }
        .onChange(of: viewModel.isNavigationLocked) { _, locked in SwipeBackDelegate.shared.isLocked = locked }
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.snapToCollectedIfSaved() } }
        .onDisappear { SwipeBackDelegate.shared.isLocked = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    // MARK: Layout

    private var topBar: some View {
        OnboardingTopBar(screen: "firstStamp", step: 3, animatesStrip: !model.isRevisit(.firstStamp), fillsStrip: choreo.has(.progress),
                         backShown: choreo.has(.back), skipShown: choreo.has(.skip), stripShown: true,
                         onBack: { if !viewModel.isNavigationLocked { model.back() } },
                         onSkip: { if !viewModel.isNavigationLocked { model.skip(from: .firstStamp) } })
            .padding(.top, InterestsMetrics.topBarTop)
            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    private func content(screen: CGSize) -> some View {
        let scale = FirstStampMetrics.scale(for: screen)
        return VStack(alignment: .leading, spacing: 0) {
            FirstStampHeadline(collected: collectedText, textVisible: textVisible, choreo: choreo)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .accessibilityFocused($focus, equals: .headline)
                .padding(.horizontal, InterestsMetrics.sideMargin)
                .padding(.top, FirstStampMetrics.headlineTop)
            subtitle
                .padding(.horizontal, InterestsMetrics.sideMargin)
                .padding(.top, FirstStampMetrics.subtitleTop)
            if isAccessibilitySize { accessibleDesk(screen: screen) } else { desk(scale: scale) }
            FirstStampNote(viewModel: viewModel, collected: collectedText, textVisible: textVisible, shown: choreo.has(.note),
                           focusRetry: $focus, onRetry: retry)
                .padding(.horizontal, InterestsMetrics.sideMargin)
                .padding(.top, FirstStampMetrics.noteTop)
                .padding(.bottom, 12)
        }
    }

    private var subtitle: some View {
        Group {
            if let collected = viewModel.collected, collectedText {
                Text("onboarding.firstStamp.subtitle.done \(collected.destination.name)")
            } else {
                Text("onboarding.firstStamp.subtitle.choose")
            }
        }
        .font(.system(size: subtitleSize))
        .tracking(-0.011 * subtitleSize)
        .lineSpacing(3.4)
        .lineLimit(2, reservesSpace: true)
        .foregroundStyle(OnbColor.inkSecondary)
        .frame(maxWidth: InterestsMetrics.subtitleMaxWidth, alignment: .topLeading)
        .opacity(textVisible ? 1 : 0)
        .offset(y: textVisible ? 0 : -6)
        .modifier(FadeUp(shown: choreo.has(.subtitle)))
        .accessibilityIdentifier("onboarding.firstStamp.subtitle")
    }

    private func desk(scale: CGFloat) -> some View {
        deskView(pageOnly: false)
            .frame(width: FirstStampMetrics.canvasWidth, height: FirstStampMetrics.deskHeight, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: FirstStampMetrics.canvasWidth * scale, height: FirstStampMetrics.deskHeight * scale, alignment: .topLeading)
            .padding(.top, FirstStampMetrics.deskTop * scale)
            .frame(maxWidth: .infinity)
    }

    /// Accessibility sizes: the page scaled to the width, then the starters as full-width rows.
    private func accessibleDesk(screen: CGSize) -> some View {
        let scale = min(1, (screen.width - InterestsMetrics.sideMargin * 2) / FirstStampMetrics.canvasWidth)
        let height = FirstStampMetrics.pageFrame.height + 30
        return VStack(spacing: 8) {
            deskView(pageOnly: true)
                .frame(width: FirstStampMetrics.canvasWidth, height: height, alignment: .topLeading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: FirstStampMetrics.canvasWidth * scale, height: height * scale, alignment: .topLeading)
            ForEach(viewModel.desk) { starter in
                StarterStampRow(starter: starter, isDimmed: viewModel.isCollected && viewModel.collected != starter) { pick(starter) }
                    .disabled(!viewModel.canTap)
            }
        }
        .padding(.horizontal, InterestsMetrics.sideMargin)
        .padding(.top, 24)
    }

    private func deskView(pageOnly: Bool) -> some View {
        PassportDeskView(desk: viewModel.desk, viewModel: viewModel, choreo: choreo, reduceMotion: reduceMotion, idleAllowed: idleAllowed,
                         pageOnly: pageOnly, postmarkDate: postmarkDate, onTouchDown: { env.haptics.lightImpact() }, onTap: pick)
            .animation(.easeOut(duration: 0.25), value: viewModel.failureCount)
    }

    private var bottomBar: some View {
        FirstStampContinueButton(isEnabled: ctaEnabled, shown: choreo.has(.cta)) { model.continueFrom(.firstStamp) }
            .padding(.horizontal, InterestsMetrics.sideMargin)
            .padding(.top, 12)
            .padding(.bottom, FirstStampMetrics.ctaBottomGap)
            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    // MARK: Actions

    private func pick(_ starter: StarterStamp) {
        guard viewModel.canTap else { return }
        Task { await viewModel.tap(starter) }
    }

    private func retry() { Task { await viewModel.retry() } }

    /// A tap anywhere during the reveal jumps to the final state, firing the success haptic if it has not fired yet.
    private func interrupt() {
        guard viewModel.interruptReveal() else { return }
        choreo.snapReveal()
        fireSuccessHaptic()
    }

    private func fireSuccessHaptic() {
        if viewModel.consumeSuccessHaptic() { env.haptics.success() }
    }

    private func phaseChanged(from old: FirstStampViewModel.Phase, to new: FirstStampViewModel.Phase) {
        switch new {
        case .collected(let starter):
            let animated = !reduceMotion && !isAccessibilitySize && !viewModel.isRestored
            choreo.startReveal(animated: animated, fade: RevealChoreography.reducedFade, onContact: fireSuccessHaptic,
                               onFinished: viewModel.revealFinished)
            AccessibilityNotification.Announcement(String(localized: "onboarding.firstStamp.a11y.collected \(starter.destination.name)")).post()
            focus = .headline
        case .failed:
            env.haptics.error()
            AccessibilityNotification.Announcement(String(localized: "onboarding.firstStamp.status.error")).post()
            focus = .retry
        case .choosing, .saving:
            break
        }
    }

    /// Plays the entrance once. Reduce Motion gets a single 0.2 s fade; a restored or revisited screen shows everything at once.
    private func start() async {
        let restored = viewModel.isRestored || model.isRevisit(.firstStamp)
        let animated = !reduceMotion && !restored
        if viewModel.isCollected {
            choreo.startReveal(animated: false, fade: 0, onContact: {}, onFinished: {})
        }
        await choreo.playEntrance(animated: animated, fade: reduceMotion ? 0.2 : 0)
    }
}
