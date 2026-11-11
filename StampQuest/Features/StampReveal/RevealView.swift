import SwiftUI

/// The collection reveal: the same stage as Stamp detail, bigger, shown once right after a collect has been saved. One calm
/// event: the detail recedes, the poster rises, the stamp arrives, the postmark presses and the name appears, then the next
/// steps. No particles, no flashing, no sound. It can be dismissed at any moment (the X is there from the first frame).
///
/// Shown in place from Stamp detail (`morphs`), where the exit morphs the stage back onto the detail layout, and over any other
/// screen through `RevealView`, where it cross-fades in and out.
struct CollectionRevealView: View {
    let name: String
    let countryName: String
    let categoryTitle: String
    let design: StampDesign?
    let payload: RevealPayload
    let completedTitle: String?
    let morphs: Bool
    let layout: StageLayout
    var postmarkHidden = false
    let canAddMemory: Bool
    let onAddMemory: () -> Void
    let onDone: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorScheme) private var scheme
    @State private var dim = false
    @State private var risen = false
    @State private var arrived = false
    @State private var pressed = false
    @State private var settled = false
    @State private var t: CGFloat = 1
    @State private var leaving = false
    @State private var run: Task<Void, Never>?
    @AccessibilityFocusState private var nameFocused: Bool

    private var reduceMotion: Bool { env.reducesMotion(system: systemReduceMotion) || voiceOver }
    private var state: StampDetailState { payload.isVerified ? .collectedVerified : .collectedManual }
    private var u: CGFloat { layout.u }
    private var extra: CGFloat { layout.extra }
    private var l: StageLayout { var copy = layout; copy.t = t; return copy }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The detail behind recedes under a dark scrim; it is only there when the reveal is shown in place.
            if morphs { Color.black.opacity(dim ? 0.55 : 0).ignoresSafeArea().allowsHitTesting(false) }
            if !reduceMotion, !risen { outline }
            poster
            StampStageLayer(name: name, countryName: countryName, design: design, state: state, collectedAt: payload.collectedAt, layout: l, postmarkHidden: postmarkHidden,
                            postmarkPress: pressed ? 1 : 1.35, postmarkOpacity: pressed ? 1 : 0, ringOpacity: arrived ? 1 : 0.4,
                            stampOpacity: arrived || reduceMotion ? 1 : 0, stampScale: arrived || reduceMotion ? 1 : 1.14)
                .blur(radius: arrived || reduceMotion ? 0 : 0.7)
            texts
            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(leaving && !morphs ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { skipAhead() }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { exit() }
        .task { run = Task { await play() }; await run?.value }
    }

    // MARK: Layers

    private var outline: some View {
        ZStack {
            PerforatedStampShape().stroke(Color(hex: 0xFFF3DE).opacity(0.62), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
                .frame(width: l.stampWidth + 18 * u, height: l.stampHeight + 18 * u).rotationEffect(.degrees(-3))
            Circle().strokeBorder(Color(hex: 0xFFF3DE).opacity(0.34), style: StrokeStyle(lineWidth: 2.2, dash: [3, 6])).frame(width: 340 * u, height: 340 * u)
        }
        .position(l.center).opacity(dim ? 1 : 0).allowsHitTesting(false)
    }

    private var poster: some View {
        PosterBackground()
            .frame(width: layout.width, height: l.posterHeight)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: risen || reduceMotion ? 0 : 40, topTrailingRadius: risen || reduceMotion ? 0 : 40))
            .offset(y: risen || reduceMotion ? 0 : 640 * u)
            .opacity(reduceMotion && !dim ? 0 : 1)
    }

    private var texts: some View {
        ZStack {
            VStack(spacing: 0) {
                Text(name).font(.system(size: 40 * u, weight: .heavy)).tracking(-0.04 * 40 * u).foregroundStyle(HomeColor.cream).lineLimit(2).minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader).accessibilityFocused($nameFocused).accessibilityIdentifier("reveal-name")
                    .opacity(pressed ? 1 : 0).offset(y: pressed || reduceMotion ? 0 : 6)
                Text("\(countryName) · \(categoryTitle)").font(.system(size: 15.5 * u, weight: .semibold)).foregroundStyle(.white).padding(.top, 8 * u)
                    .opacity(settled ? 1 : 0)
                chip.padding(.top, 20 * u).opacity(settled ? 1 : 0)
                Text(dateLine).font(.system(size: 13.5 * u, weight: .semibold)).foregroundStyle(.white).padding(.top, 14 * u).opacity(settled ? 1 : 0)
                    .accessibilityIdentifier("reveal-date")
                buttons.padding(.top, 28 * u).opacity(settled ? 1 : 0).allowsHitTesting(settled || reduceMotion)
                if let completedTitle {
                    Text("You completed \(completedTitle)").font(.system(size: 14 * u, weight: .semibold)).foregroundStyle(HomeColor.cream).padding(.top, 18 * u).opacity(settled ? 1 : 0)
                }
            }
            .padding(.horizontal, 24 * u).frame(width: layout.width)
        }
        .frame(width: layout.width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top).padding(.top, 528 * u + extra)
        .opacity(leaving ? 0 : 1)
    }

    private var chip: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 13 * u, weight: .bold))
            Text(payload.isVerified ? "Added to your passport · Visit verified" : "Added to your passport").font(.system(size: 15 * u, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
                .accessibilityIdentifier("reveal-confirmation")
        }
        .foregroundStyle(HomeColor.cream).padding(.horizontal, 18 * u).frame(minHeight: 40 * u).posterGlass(Capsule())
    }

    private var dateLine: String {
        let date = payload.collectedAt.formatted(.dateTime.day().month(.abbreviated).year())
        return payload.isVerified ? String(localized: "Verified visit · \(date)") : String(localized: "Collected by hand · \(date)")
    }

    private var buttons: some View {
        let fill = scheme == .dark ? HomeColor.cta : Color(hex: 0xFFF3DE)
        let text = scheme == .dark ? HomeColor.ctaText : Color(hex: 0x6A331C)
        return HStack(spacing: 14 * u) {
            if canAddMemory {
                Button(action: addMemory) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil").font(.system(size: 15 * u, weight: .semibold))
                        Text("Add a memory").font(.system(size: 16.5 * u, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(text).frame(maxWidth: .infinity, minHeight: 54 * u).background(fill, in: Capsule()).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityIdentifier("reveal-add-memory")
            }
            Button { exit() } label: {
                Text("Done").font(.system(size: 16.5 * u, weight: .bold)).foregroundStyle(HomeColor.cream).frame(maxWidth: canAddMemory ? 134 * u : .infinity, minHeight: 54 * u)
                    .posterGlass(Capsule()).contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("reveal-done")
        }
        .frame(maxWidth: 354 * u)
    }

    private var closeButton: some View {
        Button { exit() } label: {
            Image(systemName: "xmark").font(.system(size: 15 * u, weight: .bold)).foregroundStyle(HomeColor.cream).frame(width: 40 * u, height: 40 * u).posterGlass(Circle())
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(Text("Close")).accessibilityIdentifier("reveal-close")
        .offset(x: 22 * u, y: 60 * u + extra).opacity(leaving ? 0 : 1)
    }

    // MARK: Sequence (the timings are a proposal: tune by eye)

    private func play() async {
        if reduceMotion {
            // One calm cross-fade; everything is already where it ends.
            withAnimation(.easeInOut(duration: 0.35)) { dim = true; risen = true; arrived = true }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 0.3)) { pressed = true }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 0.3)) { settled = true }
            announce()
            return
        }
        do {
            withAnimation(.easeOut(duration: 0.3)) { dim = true }                       // 0 to 0.3: the detail recedes, an outline waits
            try await Task.sleep(for: .milliseconds(300))
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.9)) { risen = true; arrived = true }   // 0.3 to 1.2: the poster rises, the stamp arrives
            try await Task.sleep(for: .milliseconds(1_200))
            withAnimation(.timingCurve(0.3, 1.5, 0.5, 1, duration: 0.45)) { pressed = true }               // 1.5: the postmark presses, the name appears
            try await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.5)) { settled = true }                    // 2.4: settled, the next step is offered
            announce()
        } catch { /* cancelled: the person dismissed it */ }
    }

    private func skipAhead() {
        guard !settled else { return }
        run?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { dim = true; risen = true; arrived = true; pressed = true; settled = true }
        announce()
    }

    private func announce() {
        AccessibilityNotification.Announcement(String(localized: "\(name) added to your passport.")).post()
        nameFocused = true
    }

    private func addMemory() {
        exit(thenAddMemory: true)
    }

    /// Always available: cancels whatever is running and leaves at once. In place the stage morphs back onto the detail layout.
    private func exit(thenAddMemory: Bool = false) {
        guard !leaving else { return }
        run?.cancel()
        leaving = true
        Task {
            if morphs, !reduceMotion {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { t = 0; dim = false; settled = false; pressed = true; risen = true; arrived = true }
                try? await Task.sleep(for: .milliseconds(520))
            } else {
                withAnimation(.easeOut(duration: 0.25)) { dim = false }
                try? await Task.sleep(for: .milliseconds(260))
            }
            if thenAddMemory { onAddMemory() } else { onDone() }
        }
    }
}

/// The reveal shown over whatever screen collected the stamp (Discover, Map, Destination detail and the verify flow). It
/// cross-fades in and out instead of morphing.
struct RevealView: View {
    let payload: RevealPayload

    @Environment(AppEnvironment.self) private var env
    @Environment(\.passport) private var passport
    @State private var showEditor = false

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, 560)
            let u = min(1.10, max(0.93, width / 402))
            let layout = StageLayout(u: u, extra: max(0, proxy.safeAreaInsets.top - 54), width: proxy.size.width)
            ZStack {
                if let destination = passport.catalog.destination(id: payload.destinationID) {
                    CollectionRevealView(name: destination.name, countryName: destination.countryName, categoryTitle: destination.category.singularTitle,
                                         design: passport.catalog.stamp(forDestination: destination.id), payload: payload,
                                         completedTitle: payload.completedCollectionID.flatMap { passport.catalog.collection(id: $0)?.title },
                                         morphs: false, layout: layout,
                                         postmarkHidden: passport.catalog.stamp(forDestination: destination.id).map { env.preferences.isPostmarkHidden($0.id) } ?? false,
                                         canAddMemory: true, onAddMemory: { showEditor = true }, onDone: dismiss)
                } else {
                    // The catalog entry vanished between saving and presenting: fail soft.
                    EmptyStateView(title: "Stamp added", message: "It’s safely in your passport.", systemImage: "checkmark.seal", actionTitle: "Done") { dismiss() }
                        .background(HomeColor.page.ignoresSafeArea())
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .sheet(isPresented: $showEditor) { MemoryEditorSheet(prefilledDestinationID: payload.destinationID) }
    }

    private func dismiss() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { env.router.dismissReveal() }
    }
}
