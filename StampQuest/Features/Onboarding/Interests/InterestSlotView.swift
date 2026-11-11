import SwiftUI

/// One cell of the passport page: an empty slot with a ghost stamp, or the picked stamp with its badge and postmark,
/// and the name and description under it. The whole cell is one button. Selection is the single source of truth: the
/// animations are derived from it.
struct InterestSlotView: View {
    let interest: Interest
    let isSelected: Bool
    let columnWidth: CGFloat
    let reduceMotion: Bool
    let tilt: TiltParallax
    let shown: Bool
    let labelShown: Bool
    let onTap: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var nameSize = 15.0
    @ScaledMetric(relativeTo: .caption) private var descriptionSize = 12.0

    /// False until the person picks something, so a stamp picked before the screen opened appears without landing.
    @State private var animatesPicks = false
    @State private var rippleCount = 0
    @State private var thud: Task<Void, Never>?

    private var scale: CGFloat { InterestsMetrics.stampScale(columnWidth: columnWidth) }
    private var instant: Bool { reduceMotion || !animatesPicks }
    private var layers: InterestSlotLayers { InterestSlotLayers(isSelected: isSelected) }

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 0) {
                stampZone
                    .frame(width: InterestsMetrics.stampSize.width, height: InterestsMetrics.stampSize.height)
                    .scaleEffect(scale)
                    .frame(width: InterestsMetrics.stampSize.width * scale, height: InterestsMetrics.stampSize.height * scale)
                    .modifier(FadeUp(shown: shown))
                labels
                    .padding(.top, InterestsMetrics.labelGap)
                    .modifier(FadeUp(shown: labelShown, rise: 8))
            }
            .frame(width: columnWidth, alignment: .top)
            .frame(minHeight: InterestsMetrics.cellHeight, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: isSelected) { _, picked in if picked && !reduceMotion { rippleCount += 1 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.interests.a11y.tile \(Self.localized(interest.nameKey)) \(Self.localized(interest.descKey))"))
        .accessibilityHint(Text("onboarding.interests.a11y.hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(interest.accessibilityIdentifier)
    }

    private static func localized(_ key: String) -> String { Bundle.main.localizedString(forKey: key, value: nil, table: nil) }

    // MARK: Stamp

    private var stampZone: some View {
        ZStack(alignment: .topLeading) {
            slot
            ripple
            if layers.stamp { stamp }
            if layers.badge { badge }
            if layers.postmark { postmark }
        }
    }

    private var slot: some View {
        ZStack {
            FixedPitchPerforatedShape(pitch: InterestsMetrics.stampPitch, notchRatio: 0.29)
                .stroke(OnbColor.accent.opacity(contrast == .increased ? 1 : InterestsMetrics.slotOpacity),
                        style: StrokeStyle(lineWidth: InterestsMetrics.slotLineWidth, dash: InterestsMetrics.slotDash))
            InterestStampView(interest: interest, isGhost: true)
        }
        .opacity(isSelected ? 0 : 1)
        .animation(.easeOut(duration: isSelected ? InterestsTimeline.Pick.ghostFade : InterestsTimeline.Pick.ghostReturn), value: isSelected)
    }

    private var stamp: some View {
        let idleSheen = reduceMotion || tilt.tilt.x == 0 ? -1 : 0.5 + tilt.tilt.x * 0.5
        return InterestStampView(interest: interest)
            .modifier(StampLandingEffect(instant: instant, idleSheen: idleSheen))
            .rotationEffect(.degrees(interest.pickedTilt))
            .shadow(color: OnbColor.shadowDeep, radius: 7, x: TiltParallax.offset(tilt.tilt.x, limit: 2),
                    y: 14 + TiltParallax.offset(tilt.tilt.y, limit: 2))
            .transition(removal(.modifier(active: LiftOff(active: true), identity: LiftOff(active: false)),
                                animation: .easeIn(duration: InterestsTimeline.Pick.unpickLift)))
    }

    private var ripple: some View {
        RoundedRectangle(cornerRadius: 7)
            .stroke(OnbColor.accent, lineWidth: 2)
            .frame(width: InterestsMetrics.stampSize.width, height: InterestsMetrics.stampSize.height)
            .modifier(RippleEffect(trigger: reduceMotion ? 0 : rippleCount))
            .allowsHitTesting(false)
    }

    private var badge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(OnbColor.ctaLabel)
            .frame(width: InterestsMetrics.badgeSize, height: InterestsMetrics.badgeSize)
            .background(OnbColor.accent, in: Circle())
            .overlay { Circle().stroke(OnbColor.background, lineWidth: 2.4) }
            .modifier(BadgePopEffect(instant: instant))
            .offset(x: InterestsMetrics.stampSize.width - InterestsMetrics.badgeInset.width, y: -InterestsMetrics.badgeInset.height)
            .transition(removal(.scale(scale: 0.3).combined(with: .opacity), animation: .easeOut(duration: InterestsTimeline.Pick.unpickBadge)))
            .accessibilityHidden(true)
    }

    private var postmark: some View {
        StampPostmark(top: String(localized: "onboarding.interests.postmark"), bottom: "StampQuest", style: .picked,
                      size: InterestsMetrics.postmarkSize, ink: OnbColor.postmark)
            .opacity(0.92)
            .modifier(PostmarkThumpEffect(instant: instant))
            .rotationEffect(.degrees(InterestsMetrics.postmarkRotation))
            .offset(x: InterestsMetrics.stampSize.width - InterestsMetrics.postmarkOffset.width,
                    y: InterestsMetrics.stampSize.height - InterestsMetrics.postmarkOffset.height)
            .transition(removal(.opacity, animation: .easeOut(duration: InterestsTimeline.Pick.unpickBadge)))
    }

    /// Reduce Motion cross-fades every layer; otherwise a layer leaves with its own transition. Layers appear with no
    /// transition: their keyframes do the entrance.
    private func removal(_ leaving: AnyTransition, animation: Animation) -> AnyTransition {
        reduceMotion
            ? .opacity.animation(.easeInOut(duration: InterestsTimeline.Pick.reducedFade))
            : .asymmetric(insertion: .identity, removal: leaving.animation(animation))
    }

    // MARK: Labels

    private var labels: some View {
        VStack(spacing: 0) {
            Text(LocalizedStringKey(interest.nameKey))
                .font(.system(size: nameSize, weight: .semibold))
                .tracking(-0.012 * nameSize)
                .foregroundStyle(OnbColor.inkPrimary)
            Text(LocalizedStringKey(interest.descKey))
                .font(.system(size: descriptionSize))
                .lineSpacing(0.2)
                .foregroundStyle(OnbColor.inkSecondary)
                .lineLimit(2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: columnWidth - 12)
    }

    // MARK: Interaction

    private func tap() {
        animatesPicks = true
        if isSelected {
            thud?.cancel()
            env.haptics.selection()
        } else {
            env.haptics.mediumImpact()
            thud = Task {
                try? await Task.sleep(for: .seconds(InterestsTimeline.Pick.thudDelay))
                guard !Task.isCancelled else { return }
                env.haptics.heavyImpact(intensity: 0.6)
            }
        }
        onTap()
    }
}

/// The stamp lifting off: up 16 pt, up to 1.13x, tilting 3 degrees and fading.
private struct LiftOff: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.13 / InterestsMetrics.selectedScale : 1)
            .rotationEffect(.degrees(active ? 3 : 0))
            .offset(y: active ? -16 : 0)
            .opacity(active ? 0 : 1)
    }
}
