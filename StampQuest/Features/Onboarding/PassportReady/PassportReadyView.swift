import SwiftUI

/// Your passport is ready (after step 5): the passport they made, open at page 1 with the first stamp inside, and an honest
/// summary of what they set up. It shows saved state only and writes only the time it was first shown.
struct PassportReadyView: View {
    @State private var viewModel: PassportReadyViewModel
    @State private var entrance = BeatPlayer<ReadyTimeline.Beat>(schedule: ReadyTimeline.standard.schedule)
    @State private var swingHaptic: Task<Void, Never>?
    @State private var landHaptic: Task<Void, Never>?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 16.0
    @ScaledMetric(relativeTo: .footnote) private var captionSize = 13.0

    private let model: OnboardingModel

    init(model: OnboardingModel, location: LocationProviding) {
        self.model = model
        _viewModel = State(initialValue: PassportReadyViewModel(model: model, location: location))
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperGlowBackground(glowHeight: 0.38, glowCenterY: 0.45)
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
        .task {
            viewModel.appeared()
            let animated = !reduceMotion && !model.isRevisit(.passportReady)
            if !animated { viewModel.showOpen() }
            await entrance.play(animated: animated, fade: reduceMotion ? 0.25 : 0)
        }
        .onChange(of: entrance.has(.open)) { _, open in if open { viewModel.autoOpen() } }
        .onChange(of: viewModel.toggleCount) { _, _ in swung() }
        .onChange(of: entrance.has(.stamp)) { _, landed in if landed && !entrance.isInstant { scheduleLandHaptic() } }
        .onDisappear {
            swingHaptic?.cancel()
            landHaptic?.cancel()
        }
    }

    // MARK: Layout

    private var topBar: some View {
        OnboardingTopBar(screen: "ready", step: 5, animatesStrip: !model.isRevisit(.passportReady), fillsStrip: entrance.has(.progress),
                         backShown: entrance.has(.back), skipShown: false, stripShown: true, progressLabel: "onboarding.ready.a11y.progress",
                         onBack: { model.back() }, onSkip: nil)
            .padding(.top, InterestsMetrics.topBarTop)
            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    private func content(height: CGFloat) -> some View {
        let scale = isAccessibilitySize ? 0.78 : min(1, max(0.78, height / 874))
        let readyContent = viewModel.content
        return VStack(alignment: .leading, spacing: 0) {
            ReadyHeadline(entrance: entrance)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, 28)
                .padding(.top, 4 * scale)
            Text(readyContent.subtitle)
                .font(.system(size: subtitleSize))
                .tracking(-0.011 * subtitleSize)
                .lineSpacing(3.4)
                .foregroundStyle(OnbColor.inkSecondary)
                .frame(maxWidth: 340, alignment: .leading)
                .modifier(FadeUp(shown: entrance.has(.subtitle)))
                .padding(.horizontal, 28)
                .padding(.top, 12 * scale)
                .accessibilityIdentifier("onboarding.ready.subtitle")
            PassportHero(isOpen: viewModel.isOpen, content: readyContent, cover: model.appliedCover, entrance: entrance,
                         reduceMotion: reduceMotion, onTap: viewModel.toggle)
                .scaleEffect(scale)
                .frame(width: PassportHero.frameSize.width * scale, height: PassportHero.frameSize.height * scale)
                .frame(maxWidth: .infinity)
                .padding(.top, 24 * scale)
            Text("onboarding.ready.caption")
                .font(.system(size: captionSize, weight: .medium))
                .foregroundStyle(OnbColor.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .modifier(FadeUp(shown: entrance.has(.caption)))
                .padding(.top, 14 * scale)
                .accessibilityHidden(true)
            ReadySummary(rows: readyContent.rows, entrance: entrance, isVertical: isAccessibilitySize)
                .padding(.horizontal, isAccessibilitySize ? 28 : 0)
                .padding(.top, 18 * scale)
                .padding(.bottom, 12)
        }
    }

    private var bottomBar: some View {
        PrimaryCapsuleButton(title: "onboarding.ready.cta", identifier: "onboarding.ready.cta", style: .paper, showsArrow: false,
                             action: viewModel.continueTapped)
            .modifier(FadeUp(shown: entrance.has(.cta)))
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 36)
            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    // MARK: Haptics and announcements

    /// The cover starts to swing (open or closed): a soft impact, and the new state is announced.
    private func swung() {
        guard viewModel.toggleCount > 0 else { return }
        env.haptics.softImpact()
        let key = viewModel.isOpen ? "onboarding.ready.a11y.announce.open" : "onboarding.ready.a11y.announce.closed"
        AccessibilityNotification.Announcement(Bundle.main.localizedString(forKey: key, value: nil, table: nil)).post()
    }

    /// The stamp touches the page 0.36 s into its landing.
    private func scheduleLandHaptic() {
        landHaptic?.cancel()
        landHaptic = Task {
            try? await Task.sleep(for: .seconds(ReadyTimeline.stampContact))
            guard !Task.isCancelled else { return }
            env.haptics.rigidImpact(intensity: 0.8)
        }
    }
}
