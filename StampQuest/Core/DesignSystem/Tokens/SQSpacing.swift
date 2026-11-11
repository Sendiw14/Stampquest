import SwiftUI

/// Spacing scale on a 4-pt base. Use these instead of literal numbers.
nonisolated enum SQSpace {
    /// Tight icon-to-label spacing.
    static let xxs: CGFloat = 4
    /// Inline spacing between related items.
    static let xs: CGFloat = 8
    /// Standard component spacing.
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    /// Section-internal rhythm.
    static let lg: CGFloat = 24
    /// Between sections.
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    /// Screen-edge margin.
    static let screenMargin: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let gridGutter: CGFloat = 16
    /// Extra bottom inset so content clears the tab bar and home indicator.
    static let bottomInset: CGFloat = 24
}

/// Corner radii. Stamps do not use these: they have their own perforated outline.
nonisolated enum SQRadius {
    /// Chips, small controls.
    static let small: CGFloat = 8
    /// Cards and inputs.
    static let medium: CGFloat = 14
    /// Large editorial surfaces.
    static let large: CGFloat = 22
    /// Hero artwork.
    static let hero: CGFloat = 28
}

/// Minimum interactive size (HIG).
nonisolated enum SQHit {
    static let minimum: CGFloat = 44
}
