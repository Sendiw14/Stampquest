import SwiftUI

/// Parses the SVG path commands used by the artwork (M L H V C Q T A Z, absolute and relative), so illustrations can be
/// ported 1:1 from the design coordinates without an SVG dependency.
nonisolated enum SVGPath {
    static func path(_ d: String) -> Path {
        var scanner = Cursor(d.replacingOccurrences(of: "\u{2212}", with: "-"))
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastQuadControl: CGPoint?
        var command: Character = "M"

        while let token = scanner.next() {
            if case .command(let c) = token {
                command = c
                if c == "Z" || c == "z" { path.closeSubpath(); current = subpathStart }
                continue
            }
            scanner.rewind()
            let relative = command.isLowercase
            let origin = relative ? current : .zero
            func point() -> CGPoint { let p = scanner.point(); return CGPoint(x: origin.x + p.x, y: origin.y + p.y) }
            var quadControl: CGPoint?
            switch Character(command.uppercased()) {
            case "M":
                let p = point(); path.move(to: p); current = p; subpathStart = p
                command = relative ? "l" : "L"
            case "L": let p = point(); path.addLine(to: p); current = p
            case "H": current.x = origin.x + scanner.number(); path.addLine(to: current)
            case "V": current.y = origin.y + scanner.number(); path.addLine(to: current)
            case "C":
                let c1 = point(), c2 = point(), p = point()
                path.addCurve(to: p, control1: c1, control2: c2); current = p
            case "Q":
                let c = point(), p = point()
                path.addQuadCurve(to: p, control: c); current = p; quadControl = c
            case "T":
                let c = lastQuadControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let p = point()
                path.addQuadCurve(to: p, control: c); current = p; quadControl = c
            case "A":
                let rx = scanner.number(), ry = scanner.number(), rotation = scanner.number()
                let large = scanner.number() != 0, sweep = scanner.number() != 0
                let p = point()
                addArc(&path, from: current, rx: rx, ry: ry, rotation: rotation, large: large, sweep: sweep, to: p)
                current = p
            default:
                preconditionFailure("Unsupported SVG path command \(command)")
            }
            lastQuadControl = quadControl
        }
        return path
    }

    /// SVG endpoint arc to cubic Beziers (SVG 1.1 appendix F.6).
    static func addArc(_ path: inout Path, from p0: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat,
                       large: Bool, sweep: Bool, to p1: CGPoint) {
        var rx = abs(rxIn), ry = abs(ryIn)
        guard rx > 0, ry > 0, p0 != p1 else { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosPhi * dx + sinPhi * dy
        let y1 = -sinPhi * dx + cosPhi * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { let s = lambda.squareRoot(); rx *= s; ry *= s }
        let numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coefficient = (large == sweep ? -1.0 : 1.0) * max(0, numerator / denominator).squareRoot()
        let cxp = coefficient * rx * y1 / ry
        let cyp = -coefficient * ry * x1 / rx
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let length = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
            var a = acos(max(-1, min(1, dot / length)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var delta = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(segments)
        let t = 4.0 / 3.0 * tan(step / 4)
        func point(_ a: CGFloat, _ dx: CGFloat = 0, _ dy: CGFloat = 0) -> CGPoint {
            let x = rx * (cos(a) + dx), y = ry * (sin(a) + dy)
            return CGPoint(x: cosPhi * x - sinPhi * y + cx, y: sinPhi * x + cosPhi * y + cy)
        }
        var a = theta1
        for _ in 0..<segments {
            let b = a + step
            path.addCurve(to: point(b),
                          control1: point(a, -t * sin(a), t * cos(a)),
                          control2: point(b, t * sin(b), -t * cos(b)))
            a = b
        }
    }

    private enum Token { case command(Character), number }

    private struct Cursor {
        private let chars: [Character]
        private var index = 0
        private var tokenStart = 0

        init(_ string: String) { chars = Array(string) }

        mutating func next() -> Token? {
            skipSeparators()
            guard index < chars.count else { return nil }
            tokenStart = index
            let c = chars[index]
            if c.isLetter { index += 1; return .command(c) }
            return .number
        }

        mutating func rewind() { index = tokenStart }

        mutating func number() -> CGFloat {
            skipSeparators()
            var text = ""
            if index < chars.count, chars[index] == "-" || chars[index] == "+" { text.append(chars[index]); index += 1 }
            var seenDot = false
            while index < chars.count {
                let c = chars[index]
                if c.isNumber { text.append(c) } else if c == ".", !seenDot { seenDot = true; text.append(c) } else { break }
                index += 1
            }
            return CGFloat(Double(text) ?? 0)
        }

        mutating func point() -> CGPoint { let x = number(); let y = number(); return CGPoint(x: x, y: y) }

        private mutating func skipSeparators() {
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index] == "\n" { index += 1 }
        }
    }
}
