import Foundation

/// Formats values for display. Never concatenate dates or prices in English word order.
nonisolated enum OnboardingFormat {
    /// "26 OCT 2026": formatted from the date, never hardcoded.
    static func stampDate(_ date: Date, locale: Locale = .current, calendar: Calendar = .current, timeZone: TimeZone = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: timeZone)
        style = style.day(.twoDigits).month(.abbreviated).year()
        return date.formatted(style).uppercased(with: locale)
    }

    enum DateStyle: Sendable { case dayMonth, dayMonthYear }

    /// "1 Nov" or "27 Oct 2026" in the person's locale and calendar (day first where the region puts it first, no literal month names).
    /// Issued dates, the reminder and "Plan begins" all come through here; the postmark uses `stampDate`.
    static func date(_ date: Date, _ style: DateStyle, locale: Locale = .current, calendar: Calendar = .current) -> String {
        var format = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        format = format.day().month(.abbreviated)
        if style == .dayMonthYear { format = format.year() }
        return date.formatted(format)
    }

    /// Currency string from a value, in the user's locale.
    static func price(_ amount: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        amount.formatted(.currency(code: currencyCode).locale(locale))
    }
}
