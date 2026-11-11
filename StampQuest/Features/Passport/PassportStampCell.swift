import SwiftUI

/// One stamp as it sits in the grid and on a page: the stamp (3:4, a fixed tilt by position), its name and its date,
/// with the gold seal for a verified visit and a heart for a favorite. No other badge exists.
struct PassportStampCell: View {
    let entry: PassportEntry
    let width: CGFloat
    let tilt: Double
    var now: Date = .now

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var nameSize = 14.5
    @ScaledMetric(relativeTo: .caption) private var dateSize = 12.0

    var body: some View {
        VStack(spacing: 9) {
            stamp
            VStack(spacing: 1) {
                Text(entry.name).font(.system(size: nameSize, weight: .semibold)).foregroundStyle(HomeColor.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1).multilineTextAlignment(.center)
                Text(PassportDateText.short(entry.collectedAt, now: now)).font(.system(size: dateSize, weight: .medium)).foregroundStyle(HomeColor.sub).lineLimit(1)
            }
            .frame(width: width + 16)
        }
        .frame(width: width + 16)
        .contentShape(Rectangle())
    }

    private var stamp: some View {
        Group {
            if let design = entry.design {
                PerforatedStampView(design: design, showsTitle: width > 80, isDecorative: true, lifted: false, aspectRatio: 0.75)
            } else { MissingStampArtwork(name: entry.name) }
        }
        .frame(width: width, height: width * 4 / 3)
        .shadow(color: .black.opacity(0.10), radius: 1.5, y: 1)
        .shadow(color: HomeColor.shadow1.opacity(0.22), radius: 9, y: 8)
        .overlay(alignment: .bottomTrailing) {
            if entry.isVerified { VerifiedSeal(size: 26).rotationEffect(.degrees(8)).offset(x: 5, y: 3) }
        }
        .overlay(alignment: .topLeading) {
            if entry.isFavorite {
                Image(systemName: "heart.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(HomeColor.cta)
                    .frame(width: 22, height: 22).background(HomeColor.card, in: Circle())
                    .overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1)).offset(x: -4, y: -6)
            }
        }
        .rotationEffect(.degrees(tilt))
        .accessibilityHidden(true)
    }
}

extension PassportEntry {
    /// "Rome, Italy. Collected 5 November. Verified visit. Favorite." Verified is always spoken.
    func spokenLabel(calendar: Calendar = .current) -> String {
        var parts = [String(localized: "\(name), \(countryName). Collected \(PassportDateText.long(collectedAt, calendar: calendar)).")]
        if isVerified { parts.append(String(localized: "Verified visit.")) }
        if isFavorite { parts.append(String(localized: "Favorite.")) }
        return parts.joined(separator: " ")
    }
}
