import SwiftUI

/// Where everything on the stage sits, on the 402 pt reference canvas scaled by `u`. `t` moves between the detail layout (0)
/// and the reveal layout (1): the reveal's stamp is bigger and lower, and the exit morph walks `t` back to 0.
struct StageLayout {
    var u: CGFloat
    /// Extra status-area height on devices taller than the 54 pt reference.
    var extra: CGFloat
    var width: CGFloat
    var t: CGFloat = 0

    private func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }

    var stampWidth: CGFloat { lerp(212, 240) * u }
    var stampHeight: CGFloat { stampWidth / 0.75 }
    var center: CGPoint { CGPoint(x: width / 2, y: lerp(250, 318) * u + extra) }
    var ringWidth: CGFloat { lerp(350, 400) * u }
    var postmarkWidth: CGFloat { lerp(124, 130) * u }
    var postmarkCenter: CGPoint { CGPoint(x: center.x + 0.31 * stampWidth, y: center.y + 0.30 * stampHeight) }
    /// Everything that hangs off the stamp scales with it.
    var k: CGFloat { stampWidth / (212 * u) }
    var sealCenter: CGPoint { CGPoint(x: center.x + stampWidth / 2 - 2 * u * k, y: center.y - stampHeight / 2 + 30 * u * k) }
    var posterHeight: CGFloat { lerp(470 * u + extra, 874 * u + extra) }
}

/// The stamp on the poster with everything that belongs to its state: the cancellation ring, the postmark, the gold seal (only
/// when verified) or the wishlist bookmark, and for a stamp not in the passport a ghost in a dashed slot.
struct StampStageLayer: View {
    let name: String
    let countryName: String
    let design: StampDesign?
    let state: StampDetailState
    let collectedAt: Date?
    let layout: StageLayout
    var postmarkHidden = false
    /// The reveal presses the postmark on late: 1 is settled, above 1 is mid-press.
    var postmarkPress: CGFloat = 1
    var postmarkOpacity: CGFloat = 1
    var ringOpacity: CGFloat = 1
    var stampOpacity: CGFloat = 1
    var stampScale: CGFloat = 1
    var showsSeal = true
    var sealScale: CGFloat = 1
    var sealOpacity: CGFloat = 1

    @Environment(\.colorScheme) private var scheme
    private var ringColor: Color { scheme == .dark ? Color(hex: 0xEE9A68) : Color(hex: 0xFFF3DE) }
    private var postmarkInk: Color { scheme == .dark ? Color(hex: 0xE8A27C) : Color(hex: 0x7A3E2C) }

    var body: some View {
        let l = layout
        ZStack(alignment: .topLeading) {
            ring(l)
            if !state.isCollected { dashedSlot(l) }
            stamp(l)
            if state.isCollected, !postmarkHidden, let collectedAt { postmark(l, date: collectedAt) }
            if state.isVerified, showsSeal {
                VerifiedSeal(size: 68 * l.u * l.k).rotationEffect(.degrees(8)).scaleEffect(sealScale).opacity(sealOpacity)
                    .shadow(color: Color(red: 0.24, green: 0.14, blue: 0.02).opacity(0.42), radius: 3, y: 4)
                    .position(l.sealCenter)
            }
            if state == .wishlisted { bookmark(l) }
        }
        .frame(width: l.width, height: l.posterHeight, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
        .accessibilityAddTraits(.isImage)
    }

    // MARK: Parts

    @ViewBuilder
    private func ring(_ l: StageLayout) -> some View {
        if state.isCollected {
            StampPostmarkView(place: name, date: collectedAt ?? .now, kind: .collected, showsWaves: false, topText: "\(name) \(countryName)", inkOverride: ringColor)
                .frame(width: l.ringWidth, height: l.ringWidth).rotationEffect(.degrees(-10)).opacity(0.16 * ringOpacity).position(l.center)
        } else {
            ZStack {
                Circle().strokeBorder(ringColor, style: StrokeStyle(lineWidth: 2.2, dash: [3, 6]))
                Circle().strokeBorder(ringColor, style: StrokeStyle(lineWidth: 1, dash: [2, 5])).padding(l.ringWidth * 0.06)
            }
            .frame(width: 340 * l.u * l.k, height: 340 * l.u * l.k).opacity(0.34 * ringOpacity).position(l.center)
        }
    }

    private func dashedSlot(_ l: StageLayout) -> some View {
        PerforatedStampShape()
            .stroke(ringColor.opacity(0.62), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
            .frame(width: l.stampWidth + 18 * l.u, height: l.stampHeight + 18 * l.u)
            .rotationEffect(.degrees(-3)).position(l.center)
    }

    @ViewBuilder
    private func stamp(_ l: StageLayout) -> some View {
        let ghost = !state.isCollected
        Group {
            if let design {
                PerforatedStampView(design: design, presentation: ghost ? .muted : .full, showsTitle: true, isDecorative: true, lifted: false, aspectRatio: 0.75)
                    .saturation(ghost ? 0.7 : 1).opacity(ghost ? 0.76 : 1)
            } else {
                MissingStampArtwork(name: name).aspectRatio(0.75, contentMode: .fit).opacity(ghost ? 0.76 : 1)
            }
        }
        .frame(width: l.stampWidth, height: l.stampHeight)
        .shadow(color: Color(red: 0.133, green: 0.04, blue: 0.008).opacity(0.55), radius: 0.5, y: 2)
        .shadow(color: Color(red: 0.133, green: 0.04, blue: 0.008).opacity(0.50), radius: 14, y: 16)
        .shadow(color: Color(red: 0.133, green: 0.04, blue: 0.008).opacity(0.34), radius: 28, y: 36)
        .rotationEffect(.degrees(-3)).scaleEffect(stampScale).opacity(stampOpacity)
        .position(l.center)
    }

    private func postmark(_ l: StageLayout, date: Date) -> some View {
        StampPostmarkView(place: name, date: date, kind: .collected, showsWaves: false, topText: "\(name) \(countryName)", inkOverride: postmarkInk)
            .frame(width: l.postmarkWidth, height: l.postmarkWidth)
            .blendMode(scheme == .dark ? .normal : .multiply)
            .rotationEffect(.degrees(14)).scaleEffect(postmarkPress).opacity(0.84 * postmarkOpacity)
            .position(l.postmarkCenter)
    }

    private func bookmark(_ l: StageLayout) -> some View {
        let size = 36 * l.u * l.k
        return Image(systemName: "bookmark.fill").font(.system(size: size * 0.44, weight: .bold)).foregroundStyle(HomeColor.label)
            .frame(width: size, height: size).background(HomeColor.card, in: Circle())
            .overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 4.5, y: 4)
            .position(x: l.center.x - l.stampWidth / 2 - 14 * l.u * l.k + size / 2, y: l.center.y - l.stampHeight / 2 - 5.5 * l.u * l.k + size / 2)
            .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private var spoken: String {
        let base = "\(name) stamp, \(countryName)."
        switch state {
        case .notCollected: return base + " " + String(localized: "Not in your passport yet.")
        case .wishlisted: return base + " " + String(localized: "On your wishlist.")
        case .collectedManual: return base + " " + String(localized: "Collected by hand on \(collectedAt?.formatted(date: .long, time: .omitted) ?? "").")
        case .collectedVerified: return base + " " + String(localized: "Verified visit. Collected on \(collectedAt?.formatted(date: .long, time: .omitted) ?? "").")
        }
    }
}

// MARK: - Ticket

/// The glass ticket under the stage: the place, and where the stamp stands. Information, not a button: only "Verify visit"
/// inside it is tappable.
struct StampStateTicket: View {
    let name: String
    let countryName: String
    let categoryTitle: String
    let state: StampDetailState
    let collectedAt: Date?
    let verifiedAt: Date?
    let canVerify: Bool
    let u: CGFloat
    let onVerify: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var nameSize = 34.0
    @ScaledMetric(relativeTo: .subheadline) private var lineSize = 14.5
    @ScaledMetric(relativeTo: .headline) private var titleSize = 15.5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(name).font(.system(size: nameSize, weight: .heavy)).tracking(-0.04 * nameSize).foregroundStyle(HomeColor.ink)
                    .lineLimit(2).minimumScaleFactor(0.75).accessibilityAddTraits(.isHeader).accessibilityIdentifier("stamp-name")
                Text("\(countryName) · \(categoryTitle)").font(.system(size: lineSize, weight: .medium)).foregroundStyle(HomeColor.sub).padding(.top, 2)
                DottedRule().padding(.top, 14)
            }
            .accessibilityHidden(true)
            HStack(spacing: 10) {
                stateIcon.frame(width: 28, height: 28)
                Text(stateTitle).font(.system(size: titleSize, weight: .semibold)).tracking(-0.013 * titleSize).foregroundStyle(HomeColor.ink)
                    .accessibilityIdentifier("stamp-state-title")
                Spacer(minLength: 8)
                trailing
            }
            .padding(.top, 12).frame(minHeight: 44)
        }
        .padding(.horizontal, 26).padding(.top, 16).padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardGlass(RoundedRectangle(cornerRadius: 30, style: .continuous), tint: 0.86)
        .shadow(color: HomeColor.shadow1.opacity(0.22), radius: 15, y: 22).shadow(color: HomeColor.shadow1.opacity(0.14), radius: 5, y: 4)
        .overlay { Color.clear.accessibilityElement(children: .ignore).accessibilityLabel(Text(spoken)).allowsHitTesting(false) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var stateIcon: some View {
        switch state {
        case .notCollected:
            Circle().strokeBorder(HomeColor.ink3, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .overlay { Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(HomeColor.ink3) }
        case .wishlisted:
            Circle().fill(PassportColor.accentTint).overlay(Circle().strokeBorder(HomeColor.label, lineWidth: 1.5))
                .overlay { Image(systemName: "bookmark.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(HomeColor.label) }
        case .collectedManual:
            Circle().fill(HomeColor.cta).overlay { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(HomeColor.ctaText) }
        case .collectedVerified:
            VerifiedSeal(size: 28)
        }
    }

    @ViewBuilder private var trailing: some View {
        switch state {
        case .collectedManual where canVerify:
            Button(action: onVerify) {
                Text("Verify visit").font(.system(size: lineSize, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityHint(Text("Opens verification. You need to be at the place.")).accessibilityIdentifier("verify-button")
        case .collectedVerified:
            if let collectedAt { Text(collectedAt.formatted(.dateTime.day().month(.abbreviated).year())).font(.system(size: 13, weight: .medium)).foregroundStyle(HomeColor.sub).accessibilityHidden(true) }
        default:
            EmptyView()
        }
    }

    private var stateTitle: String {
        switch state {
        case .notCollected: String(localized: "Not in your passport yet")
        case .wishlisted: String(localized: "On your wishlist")
        case .collectedManual: String(localized: "In your passport")
        case .collectedVerified: String(localized: "Verified visit")
        }
    }

    private var spoken: String {
        let head = "\(name), \(countryName), \(categoryTitle)."
        func day(_ d: Date?) -> String { d?.formatted(date: .long, time: .omitted) ?? "" }
        switch state {
        case .notCollected: return head + " " + String(localized: "Not in your passport yet. Collect by hand, or verify when you visit.")
        case .wishlisted: return head + " " + String(localized: "On your wishlist. Saved for later. It is not collected yet.")
        case .collectedManual: return head + " " + String(localized: "In your passport. Collected by hand, \(day(collectedAt)).")
        case .collectedVerified:
            if let verifiedAt, let collectedAt, !Calendar.current.isDate(verifiedAt, inSameDayAs: collectedAt) {
                return head + " " + String(localized: "Verified visit. Collected \(day(collectedAt)), checked on \(day(verifiedAt)).")
            }
            return head + " " + String(localized: "Verified visit. Collected \(day(collectedAt)), checked at the place.")
        }
    }
}

// MARK: - Actions

struct StagePill: View {
    enum Kind { case primary, quiet, selected }

    let title: LocalizedStringKey
    var symbol: String?
    var kind: Kind = .quiet
    var isBusy = false
    var isDisabled = false
    var identifier: String
    let action: () -> Void

    @ScaledMetric(relativeTo: .headline) private var size = 16.5

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy { ProgressView().controlSize(.small).tint(foreground) }
                else if let symbol { Image(systemName: symbol).font(.system(size: size - 1, weight: .semibold)).contentTransition(.symbolEffect(.replace)) }
                Text(title).font(.system(size: size, weight: .bold)).tracking(-0.011 * size).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(foreground).frame(maxWidth: .infinity, minHeight: 54)
            .background { background }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).disabled(isDisabled || isBusy).opacity(isDisabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.25), value: kind).accessibilityIdentifier(identifier)
    }

    private var foreground: Color {
        switch kind {
        case .primary: HomeColor.ctaText
        case .quiet: HomeColor.ink
        case .selected: HomeColor.label
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .primary:
            Capsule().fill(HomeColor.cta).shadow(color: HomeColor.cta.opacity(0.45), radius: 11, y: 14).overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1).padding(1))
        case .quiet:
            Capsule().fill(PassportColor.quiet).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
        case .selected:
            Capsule().fill(PassportColor.accentTint).overlay(Capsule().strokeBorder(HomeColor.label, lineWidth: 1.5))
        }
    }
}

/// The two pills under the ticket. Only the actions that fit the state are offered.
struct StampActionBar: View {
    let state: StampDetailState
    let isWorking: Bool
    let canCollect: Bool
    let canShare: Bool
    let onCollect: () -> Void
    let onWishlist: () -> Void
    let onAddMemory: () -> Void
    let onShare: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 14))
        layout {
            switch state {
            case .notCollected, .wishlisted:
                StagePill(title: canCollect ? (isWorking ? "Collecting" : "Collect stamp") : "Unavailable", symbol: "plus", kind: .primary, isBusy: isWorking, isDisabled: !canCollect,
                          identifier: "stamp-collect", action: onCollect)
                    .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 206)
                    .accessibilityHint(Text("Adds this stamp to your passport"))
                if state == .wishlisted {
                    StagePill(title: "Saved", symbol: "bookmark.fill", kind: .selected, isDisabled: isWorking, identifier: "stamp-wishlist", action: onWishlist)
                        .accessibilityLabel(Text("On your wishlist")).accessibilityHint(Text("Double tap to remove"))
                } else {
                    StagePill(title: "Wishlist", symbol: "bookmark", kind: .quiet, isDisabled: isWorking, identifier: "stamp-wishlist", action: onWishlist)
                        .accessibilityLabel(Text("Add to wishlist"))
                }
            case .collectedManual, .collectedVerified:
                StagePill(title: "Add memory", symbol: "square.and.pencil", kind: .primary, identifier: "stamp-add-memory", action: onAddMemory)
                    .frame(maxWidth: typeSize.isAccessibilitySize || !canShare ? .infinity : 206)
                if canShare { StagePill(title: "Share", symbol: "square.and.arrow.up", kind: .quiet, identifier: "stamp-share", action: onShare) }
            }
        }
    }
}
