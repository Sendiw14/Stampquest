import SwiftUI

/// "Map markers": what each marker on the map means, drawn with the same marker views the map uses.
struct MapMarkerGuideSheet: View {
    let onDone: () -> Void
    @Environment(\.passport) private var passport
    @ScaledMetric(relativeTo: .title2) private var titleSize = 24.0

    private struct Row: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let content: MapMarkerContent?
        var cluster = false
    }

    /// The design of a real catalog stamp stands in for the sample marker's art.
    private var sample: StampDesign? { passport.catalog.stamps.first }

    private var rows: [Row] {
        [
            Row(id: "available", title: "Place to collect", subtitle: "Not in your passport yet.", content: MapMarkerContent(name: "", state: .notCollected)),
            Row(id: "saved", title: "On your wishlist", subtitle: "Saved to collect later.", content: MapMarkerContent(name: "", state: .wishlisted)),
            Row(id: "collected", title: "In your passport", subtitle: "Collected by hand or on a visit.", content: MapMarkerContent(name: "", state: .collected, design: sample)),
            Row(id: "verified", title: "Verified visit", subtitle: "Collected and verified on location. Gold appears only here.", content: MapMarkerContent(name: "", state: .verified, design: sample)),
            Row(id: "cluster", title: "Several places", subtitle: "Tap to zoom in. A check means one is already in your passport.", content: nil, cluster: true),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Map markers").font(.system(size: titleSize, weight: .heavy)).tracking(-0.03 * titleSize).foregroundStyle(HomeColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onDone) {
                    Text("Done").font(.system(size: 16, weight: .semibold)).foregroundStyle(HomeColor.label).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain).accessibilityIdentifier("map-guide-done")
            }
            .padding(.horizontal, 24).padding(.top, 28)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Rectangle().fill(PassportColor.cardLine).frame(height: 1).padding(.leading, 100) }
                        HStack(spacing: 0) {
                            marker(row).frame(width: 100)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(HomeColor.ink)
                                Text(row.subtitle).font(.system(size: 13.5, weight: .regular)).foregroundStyle(HomeColor.sub).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12).padding(.trailing, 24).frame(minHeight: 72)
                        .accessibilityElement(children: .combine).accessibilityIdentifier("map-guide-\(row.id)")
                    }
                    Text("Your own position shows on the map only after you tap Locate.").font(.system(size: 13.5, weight: .regular)).foregroundStyle(HomeColor.sub)
                        .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 30)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HomeColor.page.ignoresSafeArea())
    }

    @ViewBuilder
    private func marker(_ row: Row) -> some View {
        if row.cluster { MapClusterView(count: 6, hasCollected: true).scaleEffect(0.85) }
        else if let content = row.content { MapMarkerArt(content: content).frame(width: 60, height: 60) }
    }
}

/// Asked once, in words, before the system prompt: why Locate wants the position and what it never does.
struct MapLocationExplainerSheet: View {
    let onContinue: () -> Void
    let onNotNow: () -> Void
    @ScaledMetric(relativeTo: .title) private var titleSize = 26.0

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "location.fill").font(.system(size: 30, weight: .semibold)).foregroundStyle(HomeColor.label)
                .frame(width: 64, height: 64).background(PassportColor.accentTint, in: Circle()).padding(.top, 36).accessibilityHidden(true)
            Text("Use your location?").font(.system(size: titleSize, weight: .heavy)).tracking(-0.03 * titleSize).foregroundStyle(HomeColor.ink)
                .multilineTextAlignment(.center).padding(.top, 14).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 12) {
                point("mappin.and.ellipse", "Only when you locate or verify a visit")
                point("location.slash", "Never tracked in the background")
                point("map", "Every place stays browsable without it")
            }
            .padding(.horizontal, 34).padding(.top, 22)
            Spacer(minLength: 16)
            Button(action: onContinue) {
                Text("Continue").font(.system(size: 17, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                    .frame(maxWidth: .infinity, minHeight: 56).background(HomeColor.cta, in: Capsule())
            }
            .buttonStyle(.plain).padding(.horizontal, 24).accessibilityIdentifier("map-location-continue")
            Button(action: onNotNow) {
                Text("Not now").font(.system(size: 16.5, weight: .semibold)).foregroundStyle(HomeColor.sub).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain).padding(.bottom, 12).accessibilityIdentifier("map-location-not-now")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HomeColor.page.ignoresSafeArea())
    }

    private func point(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(HomeColor.label).frame(width: 28).accessibilityHidden(true)
            Text(text).font(.system(size: 15.5, weight: .medium)).foregroundStyle(HomeColor.ink).fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 34)
    }
}
