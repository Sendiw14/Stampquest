import Foundation

/// What the "Your passport is ready" screen says, built from saved state only: the subtitle, the page's text and the three
/// summary rows. Pure, so it needs no UI to test. Nothing here is a sample; empty values fall back to honest wording.
struct ReadyContent: Equatable {
    struct Row: Equatable {
        enum Status: Equatable { case done, off }
        let status: Status
        let text: String
    }

    /// The holder's name as saved, trimmed; nil when empty.
    let holderName: String?
    let stampCount: Int
    let firstStamp: StarterStamp?
    let subtitle: String
    let issuedText: String
    let rows: [Row]
    /// The stamp's city in capitals and the date printed on its postmark.
    let postmarkTop: String
    let postmarkDate: String

    init(holderName: String, cover: CoverStyle, isEntitled: Bool = true, firstStamp: (stamp: StarterStamp, collectedAt: Date)?,
         verification: VerificationChoice, authorization: LocationAuthorization, issuedAt: Date, now: Date, calendar: Calendar = .current,
         locale: Locale = .current) {
        let name = CoverName.committed(holderName)
        self.holderName = name.isEmpty ? nil : name
        stampCount = firstStamp == nil ? 0 : 1
        self.firstStamp = firstStamp?.stamp
        issuedText = Self.format(issuedAt, calendar: calendar, locale: locale)
        postmarkTop = firstStamp?.stamp.destination.label ?? ""
        postmarkDate = firstStamp.map { OnboardingFormat.stampDate($0.collectedAt, locale: locale, calendar: calendar) } ?? ""

        if firstStamp == nil {
            subtitle = String(localized: "onboarding.ready.subtitle.noStamp")
        } else if let first = name.split(whereSeparator: \.isWhitespace).first {
            subtitle = String(localized: "onboarding.ready.subtitle \(String(first))")
        } else {
            subtitle = String(localized: "onboarding.ready.subtitle.noName")
        }

        let resolved = CoverEntitlementResolver.effectiveCover(selected: cover, isEntitled: isEntitled)
        let coverName = Bundle.main.localizedString(forKey: resolved.nameKey, value: nil, table: nil)
        let chosenName = Bundle.main.localizedString(forKey: cover.nameKey, value: nil, table: nil)
        let coverText = resolved != cover ? String(localized: "onboarding.ready.row.cover.preview \(coverName) \(chosenName)")
            : name.isEmpty ? String(localized: "onboarding.ready.row.cover \(coverName)") : String(localized: "onboarding.ready.row.cover.name \(coverName)")
        var rows = [Row(status: .done, text: coverText)]
        if let firstStamp {
            let city = firstStamp.stamp.destination.name
            let sameDay = calendar.isDate(firstStamp.collectedAt, inSameDayAs: now)
            rows.append(Row(status: .done, text: sameDay ? String(localized: "onboarding.ready.row.stamp.today \(city)")
                                                         : String(localized: "onboarding.ready.row.stamp.date \(city) \(Self.format(firstStamp.collectedAt, calendar: calendar, locale: locale))")))
        } else {
            rows.append(Row(status: .off, text: String(localized: "onboarding.ready.row.stamp.none")))
        }
        let verifiedOn = verification == .enabled && authorization == .authorized
        rows.append(Row(status: verifiedOn ? .done : .off,
                        text: String(localized: verifiedOn ? "onboarding.ready.row.verified.on" : "onboarding.ready.row.verified.off")))
        self.rows = rows
    }

    /// "27 Oct 2026": day, abbreviated month and year in the person's locale.
    static func format(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        OnboardingFormat.date(date, .dayMonthYear, locale: locale, calendar: calendar)
    }
}
