import SwiftUI

// MARK: - Type

private struct MemoryFontModifier: ViewModifier {
    @ScaledMetric private var scaled: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    let italic: Bool

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, italic: Bool, relativeTo: Font.TextStyle) {
        _scaled = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
        self.design = design
        self.italic = italic
    }

    func body(content: Content) -> some View {
        let font = Font.system(size: scaled, weight: weight, design: design)
        content.font(italic ? font.italic() : font)
    }
}

extension View {
    /// A font sized from the design (in points) that still scales with Dynamic Type. Serif is New York, used for memory content.
    func memoryFont(_ size: CGFloat, _ weight: Font.Weight = .regular, serif: Bool = false, italic: Bool = false,
                    relativeTo: Font.TextStyle = .body) -> some View {
        modifier(MemoryFontModifier(size: size, weight: weight, design: serif ? .serif : .default, italic: italic, relativeTo: relativeTo))
    }
}

// MARK: - Photos

/// A photo from the app's private store at display size (decoded off the main actor, cached). A missing or unreadable file
/// becomes the Unavailable tile, never a hole or a crash; while it loads there is a quiet skeleton, not a spinner.
struct MemoryPhoto: View {
    let filename: String
    var maxPixel: Int = 700
    var radius: CGFloat = 16
    var spokenLabel: String?
    /// Show the whole photo (the full-screen viewer) instead of filling the frame.
    var fit = false

    @Environment(AppEnvironment.self) private var env
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if fit {
                ZStack {
                    if let image { Image(uiImage: image).resizable().scaledToFit() }
                    else if failed { MemoryUnavailableTile(radius: radius).frame(width: 220, height: 220) }
                }
            } else {
                // The frame takes the size it is offered; a filled image is only drawn into it, so a wide photo can never make
                // its row wider than the screen.
                Color.clear.overlay { content }.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
        .task(id: filename) {
            failed = false
            image = await env.photos.thumbnail(for: filename, maxPixel: maxPixel)
            failed = image == nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(failed ? Text("Photo unavailable") : Text(spokenLabel ?? String(localized: "Photo")))
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder private var content: some View {
        if let image { Image(uiImage: image).resizable().scaledToFill() }
        else if failed { MemoryUnavailableTile(radius: radius) }
        else { HomeColor.tint.opacity(0.7) }
    }
}

/// A dashed tile standing in for a photo that cannot be loaded.
struct MemoryUnavailableTile: View {
    var radius: CGFloat = 16

    var body: some View {
        ZStack {
            PassportColor.quiet
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(HomeColor.ink3.opacity(0.6), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.exclamationmark").font(.system(size: 20, weight: .regular)).foregroundStyle(HomeColor.ink3)
                Text("Unavailable").memoryFont(10.5, .semibold, relativeTo: .caption2).foregroundStyle(HomeColor.sub).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(4)
        }
    }
}

/// A photo as a paper print: a cream card, an inset square photo and a layered shadow. Decorative.
struct MemoryPrint: View {
    let filename: String
    let width: CGFloat
    let tilt: Double

    var body: some View {
        MemoryPhoto(filename: filename, maxPixel: 300, radius: 3)
            .frame(width: width * 0.875, height: width * 0.875)
            .padding(.top, width * 0.0625)
            .frame(width: width, height: width * 1.156, alignment: .top)
            .background(Color(hex: 0xFBF7EE), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            .shadow(color: Color(hex: 0x3C1608).opacity(0.40), radius: 14, y: 12)
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}

// MARK: - Place line, tags

/// The place of a memory: its stamp, "Place · Country", and the gold seal only when that place has a verified visit.
struct MemoryPlaceLine: View {
    let item: MemoryItem
    var stampWidth: CGFloat = 17
    var size: CGFloat = 13.5

    @Environment(\.passport) private var passport

    var body: some View {
        let state = MemoryDerived.placeState(of: item, catalog: passport.catalog, snapshot: passport.snapshot)
        HStack(spacing: 6) {
            switch state {
            case .noPlace:
                Image(systemName: "mappin").font(.system(size: size - 1, weight: .semibold)).foregroundStyle(HomeColor.sub)
                Text("Not tied to a place").memoryFont(size, .medium, relativeTo: .footnote).foregroundStyle(HomeColor.sub)
            case .removedFromCatalog:
                DiscoverDashedSlot(width: stampWidth, height: stampWidth * 1.25)
                Text("Place no longer in the catalog").memoryFont(size, .medium, relativeTo: .footnote).foregroundStyle(HomeColor.sub)
            default:
                if let id = item.destinationID, let place = passport.item(id: id) {
                    DiscoverStamp(design: place.design, name: place.destination.name, lifted: false).frame(width: stampWidth).rotationEffect(.degrees(-2))
                    (Text(place.destination.name).fontWeight(.semibold).foregroundStyle(HomeColor.ink)
                        + Text(" · \(place.destination.countryName)").foregroundStyle(HomeColor.sub))
                        .memoryFont(size, .medium, relativeTo: .footnote)
                    if state == .verified { VerifiedSeal(size: 14) }
                }
            }
        }
        .lineLimit(1)
    }

    /// For VoiceOver: "Rome, Italy, verified visit".
    static func spoken(_ item: MemoryItem, catalog: Catalog, snapshot: PassportSnapshot) -> String? {
        let state = MemoryDerived.placeState(of: item, catalog: catalog, snapshot: snapshot)
        switch state {
        case .noPlace: return nil
        case .removedFromCatalog: return String(localized: "Place no longer in the catalog")
        default:
            guard let id = item.destinationID, let d = catalog.destination(id: id) else { return nil }
            let base = "\(d.name), \(d.countryName)"
            return state == .verified ? base + ", " + String(localized: "verified visit") : base
        }
    }
}

struct MemoryTagChip: View {
    let text: String

    var body: some View {
        Text(text).memoryFont(12, .semibold, relativeTo: .caption).foregroundStyle(HomeColor.sub).lineLimit(1)
            .padding(.horizontal, 12).frame(minHeight: 26)
            .background(PassportColor.quiet, in: Capsule()).overlay(Capsule().strokeBorder(PassportColor.cardLine, lineWidth: 1))
    }
}

/// Up to three tags; with more, the third reads "+n". Not tappable on the timeline.
struct MemoryTagRow: View {
    let tags: [String]
    var limit = 3

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 6) {
                if tags.count <= limit { ForEach(tags, id: \.self) { MemoryTagChip(text: $0) } }
                else {
                    ForEach(Array(tags.prefix(limit - 1)), id: \.self) { MemoryTagChip(text: $0) }
                    MemoryTagChip(text: "+\(tags.count - (limit - 1))")
                }
            }
        }
    }
}

// MARK: - Dates

extension Date {
    /// "Thu 5 November": the date of a memory in a row of search results.
    func memoryShortDate(calendar: Calendar = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)
        style = style.weekday(.abbreviated).day().month(.wide)
        return formatted(style)
    }

    /// "Thursday 5 November 2026"
    func memoryLongDate(calendar: Calendar = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)
        style = style.weekday(.wide).day().month(.wide).year()
        return formatted(style)
    }

    /// "Thursday 5 November": the collapsed date line at accessibility sizes.
    func memoryDayLine(calendar: Calendar = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, calendar: calendar, timeZone: calendar.timeZone)
        style = style.weekday(.wide).day().month(.wide)
        return formatted(style)
    }
}

// MARK: - Month header

struct MemoryMonthHeader: View {
    let date: Date
    let count: Int
    @ScaledMetric(relativeTo: .title2) private var size = 22.0
    @ScaledMetric(relativeTo: .footnote) private var countSize = 13.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.formatted(.dateTime.month(.wide).year())).font(.system(size: size, weight: .heavy)).tracking(-0.035 * size)
                    .foregroundStyle(HomeColor.ink).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text("^[\(count) memory](inflect: true)").font(.system(size: countSize, weight: .medium)).foregroundStyle(HomeColor.sub)
            }
            DottedRule()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(Text("\(date.formatted(.dateTime.month(.wide).year())), ^[\(count) memory](inflect: true)"))
    }
}

// MARK: - Timeline entry

/// One entry of the timeline in any of its four shapes: wide (3+ photos), pair, row, or a quote card. The date column and
/// the node sit left of the content; at accessibility sizes the date moves above and the spine and node disappear.
struct MemoryTimelineItem: View {
    let item: MemoryItem
    /// The scale of the 402 pt reference canvas.
    let u: CGFloat
    let collapsed: Bool
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    @Environment(\.passport) private var passport
    @ScaledMetric(relativeTo: .title) private var numeral = 26.0
    @ScaledMetric(relativeTo: .footnote) private var weekday = 12.5

    private var title: String { item.displayTitle() }

    var body: some View {
        Group {
            if collapsed {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.effectiveDate.memoryDayLine()).memoryFont(13, .semibold, relativeTo: .footnote).foregroundStyle(HomeColor.label)
                    content(width: nil)
                }
                .padding(.horizontal, 20)
            } else {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4 * u) {
                        Text(item.effectiveDate.formatted(.dateTime.day())).font(.system(size: numeral, weight: .heavy)).tracking(-0.04 * numeral)
                            .foregroundStyle(HomeColor.ink)
                        Text(item.effectiveDate.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: weekday, weight: .medium)).foregroundStyle(HomeColor.sub)
                    }
                    .offset(x: 20 * u, y: -2).frame(width: 76 * u, alignment: .topLeading)
                    node.offset(x: 85 * u, y: 12)
                    content(width: nil).padding(.leading, 112 * u).padding(.trailing, 20 * u)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spokenLabel))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Edit")) { onEdit() }
        .accessibilityAction(named: Text("Delete")) { onDelete() }
    }

    /// Filled accent with a page-colored ring when tied to a place; a hollow ring when not. Never gold.
    private var node: some View {
        let tied = item.destinationID != nil
        return ZStack {
            Circle().fill(HomeColor.page).frame(width: tied ? 20 : 18, height: tied ? 20 : 18)
            if tied { Circle().fill(HomeColor.cta).frame(width: 12, height: 12) }
            else { Circle().strokeBorder(HomeColor.cta, lineWidth: 2.2).frame(width: 12, height: 12) }
        }
        .frame(width: 12, height: 12).accessibilityHidden(true)
    }

    private var spokenLabel: String {
        var parts = [title, item.effectiveDate.memoryDayLine()]
        if let place = MemoryPlaceLine.spoken(item, catalog: passport.catalog, snapshot: passport.snapshot) { parts.append(place) }
        if item.hasPhotos { parts.append(String(localized: "\(item.photoFilenames.count) photos")) }
        if !item.tags.isEmpty { parts.append(String(localized: "Tags: ") + item.tags.joined(separator: ", ")) }
        return parts.joined(separator: ". ") + "."
    }

    @ViewBuilder
    private func content(width: CGFloat?) -> some View {
        switch item.shape {
        case .wide: wide
        case .pair: pair
        case .row: row
        case .note: note
        }
    }

    // MARK: Shapes

    private var wide: some View {
        VStack(alignment: .leading, spacing: 10) {
            MemoryPhoto(filename: item.photoFilenames[0], maxPixel: 900, radius: 18)
                .frame(maxWidth: .infinity).frame(height: 158 * u).clipped()
                .overlay(alignment: .bottomTrailing) { countChip.padding(10) }
            titleAndMeta(titleSize: 21, textLines: 2, showsTags: true)
        }
    }

    private var pair: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Array(item.photoFilenames.prefix(2)), id: \.self) {
                    MemoryPhoto(filename: $0, maxPixel: 500, radius: 16).frame(maxWidth: .infinity).frame(height: 150 * u).clipped()
                }
            }
            titleAndMeta(titleSize: 21, textLines: 2, showsTags: true)
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12 * u) {
            MemoryPhoto(filename: item.photoFilenames[0], maxPixel: 300, radius: 16).frame(width: 92 * u, height: 92 * u)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).memoryFont(18, .semibold, serif: true, relativeTo: .title3).foregroundStyle(HomeColor.ink).lineLimit(1)
                MemoryPlaceLine(item: item, stampWidth: 15 * 1, size: 13)
                if !item.text.isEmpty {
                    Text(item.text).memoryFont(14, .regular, serif: true, relativeTo: .subheadline).foregroundStyle(HomeColor.sub).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 118 * u, alignment: .top)
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("“").font(.system(size: 46, weight: .semibold, design: .serif)).foregroundStyle(HomeColor.cta).frame(height: 40, alignment: .top).padding(.leading, 16).padding(.top, 6)
            Text(item.text.isEmpty ? title : item.text).memoryFont(17, .regular, serif: true, italic: true, relativeTo: .body).foregroundStyle(HomeColor.ink)
                .lineLimit(3).padding(.horizontal, 18).padding(.top, 2)
            Spacer(minLength: 12)
            Rectangle().fill(PassportColor.cardLine).frame(height: 1)
            HStack {
                MemoryPlaceLine(item: item, stampWidth: 15, size: 12.5)
                Spacer(minLength: 6)
                if let first = item.tags.first { MemoryTagChip(text: first) }
            }
            .padding(.horizontal, 18).frame(minHeight: 34).padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 172 * u, alignment: .topLeading)
        .background(HomeColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(PassportColor.cardLine, lineWidth: 1))
        .shadow(color: HomeColor.shadow1.opacity(0.08), radius: 8, y: 4)
    }

    private func titleAndMeta(titleSize: CGFloat, textLines: Int, showsTags: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).memoryFont(titleSize, .semibold, serif: true, relativeTo: .title3).foregroundStyle(HomeColor.ink).lineLimit(1)
            MemoryPlaceLine(item: item)
            if !item.text.isEmpty {
                Text(item.text).memoryFont(15, .regular, serif: true, relativeTo: .subheadline).foregroundStyle(HomeColor.sub).lineLimit(textLines).lineSpacing(3)
            }
            if showsTags { MemoryTagRow(tags: item.tags).padding(.top, 4) }
        }
    }

    private var countChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.on.rectangle").font(.system(size: 13, weight: .semibold))
            Text("\(item.photoFilenames.count)").font(.system(size: 12, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(HomeColor.cream).padding(.horizontal, 10).frame(minWidth: 44, minHeight: 26)
        .posterGlass(Capsule())
    }
}

// MARK: - Compact card (Search results, related memories)

/// The compact row of a memory: thumbnail (or a quiet tile with a quote mark), title, place, an excerpt and the date.
struct MemoryCard: View {
    let item: MemoryItem
    var query = ""

    @Environment(\.passport) private var passport

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            thumbnail.frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(DiscoverHighlight.attributed(item.displayTitle(), query: query)).memoryFont(18.5, .semibold, serif: true, relativeTo: .title3)
                    .foregroundStyle(HomeColor.ink).lineLimit(1)
                MemoryPlaceLine(item: item, stampWidth: 15)
                if !item.text.isEmpty {
                    Text(DiscoverHighlight.attributed(item.text, query: query)).memoryFont(13.5, .regular, serif: true, relativeTo: .footnote)
                        .foregroundStyle(HomeColor.sub).lineLimit(2)
                }
                Text(item.effectiveDate.memoryShortDate()).memoryFont(12, .medium, relativeTo: .caption).foregroundStyle(HomeColor.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10).frame(minHeight: 108).contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var thumbnail: some View {
        if let first = item.photoFilenames.first { MemoryPhoto(filename: first, maxPixel: 250, radius: 14) }
        else {
            Text("“").font(.system(size: 40, weight: .semibold, design: .serif)).foregroundStyle(HomeColor.cta)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(PassportColor.quiet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private var spoken: String {
        var parts = [item.displayTitle(), item.effectiveDate.memoryDayLine()]
        if let place = MemoryPlaceLine.spoken(item, catalog: passport.catalog, snapshot: passport.snapshot) { parts.append(place) }
        return parts.joined(separator: ". ") + "."
    }
}

/// The row older screens (Destination detail's "Your memories") already use; it now shows the compact memory card.
struct MemoryRow: View {
    let memory: MemoryEntry

    var body: some View { MemoryCard(item: MemoryItem(memory)) }
}

extension MemoryItem {
    @MainActor
    init(_ entry: MemoryEntry) {
        self.init(id: entry.id, title: entry.title, text: entry.text, eventDate: entry.eventDate, createdAt: entry.createdAt,
                  destinationID: entry.destinationID, stampID: entry.stampID, tripID: entry.tripID, tags: entry.tags,
                  photoFilenames: entry.photoFilenames)
    }
}
