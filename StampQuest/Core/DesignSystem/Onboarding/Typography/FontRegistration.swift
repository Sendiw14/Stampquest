import UIKit
import OSLog

/// The fonts are registered through `UIAppFonts` in Info.plist. This checks they actually resolve,
/// so a wrong PostScript name fails loudly in DEBUG instead of silently falling back to the system font.
enum FontRegistration {
    private static let log = Logger(subsystem: "app.stampquest.ios", category: "fonts")

    /// Names in `OBFontName.all` that `UIFont(name:size:)` cannot resolve.
    static func unresolvedNames() -> [String] {
        OBFontName.all.filter { UIFont(name: $0, size: 12) == nil }
    }

    /// Everything registered for the family, for diagnostics.
    static func availableNames() -> [String: [String]] {
        ["Newsreader"].reduce(into: [:]) { $0[$1] = UIFont.fontNames(forFamilyName: $1) }
    }

    /// DEBUG only: asserts every font resolves and logs what is registered when one does not.
    static func verifyInDebug() {
        #if DEBUG
        let missing = unresolvedNames()
        guard !missing.isEmpty else { return }
        log.fault("Unresolved fonts: \(missing.joined(separator: ", "), privacy: .public). Registered: \(String(describing: availableNames()), privacy: .public)")
        assertionFailure("Unresolved fonts: \(missing)")
        #endif
    }
}
