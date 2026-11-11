import Foundation

extension HeadlineMarkup {
    /// The intro beat that reveals the token at `index`: words before the first highlight, the highlighted words, the
    /// punctuation that follows one, the words between two highlights and the words after the last.
    static func beat(forTokenAt index: Int, in tokens: [Token]) -> WelcomeIntroTimeline.Beat {
        let token = tokens[index]
        if case .highlight(let n) = token.kind { return n == 0 ? .world : .stampWord }
        guard let firstHighlight = tokens.firstIndex(where: { $0.kind != .plain }) else { return .your }
        if index < firstHighlight { return .your }
        if !token.spaceBefore { return .comma }
        let lastHighlight = tokens.lastIndex(where: { $0.kind != .plain }) ?? firstHighlight
        return index > lastHighlight ? .atATime : .one
    }
}
