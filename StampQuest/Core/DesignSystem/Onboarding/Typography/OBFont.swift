import Foundation

/// PostScript names of the bundled serif (Newsreader, SIL OFL, variable TTFs), used for stamp captions.
nonisolated enum OBFontName {
    static let newsreaderSemiBold = "NewsreaderRoman-SemiBold"
    static let newsreaderItalic = "Newsreader16pt-Italic"
    static let newsreaderItalicMedium = "NewsreaderItalic-Medium"

    static let all = [newsreaderSemiBold, newsreaderItalic, newsreaderItalicMedium]
}
