import SwiftUI

/// "Start free, upgrade later": the sheet over the Plus paywall. It composes the sections; the state and the choices live in
/// `ExitSheetModel`. Presentation (detent from the measured height, corner radius, background) is applied here, so the Plus screen only
/// attaches the sheet.
struct ExitSheetView: View {
    @Bindable var model: ExitSheetModel

    @State private var player = ExitSheetMotion.makePlayer()
    @State private var contentHeight: CGFloat = 0
    @State private var ctaTaps = 0
    @State private var buyTaps = 0
    @Environment(\.obReducesMotion) private var reduceMotion
    @Environment(\.obHapticsEnabled) private var hapticsEnabled
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var subtitleSize = 15.0
    @ScaledMetric(relativeTo: .footnote) private var labelSize = 13.0
    @ScaledMetric(relativeTo: .body) private var ctaSize = 17.0
    @ScaledMetric(relativeTo: .body) private var linkSize = 16.0

    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }

    var body: some View {
        ScrollView {
            content
                .background(GeometryReader { Color.clear.preference(key: ExitContentHeightKey.self, value: $0.size.height) })
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .topTrailing) {
            SheetCloseButton { model.closeToPlus() }
                .disabled(model.isBusy)
                .padding(.top, 16 - 7)
                .padding(.trailing, 20 - 7)
        }
        .onPreferenceChange(ExitContentHeightKey.self) { contentHeight = $0 }
        .presentationDetents(isAccessibilitySize || contentHeight == 0 ? [.large] : [.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(OnbColor.passportPaper)
        .presentationBackgroundInteraction(.disabled)
        .interactiveDismissDisabled(model.isBusy)
        .task { await entrance() }
        .task { await model.observeUpdates() }
        .onChange(of: model.ownedCount) { _, _ in announceOwned() }
        .alert(Text("exit.error.title"), isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button(role: .cancel) {} label: { Text("exit.close") }
        } message: { Text("exit.error.body") }
        .sensoryFeedback(.impact(weight: .light), trigger: buyTaps) { _, _ in hapticsEnabled }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: ctaTaps) { _, _ in hapticsEnabled }
        .sensoryFeedback(.success, trigger: model.ownedCount) { old, new in new > old && hapticsEnabled }
        .sensoryFeedback(.error, trigger: model.failureCount) { old, new in new > old && hapticsEnabled }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExitTitle(player: player, reduceMotion: reduceMotion)
                .padding(.top, 32)
            Text("exit.subtitle")
                .font(.system(size: subtitleSize))
                .tracking(-0.011 * subtitleSize)
                .lineSpacing(3)
                .foregroundStyle(OnbColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .exitBeat(.subtitle, player, reduceMotion: reduceMotion)
                .padding(.top, 8)
                .padding(.trailing, 18)
            if !model.features.isEmpty {
                FreeFeatureCard(features: model.features, player: player, reduceMotion: reduceMotion)
                    .padding(.top, 14)
                    .padding(.horizontal, -4)
            }
            packSection
            cta
                .padding(.top, 14)
                .padding(.horizontal, -4)
            link
                .padding(.top, 14 - 10)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 38)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("exitSheet")
    }

    @ViewBuilder
    private var packSection: some View {
        if let state = model.pack, let offer = model.offer, let product = model.product {
            Text("exit.pack.label")
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(OnbColor.inkSecondary)
                .exitBeat(.label, player, reduceMotion: reduceMotion)
                .padding(.top, 14)
            PackRow(pack: offer.pack, product: product, state: state, isForInterest: offer.isForInterest, ownedCount: model.ownedCount,
                    player: player, reduceMotion: reduceMotion, isStacked: isAccessibilitySize) {
                buyTaps += 1
                Task { await model.buyPack() }
            }
            .padding(.top, 6)
            .padding(.horizontal, -4)
        }
    }

    private var cta: some View {
        Button {
            ctaTaps += 1
            model.continueFree()
        } label: {
            Text("exit.cta")
                .font(.system(size: ctaSize, weight: .semibold))
                .tracking(-0.011 * ctaSize)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryCapsuleButtonStyle(style: .paper))
        .disabled(model.isBusy)
        .exitBeat(.cta, player, style: .fadeUp(duration: 0.62), reduceMotion: reduceMotion)
        .accessibilityIdentifier("exitSheet.cta")
    }

    private var link: some View {
        Button { model.closeToPlus() } label: {
            Text("exit.link")
                .font(.system(size: linkSize, weight: .semibold))
                .tracking(-0.011 * linkSize)
                .foregroundStyle(OnbColor.ctaFill)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy)
        .exitBeat(.link, player, reduceMotion: reduceMotion)
        .accessibilityHint(Text("exit.close.hint"))
        .accessibilityIdentifier("exitSheet.link")
    }

    private func entrance() async { await player.play(animated: !reduceMotion, fade: 0.2) }

    private func announceOwned() {
        guard let product = model.product else { return }
        let name = String(localized: "exit.pack.title \(product.displayName)")
        AccessibilityNotification.Announcement(String(localized: "exit.a11y.added \(name)")).post()
    }
}

private struct ExitContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
