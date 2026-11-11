// Generates the StampQuest app icon (1024 × 1024 PNG, no transparency).
//
//   swift Tools/make_icon.swift StampQuest/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// The icon is drawn entirely in code from the same ideas as the in-app stamps:
// perforated paper, a tiny sunlit landscape, and a cancellation postmark.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("no context") }

func gradient(_ colors: [UInt32], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors.map { rgb($0) } as CFArray, locations: locations)!
}

// Background: warm terracotta.
ctx.drawLinearGradient(gradient([0xC77A52, 0x8F4A2D]), start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: CGFloat(size), y: 0), options: [])

/// A perforated stamp outline centred on the origin.
func stampPath(width w: CGFloat, height h: CGFloat, holes: Int) -> CGPath {
    let path = CGMutablePath()
    let pitch = w / CGFloat(holes)
    let nx = holes
    let ny = Int((h / pitch).rounded())
    let px = w / CGFloat(nx), py = h / CGFloat(ny)
    let r = min(px, py) * 0.30
    let k: CGFloat = 0.5523
    let origin = CGPoint(x: -w / 2, y: -h / 2)
    path.move(to: origin)
    func edge(from start: CGPoint, d: CGVector, n: CGVector, count: Int, pitch: CGFloat) {
        for i in 0..<count {
            let t = (CGFloat(i) + 0.5) * pitch
            let c = CGPoint(x: start.x + d.dx * t, y: start.y + d.dy * t)
            let a = CGPoint(x: c.x - d.dx * r, y: c.y - d.dy * r)
            let peak = CGPoint(x: c.x + n.dx * r, y: c.y + n.dy * r)
            let b = CGPoint(x: c.x + d.dx * r, y: c.y + d.dy * r)
            path.addLine(to: a)
            path.addCurve(to: peak, control1: CGPoint(x: a.x + n.dx * r * k, y: a.y + n.dy * r * k),
                          control2: CGPoint(x: peak.x - d.dx * r * k, y: peak.y - d.dy * r * k))
            path.addCurve(to: b, control1: CGPoint(x: peak.x + d.dx * r * k, y: peak.y + d.dy * r * k),
                          control2: CGPoint(x: b.x + n.dx * r * k, y: b.y + n.dy * r * k))
        }
        path.addLine(to: CGPoint(x: start.x + d.dx * pitch * CGFloat(count), y: start.y + d.dy * pitch * CGFloat(count)))
    }
    edge(from: CGPoint(x: -w / 2, y: -h / 2), d: CGVector(dx: 1, dy: 0), n: CGVector(dx: 0, dy: 1), count: nx, pitch: px)
    edge(from: CGPoint(x: w / 2, y: -h / 2), d: CGVector(dx: 0, dy: 1), n: CGVector(dx: -1, dy: 0), count: ny, pitch: py)
    edge(from: CGPoint(x: w / 2, y: h / 2), d: CGVector(dx: -1, dy: 0), n: CGVector(dx: 0, dy: -1), count: nx, pitch: px)
    edge(from: CGPoint(x: -w / 2, y: h / 2), d: CGVector(dx: 0, dy: -1), n: CGVector(dx: 1, dy: 0), count: ny, pitch: py)
    path.closeSubpath()
    return path
}

ctx.saveGState()
ctx.translateBy(x: 512, y: 512)
ctx.rotate(by: -0.10)

let sw: CGFloat = 600, sh: CGFloat = 750
// Shadow + paper
ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 50, color: rgb(0x000000, 0.35))
ctx.addPath(stampPath(width: sw, height: sh, holes: 10))
ctx.setFillColor(rgb(0xFBF6EA))
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Illustration panel
let inset: CGFloat = 54
let art = CGRect(x: -sw / 2 + inset, y: -sh / 2 + inset, width: sw - inset * 2, height: sh - inset * 2)
ctx.saveGState()
ctx.clip(to: art)
ctx.drawLinearGradient(gradient([0xF6D9A8, 0xEDA662]), start: CGPoint(x: 0, y: art.minY), end: CGPoint(x: 0, y: art.maxY), options: [])
// Sun
let sunCenter = CGPoint(x: art.midX + 70, y: art.midY + 150)
ctx.drawRadialGradient(gradient([0xFFF3C9, 0xFFF3C9, 0xF8C77A], [0, 0.55, 1]), startCenter: sunCenter, startRadius: 0,
                       endCenter: sunCenter, endRadius: 120, options: [])
// Hills
func hill(_ pts: [(CGFloat, CGFloat)], color: UInt32) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: art.minX, y: art.minY))
    p.addLine(to: CGPoint(x: art.minX, y: art.minY + pts[0].1))
    for i in 0..<pts.count {
        let pt = CGPoint(x: art.minX + pts[i].0, y: art.minY + pts[i].1)
        if i == 0 { p.addLine(to: pt) } else {
            let prev = CGPoint(x: art.minX + pts[i - 1].0, y: art.minY + pts[i - 1].1)
            p.addQuadCurve(to: pt, control: CGPoint(x: (prev.x + pt.x) / 2, y: max(prev.y, pt.y) + 40))
        }
    }
    p.addLine(to: CGPoint(x: art.maxX, y: art.minY))
    p.closeSubpath()
    ctx.addPath(p); ctx.setFillColor(rgb(color)); ctx.fillPath()
}
hill([(0, 250), (180, 330), (330, 270), (492, 310)], color: 0x8C9A6E)
hill([(0, 160), (150, 210), (310, 150), (492, 190)], color: 0x52705A)
hill([(0, 70), (200, 110), (492, 60)], color: 0x3C5A48)
// Compass star in the sky
let star = CGMutablePath()
let sc = CGPoint(x: art.minX + 110, y: art.maxY - 120)
for i in 0..<16 {
    let radius: CGFloat = i % 4 == 0 ? 62 : (i % 2 == 0 ? 44 : 15)
    let a = CGFloat(i) * .pi / 8 - .pi / 2
    let p = CGPoint(x: sc.x + cos(a) * radius, y: sc.y + sin(a) * radius)
    if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
}
star.closeSubpath()
ctx.addPath(star); ctx.setFillColor(rgb(0xA05A38, 0.9)); ctx.fillPath()
ctx.restoreGState()
// Keyline
ctx.setStrokeColor(rgb(0xFBF6EA)); ctx.setLineWidth(8)
ctx.stroke(art.insetBy(dx: 0, dy: 0))
ctx.restoreGState()

// Postmark overlapping the lower-right corner
ctx.saveGState()
ctx.translateBy(x: 512 + 170, y: 512 - 250)
ctx.rotate(by: 0.16)
let ink = rgb(0x2B2D2A, 0.78)
ctx.setStrokeColor(ink)
ctx.setLineWidth(16)
ctx.strokeEllipse(in: CGRect(x: -125, y: -125, width: 250, height: 250))
ctx.setLineWidth(7)
ctx.strokeEllipse(in: CGRect(x: -92, y: -92, width: 184, height: 184))
// Wavy cancellation lines
ctx.setLineWidth(11)
ctx.setLineCap(.round)
for i in 0..<4 {
    let y = CGFloat(i - 1) * 40 - 20
    let p = CGMutablePath()
    var x: CGFloat = -420
    p.move(to: CGPoint(x: x, y: y))
    while x < -110 { x += 6; p.addLine(to: CGPoint(x: x, y: y + sin((x + 420) * 0.07) * 10)) }
    ctx.addPath(p); ctx.strokePath()
}
// Centre mark: a small check, honest to "collected"
ctx.setLineWidth(18)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: -46, y: -2)); ctx.addLine(to: CGPoint(x: -12, y: -38)); ctx.addLine(to: CGPoint(x: 50, y: 38))
ctx.strokePath()
ctx.restoreGState()

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("no image") }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("write failed") }
print("wrote \(outPath)")
