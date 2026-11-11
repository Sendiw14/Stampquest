import SwiftUI

/// "Start ⟦free⟧,\nupgrade later": ⟦ ⟧ marks the stamp-word. A locale without the markers gets plain heavy text. Pure.
nonisolated enum ExitTitleParts {
    struct Parts: Equatable {
        let before: String
        let word: String
        let after: String
        let second: String
    }

    static func parse(_ text: String) -> Parts? {
        let lines = text.components(separatedBy: "\n")
        guard let first = lines.first, let open = first.firstIndex(of: "⟦"), let close = first.firstIndex(of: "⟧"), open < close else { return nil }
        return Parts(before: String(first[..<open]).trimmingCharacters(in: .whitespaces), word: String(first[first.index(after: open)..<close]),
                     after: String(first[first.index(after: close)...]), second: lines.dropFirst().joined(separator: " "))
    }

    static func plain(_ text: String) -> String { text.replacingOccurrences(of: "⟦", with: "").replacingOccurrences(of: "⟧", with: "") }
}

/// The two-line title with the "free" stamp: 28 pt heavy, tracking -0.04 em, ink.
struct ExitTitle: View {
    let player: BeatPlayer<ExitBeat>
    let reduceMotion: Bool

    @ScaledMetric(relativeTo: .title) private var size = 28.0

    var body: some View {
        let text = String(localized: "exit.title")
        Group {
            if let parts = ExitTitleParts.parse(text) { stamped(parts) } else {
                Text(verbatim: ExitTitleParts.plain(text)).font(.system(size: size, weight: .heavy)).tracking(-0.04 * size)
                    .foregroundStyle(OnbColor.inkPrimary).exitBeat(.start, player, reduceMotion: reduceMotion)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("exit.a11y.title"))
        .accessibilityAddTraits(.isHeader)
    }

    private func stamped(_ parts: ExitTitleParts.Parts) -> some View {
        let unit = size / 28
        let style = StampWordStyle(fill: OnbColor.ctaFill, ink: OnbColor.ctaLabel, shadow: OnbColor.shadowSoft, rotation: -3, height: 42 * unit,
                                   horizontalPadding: 13 * unit, pitch: 9, inset: 7 * unit, insetRadius: 2, shadowOffset: 10)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                heavy(parts.before).exitBeat(.start, player, reduceMotion: reduceMotion)
                StampWordFrame(word: parts.word, size: size, style: style)
                    .modifier(StampInEffect(played: player.has(.word), instant: reduceMotion))
                    .padding(.leading, -6)
                    .opacity(reduceMotion && !player.has(.word) ? 0 : 1)
                heavy(parts.after).padding(.leading, -8).exitBeat(.comma, player, reduceMotion: reduceMotion)
            }
            .frame(minHeight: 46 * unit)
            heavy(parts.second).exitBeat(.upgrade, player, reduceMotion: reduceMotion)
        }
    }

    private func heavy(_ text: String) -> some View {
        Text(verbatim: text).font(.system(size: size, weight: .heavy)).tracking(-0.04 * size).foregroundStyle(OnbColor.inkPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
