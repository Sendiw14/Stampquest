import SwiftUI

/// Interests (step 2 of 5): six stamp slots on a passport page; the choice ranks the starter stamps on the next screen.
struct InterestsScreen: View {
    @State private var viewModel: InterestsViewModel
    @State private var entrance = InterestsEntrance()
    @State private var tilt = TiltParallax()
    @State private var announcement: Task<Void, Never>?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 16.0

    private let model: OnboardingModel

    init(model: OnboardingModel) {
        self.model = model
        _viewModel = State(initialValue: InterestsViewModel(model: model))
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var columns: Int { typeSize >= .accessibility1 ? 2 : 3 }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperGlowBackground()
                VStack(spacing: 0) {
                    topBar
                    ScrollView {
                        content(width: proxy.size.width)
                            .frame(maxWidth: InterestsMetrics.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            }
        }
        .task { await play() }
        .onAppear { if !reduceMotion { tilt.start(env.parallax) } }
        .onDisappear { tilt.stop() }
    }

    // MARK: Pieces

    private var topBar: some View {
        OnboardingTopBar(screen: "interests", step: 2, animatesStrip: !model.isRevisit(.interests),
                         fillsStrip: entrance.has(.progressDots), backShown: entrance.has(.back), skipShown: entrance.has(.skip),
                         stripShown: entrance.has(.progress), onBack: { model.back() }, onSkip: { viewModel.skip() })
            .padding(.top, InterestsMetrics.topBarTop)
            .frame(maxWidth: InterestsMetrics.contentMaxWidth)
    }

    private func content(width: CGFloat) -> some View {
        let pageWidth = InterestsMetrics.pageWidth(screenWidth: width)
        let column = InterestsMetrics.columnWidth(pageWidth: pageWidth, columns: columns)
        return VStack(alignment: .leading, spacing: 0) {
            InterestsHeadline(entrance: entrance)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(.horizontal, InterestsMetrics.sideMargin)
                .padding(.top, InterestsMetrics.headlineTop)
            subtitle
                .padding(.horizontal, InterestsMetrics.sideMargin)
                .padding(.top, InterestsMetrics.subtitleTop)
            PassportPageView(width: pageWidth, pageNumber: String(localized: "onboarding.interests.page.number")) { grid(column: column) }
                .modifier(FadeUp(shown: entrance.has(.page)))
                .frame(maxWidth: .infinity)
                .padding(.top, InterestsMetrics.pageTop)
            InterestsCounterView(picked: viewModel.selected.count)
                .modifier(FadeUp(shown: entrance.has(.counter), rise: 0))
                .padding(.horizontal, InterestsMetrics.sideMargin)
                .padding(.top, InterestsMetrics.counterTop)
                .padding(.bottom, 12)
        }
    }

    private var subtitle: some View {
        Text("onboarding.interests.subtitle")
            .font(.system(size: subtitleSize))
            .tracking(-0.011 * subtitleSize)
            .lineSpacing(3.4)
            .foregroundStyle(OnbColor.inkSecondary)
            .frame(maxWidth: InterestsMetrics.subtitleMaxWidth, alignment: .leading)
            .modifier(FadeUp(shown: entrance.has(.subtitle)))
            .accessibilityIdentifier("onboarding.interests.subtitle")
    }

    private func grid(column: CGFloat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(column), spacing: 0), count: columns), spacing: 0) {
            ForEach(Interest.allCases, id: \.self) { interest in
                InterestSlotView(interest: interest, isSelected: viewModel.isSelected(interest), columnWidth: column,
                                 reduceMotion: reduceMotion, tilt: tilt, shown: entrance.has(.cell(interest.index)),
                                 labelShown: entrance.has(.label(interest.index))) { toggle(interest) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("onboarding.interests.a11y.grid"))
    }

    private var bottomBar: some View {
        PrimaryCapsuleButton(title: "onboarding.interests.cta", identifier: "onboarding.interests.cta", style: .paper, showsArrow: false) {
            viewModel.continueTapped()
        }
        .disabled(!viewModel.canContinue)
        .modifier(FadeUp(shown: entrance.has(.cta)))
        .animation(.easeInOut(duration: 0.2), value: viewModel.canContinue)
        .padding(.horizontal, InterestsMetrics.sideMargin)
        .padding(.top, InterestsMetrics.ctaBottomGap)
        .padding(.bottom, 36)
        .frame(maxWidth: InterestsMetrics.contentMaxWidth)
    }

    // MARK: Actions

    private func toggle(_ interest: Interest) {
        let count = viewModel.toggle(interest)
        announcement?.cancel()
        announcement = Task {
            try? await Task.sleep(for: .seconds(InterestsTimeline.Pick.announceDebounce))
            guard !Task.isCancelled else { return }
            AccessibilityNotification.Announcement(String(localized: "onboarding.interests.a11y.selectedCount \(count)")).post()
        }
    }

    /// Plays the entrance once. Reduce Motion gets a single 0.2 s fade; a returning visit shows everything at once.
    private func play() async {
        let animated = !reduceMotion && !model.isRevisit(.interests)
        await entrance.play(animated: animated, fade: reduceMotion ? 0.2 : 0)
    }
}
