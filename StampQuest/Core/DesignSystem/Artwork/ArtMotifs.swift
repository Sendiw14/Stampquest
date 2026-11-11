import SwiftUI

/// Dispatches a motif to its hand-built vector composition.
nonisolated enum ArtMotifs {
    static func draw(_ motif: ArtMotif, _ s: ArtSceneContext) {
        switch motif {
        case .eiffel: eiffel(s)
        case .tokyoTower: tokyoTower(s)
        case .towerBridge: towerBridge(s)
        case .colosseum: colosseum(s)
        case .sagrada: sagrada(s)
        case .hillTown: hillTown(s)
        case .canals: canals(s)
        case .stoneBridge: stoneBridge(s)
        case .parthenon: parthenon(s)
        case .towerFort: towerFort(s)
        case .castleHill: castleHill(s)
        case .fairyCastle: fairyCastle(s)
        case .hallgrimskirkja: hallgrimskirkja(s)
        case .fjord: fjord(s)
        case .peaks: peaks(s)
        case .duomo: duomo(s)
        case .parliament: parliament(s)
        case .alpineVillage: alpineVillage(s)
        case .meteora: meteora(s)
        case .cappadocia: cappadocia(s)
        case .maidenTower: maidenTower(s)
        case .torii: torii(s)
        case .fuji: fuji(s)
        case .tajMahal: tajMahal(s)
        case .angkor: angkor(s)
        case .greatWall: greatWall(s)
        case .marinaBay: marinaBay(s)
        case .pagoda: pagoda(s)
        case .burj: burj(s)
        case .petra: petra(s)
        case .halong: halong(s)
        case .hanokPalace: hanokPalace(s)
        case .prang: prang(s)
        case .sigiriya: sigiriya(s)
        case .lighthouseFort: lighthouseFort(s)
        case .pyramids: pyramids(s)
        case .tableMountain: tableMountain(s)
        case .savanna: savanna(s)
        case .minaret: minaret(s)
        case .waterfall: waterfall(s)
        case .statueOfLiberty: statueOfLiberty(s)
        case .suspensionBridge: suspensionBridge(s)
        case .canyon: canyon(s)
        case .lakeReflection: lakeReflection(s)
        case .mayanPyramid: mayanPyramid(s)
        case .geyser: geyser(s)
        case .balconyRow: balconyRow(s)
        case .palmBeach: palmBeach(s)
        case .machuPicchu: machuPicchu(s)
        case .christRedeemer: christRedeemer(s)
        case .operaHouse: operaHouse(s)
        case .monolith: monolith(s)
        case .louvre: louvre(s)
        }
    }

    // MARK: Shared helpers

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// A palm tree with a gently leaning trunk and drooping fronds.
    static func palm(_ p: ArtPen, x: Double, base: Double, h: Double, lean: Double, color: RGB) {
        var trunk = Path()
        trunk.move(to: pt(x, base))
        trunk.addQuadCurve(to: pt(x + lean, base - h), control: pt(x + lean * 0.15, base - h * 0.6))
        p.stroke(trunk, width: max(1.1, h * 0.05), color)
        let tip = pt(x + lean, base - h)
        let fronds: [(Double, Double)] = [(-11, 4), (-8, -2), (-3, -4), (3, -4), (8, -2), (11, 4), (-7, 9), (7, 9)]
        for (dx, dy) in fronds {
            let k = h / 34
            var f = Path()
            f.move(to: tip)
            f.addQuadCurve(to: pt(tip.x + dx * k, tip.y + dy * k + 3 * k),
                           control: pt(tip.x + dx * k * 0.5, tip.y + dy * k - 4 * k))
            p.stroke(f, width: max(1.1, h * 0.075), color)
        }
    }

    /// A stylised conifer made of stacked triangles.
    static func pine(_ p: ArtPen, x: Double, base: Double, h: Double, w: Double, color: RGB) {
        for i in 0..<3 {
            let apex = base - h + Double(i) * h * 0.24
            let bw = w * (0.55 + 0.45 * Double(i + 1) / 3)
            let tierBase = min(apex + h * 0.42, base - h * 0.08)
            p.poly([(x, apex), (x + bw / 2, tierBase), (x - bw / 2, tierBase)], color)
        }
        p.rect(x - 0.4, base - h * 0.12, 0.8, h * 0.12, color)
    }

    /// A row of pines across the foreground.
    static func pineRow(_ s: ArtSceneContext, on pen: ArtPen? = nil, from x0: Double, to x1: Double, base: Double,
                        height: ClosedRange<Double>, color: RGB, salt: UInt64) {
        var r = s.rng(salt)
        var x = x0
        while x < x1 {
            let h = r.range(height.lowerBound, height.upperBound)
            pine(pen ?? s.pen, x: x, base: base, h: h, w: h * 0.5, color: color)
            x += r.range(3.5, 7)
        }
    }

    /// A tiny person-like figure for scale.
    static func figure(_ p: ArtPen, x: Double, base: Double, h: Double, color: RGB) {
        p.rect(x - h * 0.12, base - h * 0.62, h * 0.24, h * 0.62, color)
        p.circle(x, base - h * 0.78, h * 0.14, color)
    }

    /// Fluffy low mist for atmospheric separation.
    static func mist(_ p: ArtPen, y: Double, color: RGB, opacity: Double = 0.4, salt: UInt64 = 1) {
        var r = ArtRandom(seed: salt &* 7919)
        for _ in 0..<6 {
            let x = r.range(0, 100), w = r.range(18, 34)
            p.ellipse(x, y + r.range(-1.5, 1.5), w / 2, r.range(1.4, 2.6), color, opacity: opacity)
        }
    }
}

nonisolated extension ArtPen {
    /// Runs `body` with a pen whose context is clipped to `path`.
    func clipped(to path: Path, _ body: (ArtPen) -> Void) {
        var copy = ctx
        copy.clip(to: path)
        body(ArtPen(ctx: copy))
    }

    /// Overlays a darker tone on the part of `path` to the right of `x`, to give forms volume.
    func shadeRight(_ path: Path, from x: Double, _ color: RGB, opacity: Double = 0.3) {
        clipped(to: path) { q in
            q.rect(x, -10, 200, 300, color, opacity: opacity)
        }
    }

    /// Brightens the part of `path` to the left of `x`.
    func lightLeft(_ path: Path, to x: Double, _ color: RGB, opacity: Double = 0.2) {
        clipped(to: path) { q in
            q.rect(-100, -10, x + 100, 300, color, opacity: opacity)
        }
    }
}
