import SwiftUI

/// StampQuest Plus, after "Passport ready". It exists only when `FeatureFlags.plusPaywallEnabled` is on. Prices, periods, the trial and
/// every date come from StoreKit through `PlusViewModel`; this view lays them out. The hero, plans and timeline scroll; the call to action,
/// the fine print and the footer links stay pinned at the bottom (the links move into the scroll content at accessibility text sizes).
struct PlusPaywallView: View {
    @State private var viewModel: PlusViewModel
    @State private var entrance: BeatPlayer<PlusTimeline.Beat>
    @State private var exit: ExitSheetModel
    private let holderName: String

    @Environment(\.obReducesMotion) private var reduceMotion
    @Environment(\.obHapticsEnabled) private var hapticsEnabled
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 15.5
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = PlusMetrics.headlineSize

    /// The real screen: wired to onboarding, StoreKit and local notifications.
    init(model: OnboardingModel, client: SubscriptionClient, reminders: ReminderService, packs: PackStoreClient, manifest: [Pack], exitStore: ExitSheetStore) {
        let exit = ExitSheetModel(interests: model.interests, flags: model.flags, client: packs, manifest: manifest, onFinish: { model.finishFromOffer() })
        let viewModel = PlusViewModel(client: client, reminders: reminders, markOfferShown: model.markPlusOfferShown) { action in
            switch action {
            case .finish(let entitled): if entitled { model.finishAfterPurchase() } else { model.finishFromOffer() }
            case .exit:
                // The route action only comes from someone without Plus, so entitlement is false here.
                if ExitSheetPolicy.shouldPresent(plusEnabled: model.flags.plusPaywallEnabled, isEntitled: false, alreadyShown: exitStore.isShown) {
                    exitStore.markShown()
                    exit.isPresented = true
                } else {
                    model.finishFromOffer()
                }
            }
        }
        self.init(viewModel: viewModel, holderName: model.coverName, exit: exit)
    }

    /// For previews and tests. `showsFinishedEntrance` skips the entrance, as Reduce Motion does.
    init(viewModel: PlusViewModel, holderName: String, exit: ExitSheetModel? = nil, showsFinishedEntrance: Bool = false) {
        _viewModel = State(initialValue: viewModel)
        _exit = State(initialValue: exit ?? ExitSheetModel(interests: [], flags: FeatureFlags(), client: UnavailablePackStoreClient(), onFinish: {}))
        let player = BeatPlayer<PlusTimeline.Beat>(schedule: PlusTimeline.standard.schedule)
        if showsFinishedEntrance { player.showAll() }
        _entrance = State(initialValue: player)
        self.holderName = holderName
    }

    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }
    private var phase: PlusViewModel.Phase { viewModel.phase }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperGlowBackground(glowHeight: 0.38, glowCenterY: 0.30)
                VStack(spacing: 0) {
                    topBar
                    ScrollView {
                        content(height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                            .frame(maxWidth: PlusMetrics.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            }
        }
        .task { await viewModel.appeared() }
        .task { await viewModel.observeUpdates() }
        .task { await exit.prefetch() }
        .sheet(isPresented: Binding(get: { exit.isPresented }, set: { exit.isPresented = $0 })) { ExitSheetView(model: exit) }
        .task { await entrance.play(animated: !reduceMotion, fade: 0.25) }
        .onChange(of: viewModel.announcement) { _, announcement in post(announcement) }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: entrance.has(.sealLand)) { _, landed in
            landed && hapticsEnabled && !entrance.isInstant
        }
        .sensoryFeedback(.selection, trigger: viewModel.selected) { _, _ in hapticsEnabled && viewModel.isInteractive }
        .sensoryFeedback(.success, trigger: viewModel.successCount) { old, new in new > old && hapticsEnabled }
        .sensoryFeedback(.error, trigger: viewModel.failureCount) { old, new in new > old && hapticsEnabled }
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            HStack {
                Spacer(minLength: 0)
                Button(action: viewModel.closeTapped) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold)) // audit:fixed-glyph: inside a fixed-size badge or icon button
                        .foregroundStyle(OnbColor.inkPrimary)
                        .frame(width: PlusMetrics.closeSize, height: PlusMetrics.closeSize)
                        .background(OnbColor.closeFill, in: Circle())
                        .frame(width: PlusMetrics.closeHit, height: PlusMetrics.closeHit)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("onboarding.common.close"))
                .accessibilityIdentifier("onboarding.plus.close")
                .padding(.trailing, 20 - (PlusMetrics.closeHit - PlusMetrics.closeSize) / 2)
            }
            PunchProgressStrip(step: 5, of: OnboardingRoute.progressStepCount, animated: false, style: .interests,
                               accessibilityLabelKey: "onboarding.ready.a11y.progress")
                .modifier(FadeUp(shown: entrance.has(.topBar), rise: 0))
        }
        .frame(height: PlusMetrics.closeSize + 2)
        .padding(.top, 4)
        .frame(maxWidth: PlusMetrics.contentMaxWidth)
    }

    // MARK: Scrolling content

    private func content(height: CGFloat) -> some View {
        let scale = isAccessibilitySize ? (gap: 0.7, hero: PlusMetrics.minHeroScale) : PlusMetrics.scales(forHeight: height)
        let rise: CGFloat = reduceMotion ? 0 : 16
        return VStack(spacing: 0) {
            PlusHero(holderName: holderName, entrance: entrance, reduceMotion: reduceMotion, successCount: viewModel.successCount)
                .scaleEffect(scale.hero, anchor: .top)
                .frame(height: PlusMetrics.heroHeight * scale.hero)
            headline
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, PlusMetrics.sideMargin)
            Text("onboarding.plus.subtitle")
                .font(.system(size: subtitleSize))
                .tracking(-0.011 * subtitleSize)
                .lineSpacing(3)
                .foregroundStyle(OnbColor.inkSecondary)
                .multilineTextAlignment(.center)
                .modifier(FadeUp(shown: entrance.has(.subtitle), rise: rise))
                .padding(.horizontal, PlusMetrics.sideMargin)
                .padding(.top, 4 * scale.gap)
                .accessibilityIdentifier("onboarding.plus.subtitle")
            PerkGrid(perks: viewModel.perks, entrance: entrance, reduceMotion: reduceMotion, singleColumn: isAccessibilitySize)
                .padding(.horizontal, PlusMetrics.sideMargin)
                .padding(.top, 20 * scale.gap)
            timelineSlot
                .padding(.horizontal, PlusMetrics.sideMargin)
                .padding(.top, 22 * scale.gap)
            planSlot
                .padding(.horizontal, PlusMetrics.sideMargin)
                .padding(.top, 19 * scale.gap)
                .padding(.bottom, 4)
            if isAccessibilitySize { footer.padding(.top, 8).padding(.bottom, 16) }
        }
    }

    /// "StampQuest" and the "Plus" stamp-word on one line; they wrap onto two lines when the line does not fit.
    private var headline: some View {
        let unit = headlineSize / PlusMetrics.headlineSize
        let style = StampWordStyle(fill: OnbColor.stampWordFill, ink: OnbColor.stampWordLabel, shadow: OnbColor.shadowSoft, rotation: -3,
                                   height: PlusMetrics.wordSize.height * unit, horizontalPadding: 17 * unit, pitch: PlusMetrics.stampPitch,
                                   inset: 6, insetRadius: 2, shadowOffset: 8)
        let brand = Text("onboarding.plus.headline.brand")
            .font(.system(size: headlineSize, weight: .heavy))
            .tracking(-0.04 * headlineSize)
            .foregroundStyle(OnbColor.inkPrimary)
            .lineLimit(1)
            .fixedSize()
            .modifier(FadeUp(shown: entrance.has(.brand), rise: reduceMotion ? 0 : 16))
        let word = StampWordFrame(word: String(localized: "onboarding.plus.headline.word"), size: headlineSize, style: style)
            .modifier(StampInEffect(played: entrance.has(.plusWord), instant: reduceMotion || entrance.isInstant))
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) { brand; word }
            VStack(spacing: 8) { brand; word }
        }
        .frame(maxWidth: .infinity, minHeight: PlusMetrics.wordSize.height * unit + 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.plus.title"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.plus.headline")
    }

    @ViewBuilder
    private var timelineSlot: some View {
        Group {
            if let content = viewModel.content, phase != .unavailable {
                TrialRoute(steps: content.steps, shown: entrance.shown, reduceMotion: reduceMotion, isVertical: isAccessibilitySize)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, minHeight: isAccessibilitySize ? 0 : 66)
    }

    @ViewBuilder
    private var planSlot: some View {
        if let content = viewModel.content, phase != .unavailable {
            PlanPicker(plans: content.plans, saveBadge: content.saveBadge, selected: viewModel.selected, isEnabled: viewModel.isInteractive,
                       isDimmed: phase == .purchasing, isStacked: isAccessibilitySize, shown: entrance.shown, reduceMotion: reduceMotion) { viewModel.select($0) }
        } else {
            PlanSkeleton(isStacked: isAccessibilitySize).opacity(phase == .unavailable ? 0.5 : 1)
        }
    }

    // MARK: Pinned bottom

    private var bottomBar: some View {
        VStack(spacing: 0) {
            ctaSlot
                .padding(.horizontal, PlusMetrics.sideMargin)
                .modifier(FadeUp(shown: entrance.has(.cta), rise: reduceMotion ? 0 : 16))
            finePrint
                .padding(.horizontal, PlusMetrics.sideMargin)
                .padding(.top, 8)
                .modifier(FadeUp(shown: entrance.has(.finePrint), rise: reduceMotion ? 0 : 16))
            if !isAccessibilitySize { footer }
        }
        .padding(.top, 8)
        .frame(maxWidth: PlusMetrics.contentMaxWidth)
    }

    private var footer: some View {
        LegalLinks(isRestoreEnabled: phase == .ready || phase == .unavailable) { Task { await viewModel.restoreTapped() } }
            .modifier(FadeUp(shown: entrance.has(.links), rise: 0))
    }

    @ViewBuilder
    private var ctaSlot: some View {
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.25) : .spring(response: 0.5, dampingFraction: 0.8)
        Group {
            switch phase {
            case .loading:
                PurchaseButton(title: "", isLoadingPlans: true) {}
            case .unavailable:
                Button { Task { await viewModel.retryTapped() } } label: { Text("onboarding.plus.cta.retry").frame(maxWidth: .infinity) }
                    .buttonStyle(PrimaryCapsuleButtonStyle(style: .paper))
                    .accessibilityIdentifier("onboarding.plus.retry")
            case .ready, .purchasing:
                PurchaseButton(title: viewModel.content?.ctaTitle ?? "", isPurchasing: phase == .purchasing) {
                    Task { await viewModel.purchaseTapped() }
                }
                .transition(.opacity.animation(.easeOut(duration: 0.3)))
            case .succeeded(let kind):
                StatusBanner(text: PlusContent.banner(kind), kind: .success)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)).animation(animation.delay(0.1)))
            case .pending:
                StatusBanner(text: String(localized: "onboarding.plus.banner.pending"), kind: .waiting)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)).animation(animation.delay(0.1)))
            }
        }
        .frame(minHeight: PlusMetrics.ctaHeight)
        .animation(animation, value: phase)
    }

    private var finePrint: some View {
        PlusFinePrint(phase: phase, content: viewModel.content, notice: viewModel.notice, reduceMotion: reduceMotion)
    }

    // MARK: Announcements

    private func post(_ announcement: PlusViewModel.Announcement?) {
        guard let announcement else { return }
        var text = AttributedString(announcement.text)
        if announcement.isHighPriority { text.accessibilitySpeechAnnouncementPriority = .high }
        AccessibilityNotification.Announcement(text).post()
    }
}
