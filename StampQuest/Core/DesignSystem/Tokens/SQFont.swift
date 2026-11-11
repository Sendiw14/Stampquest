import SwiftUI

/// Semantic type scale. Everything is built on Dynamic Type text styles so it
/// scales with the user's settings. Serif (New York) is reserved for editorial
/// and destination moments; SF handles interface chrome and information.
enum SQFont {
    /// Hero headings on Home, Welcome and detail screens.
    static let display = Font.system(.largeTitle, design: .serif).weight(.semibold)
    /// Screen titles when a custom title is shown.
    static let title = Font.system(.title, design: .serif).weight(.semibold)
    /// Destination names on cards and detail.
    static let destination = Font.system(.title2, design: .serif).weight(.semibold)
    /// Section headings.
    static let section = Font.system(.title3, design: .serif).weight(.semibold)
    /// Card titles, row titles.
    static let headline = Font.system(.headline, design: .default)
    static let body = Font.system(.body, design: .default)
    /// Editorial body copy.
    static let story = Font.system(.body, design: .serif)
    static let subheadline = Font.system(.subheadline, design: .default)
    static let meta = Font.system(.footnote, design: .default)
    static let caption = Font.system(.caption, design: .default)
    /// Small labels, e.g. chip text. Never carries essential information alone.
    static let label = Font.system(.caption, design: .default).weight(.semibold)
    /// Numbers that should align in progress and statistics.
    static let numeral = Font.system(.title, design: .rounded).weight(.semibold).monospacedDigit()
    static let numeralLarge = Font.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit()
    /// Archival micro-detail (postmark, edition).
    static let postmark = Font.system(.caption2, design: .monospaced).weight(.medium)
}

extension View {
    /// Applies tracking suited to small caps-style labels without shouting.
    func sqEyebrow() -> some View {
        self
            .font(SQFont.label)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(SQColor.textSecondary)
    }
}
