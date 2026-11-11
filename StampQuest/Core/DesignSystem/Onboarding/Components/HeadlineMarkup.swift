import Foundation

/// The headline string with its highlighted words, e.g. "Your {world}, one {stamp} at a time.", split into the
/// pieces the headline lays out. A newline in the string is a line break. Pure.
nonisolated enum HeadlineMarkup {
    enum Kind: Equatable, Sendable {
        case plain
        /// The n-th `{...}` word of the string.
        case highlight(Int)
    }

    struct Token: Equatable, Sendable {
        let text: String
        let kind: Kind
        /// False when the token sits tight against the one before it, like the comma after a frame.
        let spaceBefore: Bool
        /// True when the string breaks the line before this token.
        var lineBreakBefore = false
    }

    /// Parses a string whose highlighted words are marked `**like this**` (a String Catalog markdown value).
    static func parse(markdown text: String) -> [Token]? {
        let parts = text.components(separatedBy: "**")
        guard parts.count.isMultiple(of: 2) == false else { return nil }
        let braces = parts.enumerated().map { $0.offset.isMultiple(of: 2) ? $0.element : "{" + $0.element + "}" }.joined()
        return parse(braces)
    }

    /// Words in `text` and `{highlighted}` words. Returns nil when the braces do not pair up or nothing is highlighted,
    /// so the caller can fall back to plain text.
    static func parse(_ text: String) -> [Token]? {
        var tokens: [Token] = []
        var highlights = 0
        var word = ""
        var wordKind = Kind.plain
        var pendingSpace = false
        var pendingBreak = false
        var inside = false

        func flush() {
            guard !word.isEmpty else { return }
            tokens.append(Token(text: word, kind: wordKind, spaceBefore: pendingSpace && !tokens.isEmpty && !pendingBreak,
                                lineBreakBefore: pendingBreak && !tokens.isEmpty))
            word = ""
            pendingSpace = false
            pendingBreak = false
        }

        for character in text {
            switch character {
            case "{":
                guard !inside else { return nil }
                flush()
                inside = true
                wordKind = .highlight(highlights)
                highlights += 1
            case "}":
                guard inside else { return nil }
                flush()
                inside = false
                wordKind = .plain
            case " ", "\n":
                if inside { word.append(character) } else {
                    flush()
                    pendingSpace = true
                    if character == "\n" { pendingBreak = true }
                }
            default:
                word.append(character)
            }
        }
        flush()
        guard !inside, highlights > 0 else { return nil }
        return tokens
    }

    /// The same string without braces, for VoiceOver and the plain-text fallback.
    static func plainText(_ text: String) -> String {
        text.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "").replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
