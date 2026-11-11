import Foundation

/// The optional name printed on the cover (onboarding prompt 05 section 5 and 8).
nonisolated enum CoverName {
    /// Grapheme clusters, so emoji and accents are safe.
    static let maxLength = 24
    /// Number of characters up to which the name keeps its full size.
    static let fullSizeLimit = 14

    /// Live while typing: collapse runs of whitespace to one space, drop leading whitespace, cap at 24 characters.
    /// A single trailing space is kept so the next word can be typed.
    static func sanitizeWhileTyping(_ raw: String) -> String {
        var result: [Character] = []
        for character in raw {
            if character.unicodeScalars.allSatisfy({ CharacterSet.controlCharacters.contains($0) }) && !character.isWhitespace { continue }
            if character.isWhitespace {
                if result.isEmpty || result.last == " " { continue }
                result.append(" ")
            } else {
                result.append(character)
            }
            if result.count >= maxLength { break }
        }
        return String(result.prefix(maxLength))
    }

    /// On commit: sanitized and trimmed. A name of only spaces is empty.
    static func committed(_ raw: String) -> String {
        sanitizeWhileTyping(raw).trimmingCharacters(in: .whitespaces)
    }

    /// Font size in cover units: full size up to 14 characters, then shrinking, never below 3.8.
    static func sizeUnits(characterCount n: Int) -> Double {
        n <= fullSizeLimit ? 6.6 : max(3.8, 6.6 * Double(fullSizeLimit) / Double(n))
    }
}
