import SwiftUI

/// Your passport cover (step 5 of 5): browse five covers, pick one, put a name on it. Plus covers (flag on) can be
/// previewed and are never locked; nothing here asks for a permission or sends the name anywhere.
struct CoverView: View {
    @State private var viewModel: CoverViewModel
    @State private var entrance = BeatPlayer<CoverTimeline.Beat>(schedule: CoverTimeline.standard.schedule)
    @State private var tilt = TiltParallax()
    @State private var position: CoverStyle?
    @State private var sheenX: Double?
    @State private var sheenTask: Task<Void, Never>?
    @State private var lastSheen = Date.distantPast
    @State private var labelStyle: CoverStyle
    /// While a tapped swatch scrolls the carousel, the scroll position passes through the covers in between: ignore it.
    @State private var programmaticUntil = Date.now.addingTimeInterval(1.2)
    @State private var labelVisible = true
    @FocusState private var focused: Bool

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 16.0
    @ScaledMetric(relativeTo: .title3) private var labelSize = 17.0

    private let model: OnboardingModel

    init(model: OnboardingModel) {
        self.model = model
        let vm = CoverViewModel(model: model)
        _viewModel = State(initialValue: vm)
        _position = State(initialValue: vm.selected)
        _labelStyle = State(initialValue: vm.selected)
    }

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) }
    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }
    private var slide: Animation { reduceMotion ? .easeInOut(duration: 0.25) : .timingCurve(0.32, 0.78, 0.2, 1, duration: CoverTimeline.slide) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperGlowBackground(glowHeight: 0.38, glowCenterY: 0.4)
                VStack(spacing: 0) {
                    topBar
                    ScrollViewReader { reader in
                        ScrollView {
                            content(height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                                .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
                                .frame(maxWidth: .infinity)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: focused) { _, isFocused in
                            if isFocused { withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("coverField", anchor: .bottom) } }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            }
        }
        .task {
            // Centre the hero on the stored selection with no animation and ignore the scroll view settling there.
            programmaticUntil = .now.addingTimeInterval(1.0)
            await Task.yield()
            position = viewModel.selected
        }
        .task { await entrance.play(animated: !reduceMotion && !viewModel.isRestored, fade: reduceMotion ? 0.2 : 0) }
        .onChange(of: position) { _, new in
            if let new, new != viewModel.selected, Date.now >= programmaticUntil { choose(new) }
        }
        .onChange(of: viewModel.displayName) { _, _ in scheduleSheen() }
        .onAppear { if !reduceMotion { tilt.start(env.parallax) } }
        .onDisappear {
            tilt.stop()
            sheenTask?.cancel()
        }
    }

    // MARK: Layout

    private var topBar: some View {
        OnboardingTopBar(screen: "cover", step: 5, animatesStrip: !viewModel.isRestored, fillsStrip: entrance.has(.progress),
                         backShown: entrance.has(.back), skipShown: entrance.has(.skip), stripShown: true,
                         onBack: { model.back() }, onSkip: viewModel.skipTapped)
            .padding(.top, InterestsMetrics.topBarTop)
            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    private func content(height: CGFloat) -> some View {
        let scale = isAccessibilitySize ? 0.78 : min(1, max(CoverMetrics.minHeroScale, height / 874))
        return VStack(alignment: .leading, spacing: 0) {
            CoverHeadline(entrance: entrance)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, 28)
                .padding(.top, 4 * scale)
            subtitle.padding(.horizontal, 28).padding(.top, 12 * scale)
            hero(scale: scale).padding(.top, 20 * scale)
            SwatchDock(covers: viewModel.covers, selected: viewModel.selected, showsPlus: viewModel.showsPlus,
                       shownCount: shownSwatches, ringShown: entrance.has(.ring), reduceMotion: reduceMotion, onSelect: choose)
                .frame(maxWidth: .infinity)
                .padding(.top, (focused ? 6 : 28) * scale)
            nameLabel
                .frame(maxWidth: .infinity)
                .padding(.top, 8 * scale)
            NameField(text: viewModel.typedName, onChange: viewModel.setName, focus: $focused)
                .padding(.horizontal, 28)
                .padding(.top, 12 * scale)
                .padding(.bottom, 16)
                .modifier(FadeUp(shown: entrance.has(.field)))
                .id("coverField")
        }
    }

    private var shownSwatches: Int { (0..<CoverTimeline.swatchCount).filter { entrance.has(.swatch($0)) }.count }

    private var subtitle: some View {
        Text("onboarding.cover.subtitle")
            .font(.system(size: subtitleSize))
            .tracking(-0.011 * subtitleSize)
            .lineSpacing(3.4)
            .foregroundStyle(OnbColor.inkSecondary)
            .frame(maxWidth: 340, alignment: .leading)
            .modifier(FadeUp(shown: entrance.has(.subtitle)))
            .accessibilityIdentifier("onboarding.cover.subtitle")
    }

    private func hero(scale: CGFloat) -> some View {
        let group = CoverMetrics.groupSize(width: CoverMetrics.heroWidth, showsPageBlock: true)
        let keyboardScale = focused ? CoverMetrics.keyboardHeroScale : 1
        return CoverCarousel(covers: viewModel.covers, selected: $position, holderName: viewModel.displayName,
                             glossShift: reduceMotion ? 0 : CGFloat(tilt.tilt.x) * 14, sheenX: sheenX, neighboursShown: entrance.has(.neighbours),
                             hidesNeighbours: focused && scale < 0.9)
            .frame(height: group.height)
            .scaleEffect(scale * keyboardScale, anchor: .top)
            .frame(height: group.height * scale * keyboardScale, alignment: .top)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.2), value: focused)
            .modifier(CoverRiseEffect(played: entrance.has(.hero), instant: entrance.isInstant || reduceMotion))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("onboarding.cover.a11y.carousel"))
            .accessibilityValue(heroValue)
            .accessibilityIdentifier("onboarding.cover.carousel")
    }

    private var heroValue: Text {
        let name = Bundle.main.localizedString(forKey: viewModel.selected.nameKey, value: nil, table: nil)
        return viewModel.displayName.isEmpty ? Text(verbatim: name) : Text("onboarding.cover.a11y.hero.name \(name) \(viewModel.displayName)")
    }

    private var nameLabel: some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey(labelStyle.nameKey))
                .font(.system(size: labelSize, weight: .semibold))
                .tracking(-0.014 * labelSize)
                .foregroundStyle(OnbColor.inkPrimary)
            if viewModel.showsPlus && labelStyle.isPlus {
                Text("onboarding.cover.plus")
                    .font(.system(size: 11, weight: .bold)) // audit:fixed-glyph: inside a fixed-size badge or icon button
                    .foregroundStyle(OnbColor.ctaLabel)
                    .padding(.horizontal, 10)
                    .frame(height: 20)
                    .background(OnbColor.ctaFill, in: Capsule())
            }
        }
        .opacity(labelVisible ? 1 : 0)
        .frame(minHeight: 24)
        .modifier(FadeUp(shown: entrance.has(.name)))
        .accessibilityHidden(true)
        .accessibilityIdentifier("onboarding.cover.styleName")
    }

    private var bottomBar: some View {
        PrimaryCapsuleButton(title: "onboarding.cover.cta", identifier: "onboarding.cover.cta", style: .paper, showsArrow: false,
                             action: viewModel.continueTapped)
            .modifier(FadeUp(shown: entrance.has(.cta)))
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 36)
            .frame(maxWidth: FirstStampMetrics.contentMaxWidth)
    }

    // MARK: Actions

    /// A swatch tap or a swipe settling: one selection, one haptic, one announcement. The latest always wins.
    private func choose(_ style: CoverStyle) {
        guard style != viewModel.selected || position != style else { return }
        let changed = style != viewModel.selected
        viewModel.select(style)
        programmaticUntil = .now.addingTimeInterval(CoverTimeline.slide + 0.15)
        withAnimation(slide) { position = style }
        guard changed else { return }
        env.haptics.selection()
        swapLabel(to: style)
        let name = Bundle.main.localizedString(forKey: style.nameKey, value: nil, table: nil)
        let plus = viewModel.showsPlus && style.isPlus
        AccessibilityNotification.Announcement(String(localized: plus ? "onboarding.cover.a11y.selected.plus \(name)" : "onboarding.cover.a11y.selected \(name)")).post()
    }

    /// The old name leaves over 0.2 s; 0.2 s in, the new one arrives over 0.3 s.
    private func swapLabel(to style: CoverStyle) {
        withAnimation(.easeIn(duration: reduceMotion ? 0.2 : CoverTimeline.labelOut)) { labelVisible = false }
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : CoverTimeline.labelInDelay))
            guard viewModel.selected == style else { return }
            labelStyle = style
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : CoverTimeline.labelIn)) { labelVisible = true }
        }
    }

    /// When typing pauses for half a second after the name changed, one foil sheen crosses the cover (at most every 4 s).
    private func scheduleSheen() {
        guard !reduceMotion, !viewModel.displayName.isEmpty else { return }
        sheenTask?.cancel()
        sheenTask = Task {
            try? await Task.sleep(for: .seconds(CoverTimeline.sheenPause))
            guard !Task.isCancelled, Date.now.timeIntervalSince(lastSheen) >= CoverTimeline.sheenCooldown else { return }
            lastSheen = .now
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { sheenX = CoverTimeline.sheenRange.lowerBound }
            await Task.yield()
            withAnimation(.easeOut(duration: CoverTimeline.sheenDuration)) { sheenX = CoverTimeline.sheenRange.upperBound }
            try? await Task.sleep(for: .seconds(CoverTimeline.sheenDuration))
            sheenX = nil
        }
    }
}

/// The hero rising in 1.05 s after the screen appears: from 46 pt down at .88x, up past rest and settling (0.85 s).
struct CoverRiseEffect: ViewModifier {
    let played: Bool
    let instant: Bool

    private struct Values {
        var opacity = 0.0
        var offset = 46.0
        var scale = 0.88
    }

    func body(content: Content) -> some View {
        if instant {
            content.opacity(played ? 1 : 0)
        } else {
            content.keyframeAnimator(initialValue: Values(), trigger: played) { view, value in
                view.scaleEffect(value.scale).offset(y: value.offset).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1, duration: 0.5)
                    LinearKeyframe(1, duration: 0.35)
                }
                KeyframeTrack(\.offset) {
                    CubicKeyframe(-4, duration: 0.51)
                    CubicKeyframe(0, duration: 0.34)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.02, duration: 0.51)
                    CubicKeyframe(1, duration: 0.34)
                }
            }
        }
    }
}
