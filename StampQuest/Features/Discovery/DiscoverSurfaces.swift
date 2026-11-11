import SwiftUI

extension Destination {
    /// "Japan · History": the subline of a place in Discover.
    var countryCategoryLine: String { "\(countryName) · \(category.singularTitle)" }
}

extension StampState {
    /// What VoiceOver and the row text say about a place's state. Saved and collected are different things (rule 3).
    /// A verified place reads as collected here: verification belongs to Passport and Stamp detail.
    var discoverSpoken: String? {
        switch self {
        case .collected, .verified: String(localized: "In your passport")
        case .wishlisted: String(localized: "Saved to wishlist")
        case .notCollected: nil
        }
    }
}

/// A catalog stamp, or the designed placeholder (same perforation, a quiet pattern, the name) when its design is missing.
struct DiscoverStamp: View {
    let design: StampDesign?
    let name: String
    var aspect: CGFloat = StampMetrics.aspectRatio
    var showsTitle = false
    var lifted = true

    var body: some View {
        if let design {
            PerforatedStampView(design: design, showsTitle: showsTitle, isDecorative: true, lifted: lifted, aspectRatio: aspect)
        } else {
            MissingStampArtwork(name: name).aspectRatio(aspect, contentMode: .fit)
        }
    }
}

/// The state badges shared by every place stamp on Discover. Collected is an accent check at the bottom right, saved is a
/// bookmark at the top left. Never gold, never "verified": a verified place just reads as collected here.
private struct DiscoverStateBadge: ViewModifier {
    let state: StampState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if state.isInPassport {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                        .frame(width: 24, height: 24).background(HomeColor.cta, in: Circle())
                        .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
                        .offset(x: 10, y: 10).transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .topLeading) {
                if state == .wishlisted {
                    Image(systemName: "bookmark.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(HomeColor.label)
                        .frame(width: 22, height: 22).background(HomeColor.card, in: Circle())
                        .overlay(Circle().strokeBorder(PassportColor.cardLine, lineWidth: 1))
                        .offset(x: -4, y: -6).transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.7), value: state)
    }
}

extension View {
    func discoverStateBadge(_ state: StampState) -> some View { modifier(DiscoverStateBadge(state: state)) }
}

/// The matched text of a title or subline in accent and bold. Only the text that is on screen is highlighted.
enum DiscoverHighlight {
    static func attributed(_ text: String, query: String, accent: Color = HomeColor.label) -> AttributedString {
        var attributed = AttributedString(text)
        for token in query.split(whereSeparator: \.isWhitespace).map(String.init) where !token.isEmpty {
            var window = text.startIndex..<text.endIndex
            while let found = text.range(of: token, options: [.caseInsensitive, .diacriticInsensitive], range: window) {
                let lower = attributed.index(attributed.startIndex, offsetByCharacters: text.distance(from: text.startIndex, to: found.lowerBound))
                let upper = attributed.index(attributed.startIndex, offsetByCharacters: text.distance(from: text.startIndex, to: found.upperBound))
                attributed[lower..<upper].foregroundColor = accent
                attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
                window = found.upperBound..<text.endIndex
            }
        }
        return attributed
    }
}

/// A place in a list (Search and Results): 44 pt stamp, name, "Country · Category", then its state.
struct DiscoverPlaceRow: View {
    let item: DestinationItem
    var query = ""
    @ScaledMetric(relativeTo: .headline) private var titleSize = 17.0
    @ScaledMetric(relativeTo: .footnote) private var subSize = 13.0

    var body: some View {
        HStack(spacing: 14) {
            DiscoverStamp(design: item.design, name: item.destination.name, lifted: false).frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(DiscoverHighlight.attributed(item.destination.name, query: query)).font(.system(size: titleSize, weight: .semibold)).foregroundStyle(HomeColor.ink)
                    .lineLimit(2)
                Text(DiscoverHighlight.attributed(item.destination.countryCategoryLine, query: query)).font(.system(size: subSize, weight: .medium)).foregroundStyle(HomeColor.sub)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            DiscoverRowAccessory(state: item.state)
        }
        .padding(.vertical, 6).frame(minHeight: 56).contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.destination.name), \(item.destination.countryName), \(item.destination.category.singularTitle)"))
        .accessibilityValue(Text(item.state.discoverSpoken ?? ""))
        .accessibilityAddTraits(.isButton)
    }
}

/// The right side of a place row: "In passport", a filled bookmark, or a chevron.
struct DiscoverRowAccessory: View {
    let state: StampState

    var body: some View {
        Group {
            if state.isInPassport {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                    Text("In passport").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(HomeColor.label)
            } else if state == .wishlisted {
                Image(systemName: "bookmark.fill").font(.system(size: 16)).foregroundStyle(HomeColor.label)
            } else {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeColor.ink3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One interest: a catalog stamp with its name and "N places" or "Your pick".
struct DiscoverInterestTile: View {
    let interest: DiscoverInterest
    let art: DestinationItem?
    let tilt: Double
    var scale: CGFloat = 1
    @ScaledMetric(relativeTo: .subheadline) private var nameSize = 14.5
    @ScaledMetric(relativeTo: .caption) private var subSize = 12.0
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DiscoverStamp(design: art?.design, name: interest.category.title, aspect: 84.0 / 109.0)
                .frame(width: 84 * scale, height: 109 * scale)
                .rotationEffect(.degrees(tilt))
                .overlay(alignment: .topTrailing) {
                    if interest.isPick {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(HomeColor.ctaText)
                            .frame(width: 24, height: 24).background(HomeColor.cta, in: Circle())
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 2).offset(x: 12, y: -8)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(interest.category.title).font(.system(size: nameSize, weight: .semibold)).foregroundStyle(HomeColor.ink).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true).minimumScaleFactor(0.7)
                if interest.isPick {
                    Text("Your pick").font(.system(size: subSize, weight: .semibold)).foregroundStyle(HomeColor.label)
                } else {
                    Text("^[\(interest.count) place](inflect: true)").font(.system(size: subSize, weight: .medium)).foregroundStyle(HomeColor.sub)
                }
            }
            // Wide enough at accessibility sizes that a word is never cut in the middle.
            .frame(width: (typeSize.isAccessibilitySize ? 170 : 92) * scale, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(interestLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var interestLabel: Text {
        let places = Text("^[\(interest.count) place](inflect: true)")
        return interest.isPick ? Text("\(interest.category.title). ") + places + Text(". Your pick.") : Text("\(interest.category.title). ") + places + Text(".")
    }
}
