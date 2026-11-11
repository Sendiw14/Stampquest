import SwiftUI

/// Collected or verified (step 4 of 5): explains the difference between a stamp you add by hand and one you earn by being
/// there, then offers the optional permission. The control is a preview; nothing here is stored until a choice is made.
struct VerificationView: View {
    @State private var viewModel: VerificationViewModel
    @State private var entrance = BeatPlayer<VerificationTimeline.Beat>(schedule: VerificationTimeline.standard.schedule)
    @State private var tilt = TiltParallax()
    @State private var captionKey: VerificationViewModel.Preview = .collected
    @State private var captionVisible = true
    @State private var sealHaptic: Task<Void, Never>?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 16.0
    @ScaledMetric(relativeTo: .headline) private var linkSize = 17.0
    @ScaledMetric(relativeTo: .callout) private var captionSize = 14.0

    private let model: OnboardingModel

    init(model: OnboardingModel, location: LocationProviding) {
        self.model = model
        _viewModel = State(initialValue: VerificationViewModel(model: model, location: location))
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }
    private var exampleDate: String { OnboardingFormat.stampDate(viewModel.exampleDate) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperGlowBackground(glowHeight: 0.3, glowCenterY: 0.4)
                VStack(spacing: 0) {
                    topBar
                    ScrollView {
                        content(height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            }
        }
        .task { await entrance.play(animated: !reduceMotion && !model.isRevisit(.verification), fade: reduceMotion ? 0.2 : 0) }
        .sheet(isPresented: .constant(viewModel.isExplaining), onDismiss: viewModel.explainerDismissed) {
            LocationExplainerSheet(onContinue: { Task { await viewModel.explainerContinued() } }, onNotNow: viewModel.explainerDismissed)
        }
        .onChange(of: viewModel.landingID) { _, _ in switched() }
        .onChange(of: viewModel.successCount) { _, _ in env.haptics.success() }
        .onChange(of: viewModel.showsDeclinedNotice) { _, shown in
            if shown { AccessibilityNotification.Announcement(String(localized: "onboarding.verification.notice")).post() }
        }
        .onAppear { if !reduceMotion { tilt.start(env.parallax) } }
        .onDisappear {
            tilt.stop()
            sealHaptic?.cancel()
        }
    }

    // MARK: Layout

    private var topBar: some View {
        OnboardingTopBar(screen: "verification", step: 4, animatesStrip: !model.isRevisit(.verification),
                         fillsStrip: entrance.has(.progress), backShown: entrance.has(.back), skipShown: entrance.has(.skip),
                         stripShown: true, onBack: { model.back() }, onSkip: viewModel.skipTapped)
            .padding(.top, InterestsMetrics.topBarTop)
            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    private func content(height: CGFloat) -> some View {
        let scale = isAccessibilitySize ? 0.8 : min(1, max(0.78, height / 874))
        return VStack(alignment: .leading, spacing: 0) {
            VerificationHeadline(entrance: entrance)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, 28)
                .padding(.top, 4 * scale)
            subtitle.padding(.horizontal, 28).padding(.top, 14 * scale)
            hero(scale: scale).frame(maxWidth: .infinity).padding(.top, 8 * scale)
            SegmentedPill(selection: viewModel.preview, isFullWidth: isAccessibilitySize) { viewModel.select($0) }
                .padding(.horizontal, isAccessibilitySize ? 24 : 0)
                .frame(maxWidth: .infinity)
                .modifier(FadeUp(shown: entrance.has(.control)))
                .padding(.top, 4 * scale)
            caption
                .padding(.horizontal, 24)
                .padding(.top, 12 * scale)
            VerificationBullets(entrance: entrance)
                .padding(.horizontal, 35)
                .padding(.top, 17 * scale)
                .padding(.bottom, 12)
        }
    }

    private var subtitle: some View {
        Text("onboarding.verification.subtitle")
            .font(.system(size: subtitleSize))
            .tracking(-0.011 * subtitleSize)
            .lineSpacing(3.4)
            .foregroundStyle(OnbColor.inkSecondary)
            .frame(maxWidth: 340, alignment: .leading)
            .modifier(FadeUp(shown: entrance.has(.subtitle)))
            .accessibilityIdentifier("onboarding.verification.subtitle")
    }

    private func hero(scale: CGFloat) -> some View {
        VerificationPreview(preview: viewModel.preview, landingID: viewModel.landingID, verifiedCount: viewModel.verifiedCount,
                            date: exampleDate, reduceMotion: reduceMotion, tilt: tilt, postmarkShown: entrance.has(.postmark),
                            instant: entrance.isInstant)
            .scaleEffect(scale)
            .frame(width: VerificationPreview.groupSize.width * scale, height: VerificationPreview.groupSize.height * scale)
            .modifier(StarterDropEffect(played: entrance.has(.hero), instant: entrance.isInstant))
    }

    private var caption: some View {
        Text(captionKey == .collected ? "onboarding.verification.caption.collected" : "onboarding.verification.caption.verified")
            .font(.system(size: captionSize))
            .foregroundStyle(OnbColor.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .opacity(captionVisible ? 1 : 0)
            .offset(y: captionVisible ? 0 : -6)
            .modifier(FadeUp(shown: entrance.has(.caption), rise: 0))
            .accessibilityIdentifier("onboarding.verification.caption")
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if viewModel.showsDeclinedNotice {
                Text("onboarding.verification.notice")
                    .font(.system(size: captionSize))
                    .foregroundStyle(OnbColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                    .accessibilityIdentifier("onboarding.verification.notice")
            }
            PrimaryCapsuleButton(title: viewModel.ctaIsContinue ? "onboarding.common.continue" : "onboarding.verification.cta",
                                 identifier: "onboarding.verification.cta", style: .paper, showsArrow: false,
                                 action: viewModel.ctaTapped)
                .disabled(viewModel.isRequesting)
                .modifier(FadeUp(shown: entrance.has(.cta)))
            Button(action: viewModel.notNowTapped) {
                Text("onboarding.verification.notNow")
                    .font(.system(size: linkSize, weight: .semibold))
                    .foregroundStyle(OnbColor.accentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(FadeUp(shown: entrance.has(.notNow)))
            .accessibilityIdentifier("onboarding.verification.notNow")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    // MARK: Switching

    /// A switch of the preview: the haptics, the caption swap and the announcement. Only the latest switch counts.
    private func switched() {
        env.haptics.selection()
        sealHaptic?.cancel()
        if viewModel.preview == .verified {
            sealHaptic = Task {
                try? await Task.sleep(for: .seconds(VerificationTimeline.sealContact))
                guard !Task.isCancelled else { return }
                env.haptics.rigidImpact(intensity: 0.7)
            }
        }
        let target = viewModel.preview
        Task { await swapCaption(to: target) }
    }

    /// The old caption leaves over 0.2 s; 0.1 s in, the new one arrives over 0.3 s. Reduce Motion cross-fades.
    private func swapCaption(to target: VerificationViewModel.Preview) async {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeIn(duration: VerificationTimeline.captionOut)) { captionVisible = false }
        try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : VerificationTimeline.captionSwapDelay))
        guard !Task.isCancelled, viewModel.preview == target else { return }
        captionKey = target
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: VerificationTimeline.captionIn)) { captionVisible = true }
        AccessibilityNotification.Announcement(String(localized: target == .collected ? "onboarding.verification.caption.collected"
                                                                                         : "onboarding.verification.caption.verified")).post()
    }
}
