import SwiftUI

/// Everything a motif needs to draw itself into the shared scene.
nonisolated struct ArtSceneContext {
    let pen: ArtPen
    let c: ArtColors
    /// y of the ground / waterline in art space.
    let g: Double
    let variant: Int
    let seed: UInt64
    let sunX: Double
    let sunY: Double

    func rng(_ salt: UInt64 = 0) -> ArtRandom { ArtRandom(seed: seed &+ salt &* 0x9E37) }

    /// Draws `body` mirrored below the waterline, faded, as a reflection.
    func mirror(opacity: Double = 0.30, _ body: (ArtPen) -> Void) {
        var base = pen.ctx
        base.opacity = opacity
        base.clip(to: Path(CGRect(x: 0, y: g, width: 100, height: ArtScene.height - g)))
        base.drawLayer { layer in
            layer.translateBy(x: 0, y: 2 * g)
            layer.scaleBy(x: 1, y: -1)
            body(ArtPen(ctx: layer))
        }
    }
}

nonisolated enum ArtForeground: Sendable { case land, water, none }

nonisolated struct ArtTraits: Sendable {
    var horizon: Double = 92
    var foreground: ArtForeground = .land
    var hills: Int = 1
}

nonisolated enum ArtScene {
    static let width: Double = 100
    static let height: Double = 130

    static func traits(for motif: ArtMotif, variant: Int = 0) -> ArtTraits {
        switch motif {
        case .fuji, .lakeReflection, .fjord:
            ArtTraits(horizon: 92, foreground: .water, hills: 0)
        case .towerBridge, .operaHouse, .maidenTower, .halong, .lighthouseFort, .palmBeach,
             .suspensionBridge, .canals, .parliament, .stoneBridge, .marinaBay, .tajMahal,
             .angkor, .pagoda, .prang, .towerFort, .alpineVillage, .statueOfLiberty:
            ArtTraits(horizon: 92, foreground: .water, hills: motif == .alpineVillage ? 0 : 1)
        case .hillTown:
            ArtTraits(horizon: 94, foreground: variant == 2 ? .land : .water, hills: 0)
        case .waterfall:
            ArtTraits(horizon: 92, foreground: variant == 1 ? .water : .land, hills: 1)
        case .peaks, .machuPicchu, .sigiriya, .greatWall, .cappadocia, .meteora, .geyser, .christRedeemer:
            ArtTraits(horizon: 94, foreground: .land, hills: 2)
        case .canyon, .monolith, .savanna, .petra:
            ArtTraits(horizon: 90, foreground: .land, hills: 1)
        default:
            ArtTraits(horizon: 92, foreground: .land, hills: 1)
        }
    }

    /// Paints a full illustration into `context` for a canvas of `size`.
    static func draw(spec: ArtworkSpec, seed: UInt64, in context: inout GraphicsContext, size: CGSize) {
        guard let c = ArtColors(palette: spec.palette) else {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray))
            return
        }
        let scale = max(size.width / width, size.height / height)
        let ox = (size.width - width * scale) / 2
        let oy = (size.height - height * scale) / 2
        context.clip(to: Path(CGRect(origin: .zero, size: size)))
        context.translateBy(x: ox, y: oy)
        context.scaleBy(x: scale, y: scale)

        let traits = traits(for: spec.motif, variant: spec.variant)
        let g = traits.horizon
        let sunX = spec.sunX ?? 72
        let sunY = spec.sunY ?? 34
        let sunR = spec.sunRadius ?? 9
        var rng = ArtRandom(seed: seed)

        // Sky
        let skyRect = Path(CGRect(x: -2, y: -2, width: width + 4, height: height + 4))
        context.fill(skyRect, with: .linearGradient(
            Gradient(colors: [c.skyTop.color, c.skyBottom.color]),
            startPoint: pt(0, 0), endPoint: pt(0, g)))

        if spec.night { drawStars(&context, c: c, rng: &rng, horizon: g) }
        if spec.aurora { drawAurora(&context, rng: &rng) }
        drawCelestial(&context, c: c, x: sunX, y: sunY, r: sunR, night: spec.night)
        drawClouds(&context, c: c, amount: spec.clouds, night: spec.night, rng: &rng, horizon: g)
        drawHills(&context, c: c, count: traits.hills, rng: &rng, horizon: g)
        drawHaze(&context, c: c, horizon: g)

        switch traits.foreground {
        case .land: drawLand(&context, c: c, rng: &rng, horizon: g)
        case .water: drawWater(&context, c: c, rng: &rng, horizon: g, sunX: sunX, sunR: sunR, sunVisible: sunY < g)
        case .none: break
        }

        context.drawLayer { layer in
            let scene = ArtSceneContext(pen: ArtPen(ctx: layer), c: c, g: g, variant: spec.variant,
                                        seed: seed, sunX: sunX, sunY: sunY)
            ArtMotifs.draw(spec.motif, scene)
        }
    }

    // MARK: Layers

    private static func drawStars(_ ctx: inout GraphicsContext, c: ArtColors, rng: inout ArtRandom, horizon: Double) {
        let starColor = c.sun.lightened(0.5)
        for _ in 0..<46 {
            let x = rng.range(1, 99), y = rng.range(2, horizon * 0.62)
            let r = rng.range(0.22, 0.65)
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(starColor.color(opacity: rng.range(0.35, 1))))
        }
    }

    private static func drawAurora(_ ctx: inout GraphicsContext, rng: inout ArtRandom) {
        let colors: [RGB] = [RGB(r: 0.35, g: 0.92, b: 0.69), RGB(r: 0.47, g: 0.70, b: 1.0), RGB(r: 0.69, g: 0.49, b: 1.0)]
        for (k, col) in colors.enumerated() {
            let phase = rng.range(0, 6)
            let base = 20 + Double(k) * 9
            var p = Path()
            p.move(to: pt(-2, base + 40))
            var x = -2.0
            while x <= 102 {
                p.addLine(to: pt(x, base + 7 * sin(x * 0.085 + phase)))
                x += 4
            }
            p.addLine(to: pt(102, base + 40))
            p.closeSubpath()
            ctx.fill(p, with: .linearGradient(
                Gradient(stops: [.init(color: col.color(opacity: 0.0), location: 0),
                                 .init(color: col.color(opacity: 0.55), location: 0.22),
                                 .init(color: col.color(opacity: 0.0), location: 1)]),
                startPoint: pt(0, base - 8), endPoint: pt(0, base + 40)))
        }
    }

    private static func drawCelestial(_ ctx: inout GraphicsContext, c: ArtColors, x: Double, y: Double, r: Double, night: Bool) {
        guard y < 100 else { return }
        let halo = CGRect(x: x - r * 3.2, y: y - r * 3.2, width: r * 6.4, height: r * 6.4)
        ctx.fill(Path(ellipseIn: halo), with: .radialGradient(
            Gradient(colors: [c.sun.color(opacity: night ? 0.28 : 0.5), c.sun.color(opacity: 0)]),
            center: pt(x, y), startRadius: r * 0.8, endRadius: r * 3.2))
        let disc = night ? c.sun.lightened(0.35) : c.sun
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(disc.color))
        if night {
            // A few craters so the moon reads as a moon.
            ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.45, y: y - r * 0.2, width: r * 0.5, height: r * 0.5)),
                     with: .color(disc.darkened(0.08).color(opacity: 0.6)))
            ctx.fill(Path(ellipseIn: CGRect(x: x + r * 0.1, y: y + r * 0.25, width: r * 0.35, height: r * 0.35)),
                     with: .color(disc.darkened(0.08).color(opacity: 0.5)))
        }
    }

    private static func drawClouds(_ ctx: inout GraphicsContext, c: ArtColors, amount: Double, night: Bool,
                                   rng: inout ArtRandom, horizon: Double) {
        let n = Int((amount * 5).rounded())
        guard n > 0 else { return }
        let col = c.skyTop.mixed(.white, night ? 0.25 : 0.78)
        let alpha = night ? 0.22 : 0.5
        for _ in 0..<n {
            let cx = rng.range(4, 96), cy = rng.range(10, horizon * 0.5), w = rng.range(14, 26)
            for (dx, dy, rx, ry) in [(0.0, 0.0, 0.5, 0.14), (-0.24, -0.06, 0.27, 0.14), (0.2, -0.05, 0.3, 0.15)] {
                ctx.fill(Path(ellipseIn: CGRect(x: cx + dx * w - rx * w, y: cy + dy * w - ry * w,
                                                width: rx * w * 2, height: ry * w * 2)),
                         with: .color(col.color(opacity: alpha)))
            }
        }
    }

    private static func drawHills(_ ctx: inout GraphicsContext, c: ArtColors, count: Int,
                                  rng: inout ArtRandom, horizon: Double) {
        guard count > 0 else { return }
        for i in 0..<count {
            let base = horizon - 7 - Double(count - 1 - i) * 8
            let amp = rng.range(5, 10)
            let phase = rng.range(0, 6.28)
            let freq = rng.range(0.05, 0.1)
            var pts: [(Double, Double)] = []
            var x = -4.0
            while x <= 104 {
                pts.append((x, base - amp * (0.5 + 0.5 * sin(x * freq + phase)) - rng.range(0, 2.5)))
                x += 12
            }
            let t = Double(i) / Double(max(count, 1))
            ctx.fill(Path.ridge(points: pts, baseY: horizon + 2),
                     with: .color(c.hillFar.mixed(c.hillNear, t).color))
        }
    }

    private static func drawHaze(_ ctx: inout GraphicsContext, c: ArtColors, horizon: Double) {
        let rect = Path(CGRect(x: 0, y: horizon - 16, width: 100, height: 18))
        ctx.fill(rect, with: .linearGradient(
            Gradient(colors: [c.haze.color(opacity: 0), c.haze.color(opacity: 0.5)]),
            startPoint: pt(0, horizon - 16), endPoint: pt(0, horizon + 1)))
    }

    private static func drawLand(_ ctx: inout GraphicsContext, c: ArtColors, rng: inout ArtRandom, horizon: Double) {
        let rect = Path(CGRect(x: -2, y: horizon, width: 104, height: height - horizon + 2))
        ctx.fill(rect, with: .linearGradient(
            Gradient(colors: [c.ground.mixed(c.skyBottom, 0.12).color, c.ground.darkened(0.2).color]),
            startPoint: pt(0, horizon), endPoint: pt(0, height)))
        for i in 0..<18 {
            let y = horizon + 3 + Double(i) * (height - horizon - 4) / 18
            let x = rng.range(-4, 90), len = rng.range(8, 26)
            let dark = i % 2 == 0
            ctx.fill(Path(CGRect(x: x, y: y, width: len, height: 0.6)),
                     with: .color((dark ? c.ground.darkened(0.45) : c.ground.lightened(0.4)).color(opacity: dark ? 0.2 : 0.14)))
        }
    }

    private static func drawWater(_ ctx: inout GraphicsContext, c: ArtColors, rng: inout ArtRandom, horizon: Double,
                                  sunX: Double, sunR: Double, sunVisible: Bool) {
        let rect = Path(CGRect(x: -2, y: horizon, width: 104, height: height - horizon + 2))
        ctx.fill(rect, with: .linearGradient(
            Gradient(colors: [c.ground.mixed(c.skyBottom, 0.5).color, c.ground.darkened(0.28).color]),
            startPoint: pt(0, horizon), endPoint: pt(0, height)))
        if sunVisible {
            for k in 0..<9 {
                let y = horizon + 2.5 + Double(k) * 3.5
                let w = sunR * 1.7 * (1 - Double(k) * 0.08) + rng.range(-1, 1)
                ctx.fill(Path(CGRect(x: sunX - w / 2, y: y, width: w, height: 0.9)),
                         with: .color(c.sun.color(opacity: 0.55 - Double(k) * 0.05)))
            }
        }
        for _ in 0..<26 {
            let y = rng.range(horizon + 3, height - 2)
            let depth = (y - horizon) / (height - horizon)
            let len = rng.range(4, 10) * (0.6 + depth)
            ctx.fill(Path(CGRect(x: rng.range(-4, 98), y: y, width: len, height: 0.4 + depth * 0.5)),
                     with: .color(c.skyBottom.lightened(0.5).color(opacity: 0.2)))
        }
    }
}
