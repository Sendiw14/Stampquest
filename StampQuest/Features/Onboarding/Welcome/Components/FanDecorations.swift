import SwiftUI

/// Four hand-cancelled wavy lines. `progress` 0...1 draws them left to right together.
struct CancellationWaves: View {
    let progress: CGFloat

    var body: some View {
        WaveLines()
            .stroke(WelcomeColor.postmark, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            .frame(width: WelcomeMetrics.wavesFrame.width, height: WelcomeMetrics.wavesFrame.height)
            .mask(alignment: .leading) {
                Rectangle().frame(width: WelcomeMetrics.wavesFrame.width * progress)
            }
            .accessibilityHidden(true)
    }
}

private nonisolated struct WaveLines: Shape {
    static let lines = 4
    static let waves = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing = rect.height / CGFloat(Self.lines)
        let step = rect.width / CGFloat(Self.waves)
        let lift = spacing * 0.42
        for line in 0..<Self.lines {
            let y = spacing * (CGFloat(line) + 0.5)
            path.move(to: CGPoint(x: rect.minX, y: y))
            for wave in 0..<Self.waves {
                let x = rect.minX + step * CGFloat(wave)
                let sign: CGFloat = wave.isMultiple(of: 2) ? -1 : 1
                path.addQuadCurve(to: CGPoint(x: x + step, y: y), control: CGPoint(x: x + step / 2, y: y + sign * lift * 2))
            }
        }
        return path
    }
}

/// An 8-point star that twinkles between a quarter and full strength.
struct Sparkle: View {
    let size: CGFloat
    let opacity: Double

    var body: some View {
        StarShape()
            .fill(WelcomeColor.highlight)
            .frame(width: size, height: size)
            .opacity(opacity)
            .accessibilityHidden(true)
    }
}
