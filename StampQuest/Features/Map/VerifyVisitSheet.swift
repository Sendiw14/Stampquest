import SwiftUI

/// The optional "verify my visit" flow. It explains what will happen before asking for
/// anything, reports every failure honestly, and always offers the manual alternative.
struct VerifyVisitSheet: View {
    let item: DestinationItem

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case intro
        case working
        case verified(distance: Double, collectedNew: Bool, alreadyVerified: Bool)
        case failed(VerificationFailure)
        case saveFailed
    }

    @State private var phase: Phase = .intro
    @State private var task: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SQSpace.lg) {
                    PerforatedStampView(design: item.design, showsTitle: false, isDecorative: true)
                        .frame(width: 110)
                        .rotationEffect(.degrees(-3))
                        .padding(.top, SQSpace.md)
                    switch phase {
                    case .intro: intro
                    case .working: working
                    case .verified(let distance, let collectedNew, let already): verified(distance: distance, collectedNew: collectedNew, already: already)
                    case .failed(let failure): failed(failure)
                    case .saveFailed: saveFailed
                    }
                }
                .padding(SQSpace.screenMargin)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .sqScreenBackground()
            .navigationTitle("Verify visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { task?.cancel(); dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled({ if case .working = phase { true } else { false } }())
    }

    // MARK: Phases

    private var intro: some View {
        VStack(spacing: SQSpace.md) {
            Text("Are you at \(item.destination.landmark)?")
                .font(SQFont.title).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: SQSpace.sm) {
                point("location", "StampQuest checks your location once, right now. It never tracks you in the background.")
                point("hand.raised", "Your coordinates aren’t saved or sent anywhere. If it works, only the distance to the place is kept.")
                point("info.circle", "Location can be inaccurate or faked, so this is a friendly check, not proof.")
            }
            PrimaryActionButton(title: "Check my location", systemImage: "location.fill", action: start)
                .accessibilityIdentifier("verify-start")
            if !item.state.isInPassport { collectWithoutVerifying }
        }
    }

    private var working: some View {
        VStack(spacing: SQSpace.md) {
            ProgressView().controlSize(.large)
            Text(env.verification.phase == .requestingPermission ? "Waiting for your permission…" : "Finding your location…")
                .font(SQFont.headline)
            Text("This usually takes a few seconds.").font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary)
            SecondaryActionButton(title: "Cancel") { task?.cancel() }
        }
        .accessibilityElement(children: .contain)
    }

    private func verified(distance: Double, collectedNew: Bool, already: Bool) -> some View {
        VStack(spacing: SQSpace.md) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(SQColor.verified).accessibilityHidden(true)
            Text(already ? "Already verified" : "Visit verified").font(SQFont.title)
            Text(already ? "This visit was verified earlier, so nothing changed."
                 : "You’re about \(Measurement(value: distance, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))) from \(item.destination.landmark).")
                .font(SQFont.body).foregroundStyle(SQColor.textSecondary).multilineTextAlignment(.center)
            PrimaryActionButton(title: "Done") {
                dismiss()
                if collectedNew, let stamp = env.store.stamp(forDestination: item.id) {
                    // Let the sheet finish dismissing before presenting the full-screen reveal.
                    Task { try? await Task.sleep(for: .milliseconds(450)); env.presentReveal(for: stamp) }
                }
            }
            .accessibilityIdentifier("verify-done")
        }
    }

    private func failed(_ failure: VerificationFailure) -> some View {
        VStack(spacing: SQSpace.md) {
            Image(systemName: "location.slash").font(.system(size: 40, weight: .light)).foregroundStyle(SQColor.warning).accessibilityHidden(true)
            Text(failure.title).font(SQFont.title).multilineTextAlignment(.center)
                .accessibilityIdentifier("verify-failure-title")
            Text(failure.message).font(SQFont.body).foregroundStyle(SQColor.textSecondary).multilineTextAlignment(.center)
            if failure.suggestsSettings {
                PrimaryActionButton(title: "Open Settings", systemImage: "gearshape") { env.openSystemSettings() }
            } else if failure != .featureDisabled && failure != .missingDestinationCoordinates {
                PrimaryActionButton(title: "Try again", systemImage: "arrow.clockwise", action: start)
            }
            if !item.state.isInPassport { collectWithoutVerifying }
        }
    }

    private var saveFailed: some View {
        VStack(spacing: SQSpace.md) {
            InlineErrorView(title: "Couldn’t save", message: "Your location matched, but the result couldn’t be saved, so nothing was changed.", retry: start)
        }
    }

    private var collectWithoutVerifying: some View {
        SecondaryActionButton(title: "Collect without verifying", systemImage: "plus.circle") {
            dismiss()
            Task { try? await Task.sleep(for: .milliseconds(450)); env.collect(item.id) }
        }
        .accessibilityIdentifier("verify-collect-manually")
    }

    private func point(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: SQSpace.sm) {
            Image(systemName: symbol).frame(width: 24).foregroundStyle(SQColor.accentText).accessibilityHidden(true)
            Text(text).font(SQFont.subheadline).foregroundStyle(SQColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Run

    private func start() {
        guard !env.verification.isBusy else { return }
        phase = .working
        task = Task {
            let attempt = await env.verify(item.destination)
            // Always reflect the real outcome, even if "Cancel" raced a success: the record
            // may already be saved, and the screen must never claim otherwise.
            switch attempt {
            case .success(let outcome):
                env.haptics.success()
                let v = outcome.stamp.verification
                switch outcome {
                case .collectedAndVerified: phase = .verified(distance: v?.distanceMeters ?? 0, collectedNew: true, alreadyVerified: false)
                case .upgraded: phase = .verified(distance: v?.distanceMeters ?? 0, collectedNew: false, alreadyVerified: false)
                case .alreadyVerified: phase = .verified(distance: v?.distanceMeters ?? 0, collectedNew: false, alreadyVerified: true)
                }
            case .failure(let failure):
                phase = failure == .cancelled ? .intro : .failed(failure)
            case .saveFailed:
                phase = .saveFailed
            }
        }
    }
}
