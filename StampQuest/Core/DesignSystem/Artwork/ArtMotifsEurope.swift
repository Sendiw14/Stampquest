import SwiftUI

// European landmarks. Coordinates are in 100 × 130 art space; `g` is the ground line.
nonisolated extension ArtMotifs {
    // MARK: Eiffel Tower / Tokyo Tower

    static func eiffel(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        var body = Path()
        body.move(to: pt(29, g + 1))
        body.addQuadCurve(to: pt(49.2, g - 74), control: pt(47, g - 22))
        body.addLine(to: pt(50.8, g - 74))
        body.addQuadCurve(to: pt(71, g + 1), control: pt(53, g - 22))
        body.closeSubpath()
        p.fill(body, c.subject)
        p.shadeRight(body, from: 50, c.shade, opacity: 0.45)
        p.rect(38.5, g - 28, 23, 2.2, c.shade)
        p.rect(43.6, g - 48, 12.8, 1.8, c.shade)
        p.rect(47.4, g - 63, 5.2, 1.4, c.shade)
        p.rect(49.65, g - 90, 0.7, 17, c.subject)
        p.clearArch(cx: 50, y: g - 18, w: 22, h: 19)
        p.clear(Path(ellipseIn: CGRect(x: 43.4, y: g - 26, width: 1.7, height: 6)))
        p.clear(Path(ellipseIn: CGRect(x: 54.9, y: g - 26, width: 1.7, height: 6)))
        p.clear(Path(ellipseIn: CGRect(x: 49.2, y: g - 46, width: 1.6, height: 15)))
        p.clear(Path(ellipseIn: CGRect(x: 49.4, y: g - 61, width: 1.2, height: 9)))
        // Tiny strollers for scale
        figure(p, x: 20, base: g + 6, h: 4, color: c.deep)
        figure(p, x: 78, base: g + 8, h: 4.4, color: c.deep)
    }

    static func tokyoTower(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let top = g - 58
        func xl(_ y: Double) -> Double { lerp(30, 46.8, (g + 1 - y) / (g + 1 - top)) }
        func xr(_ y: Double) -> Double { 100 - xl(y) }
        let levels = [g + 1, g - 12, g - 24, g - 36, g - 47, top]
        p.poly([(xl(g + 1), g + 1), (xr(g + 1), g + 1), (xr(top), top), (xl(top), top)], c.subject, opacity: 0.22)
        for i in 0..<(levels.count - 1) {
            let y0 = levels[i], y1 = levels[i + 1]
            p.line(xl(y0), y0, xl(y1), y1, width: 1.9, c.subject)
            p.line(xr(y0), y0, xr(y1), y1, width: 1.9, c.subject)
            p.line(xl(y0), y0, xr(y1), y1, width: 0.7, c.subject)
            p.line(xr(y0), y0, xl(y1), y1, width: 0.7, c.subject)
            p.line(xl(y0), y0, xr(y0), y0, width: 0.9, c.subject)
        }
        // Observation decks
        let mainY = g - 28
        p.rect(xl(mainY) - 4, mainY, xr(mainY) - xl(mainY) + 8, 3.6, c.shade)
        p.rect(xl(mainY) - 4, mainY, xr(mainY) - xl(mainY) + 8, 1.0, c.light)
        let topY = g - 46
        p.rect(xl(topY) - 2.6, topY, xr(topY) - xl(topY) + 5.2, 2.6, c.shade)
        // Antenna
        p.rect(49.3, g - 90, 1.4, 34, c.subject)
        p.rect(48.6, g - 80, 2.8, 2.2, c.light)
        p.rect(48.6, g - 70, 2.8, 2.2, c.light)
        p.circle(50, g - 91, 1.0, c.light)
    }

    // MARK: Tower Bridge

    static func towerBridge(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            func tower(_ cx: Double) {
                let top = g - 46
                let body = Path(CGRect(x: cx - 8, y: top, width: 16, height: 47))
                q.fill(body, c.subject)
                q.shadeRight(body, from: cx, c.shade, opacity: 0.35)
                for dx in [-8.0, 5.2] {
                    q.poly([(cx + dx, top), (cx + dx + 1.4, top - 8), (cx + dx + 2.8, top)], c.subject)
                }
                q.poly([(cx - 5, top), (cx, top - 9), (cx + 5, top)], c.shade)
                q.rect(cx - 8.8, top, 17.6, 1.6, c.light)
                for dx in [-3.4, 3.4] {
                    q.clearArch(cx: cx + dx, y: top + 6, w: 2.6, h: 9)
                    q.clearArch(cx: cx + dx, y: top + 22, w: 2.6, h: 9)
                }
            }
            tower(26)
            tower(74)
            // Roadway and walkway
            q.rect(0, g - 13, 100, 2.4, c.subject)
            q.rect(34, g - 36, 32, 3.6, c.shade)
            for i in 0..<9 { q.clearRect(36 + Double(i) * 3.3, g - 35, 1.6, 1.6) }
            // Suspension chains
            for side in [0.0, 1.0] {
                let x0 = side == 0 ? 17.0 : 83.0, xe = side == 0 ? -2.0 : 102.0
                var chain = Path()
                chain.move(to: pt(x0, g - 34))
                chain.addQuadCurve(to: pt(xe, g - 12), control: pt(lerp(x0, xe, 0.55), g - 11))
                q.stroke(chain, width: 1.3, c.subject)
                var x = lerp(x0, xe, 0.12)
                while side == 0 ? x > xe + 2 : x < xe - 2 {
                    let t = abs(x - x0) / abs(xe - x0)
                    let y = (1 - t) * (1 - t) * (g - 34) + 2 * t * (1 - t) * (g - 11) + t * t * (g - 12)
                    q.line(x, y, x, g - 12, width: 0.45, c.subject, opacity: 0.8)
                    x += side == 0 ? -3.2 : 3.2
                }
            }
        }
        s.mirror(opacity: 0.28) { render($0) }
        render(p)
    }

    // MARK: Colosseum

    static func colosseum(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let roof: [(Double, Double)] = [(8, g - 30), (30, g - 34), (52, g - 37), (66, g - 36), (66, g - 27),
                                        (78, g - 27), (78, g - 19), (92, g - 17)]
        var out = Path()
        out.move(to: pt(8, g + 1))
        for (x, y) in roof { out.addLine(to: pt(x, y)) }
        out.addLine(to: pt(92, g + 1))
        out.closeSubpath()
        p.fill(out, c.subject)
        p.shadeRight(out, from: 62, c.shade, opacity: 0.30)

        func roofY(_ x: Double) -> Double {
            var best = roof[0].1
            for i in 0..<(roof.count - 1) {
                let a = roof[i], b = roof[i + 1]
                if b.0 > a.0 && x >= a.0 && x <= b.0 { best = lerp(a.1, b.1, (x - a.0) / (b.0 - a.0)) }
            }
            return best
        }
        let tiers: [(y: Double, h: Double)] = [(g - 9, 8), (g - 19, 7.4), (g - 29, 7)]
        for t in tiers {
            var x = 11.5
            while x < 89 {
                if t.y > roofY(x) + 2.5 { p.fillArch(cx: x, y: t.y, w: 4.4, h: t.h, c.deep) }
                x += 6.6
            }
        }
        p.clipped(to: out) { q in
            q.rect(8, g - 10.7, 84, 1.0, c.light, opacity: 0.55)
            q.rect(8, g - 20.7, 84, 1.0, c.light, opacity: 0.55)
            q.rect(8, g - 30.4, 84, 1.0, c.light, opacity: 0.55)
        }
        // Foreground pines
        pineRow(s, from: 2, to: 14, base: g + 3, height: 12...18, color: c.deep, salt: 3)
        pineRow(s, from: 90, to: 99, base: g + 3, height: 10...16, color: c.deep, salt: 4)
    }

    // MARK: Sagrada Família

    static func sagrada(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Nave / facade
        let facade = Path(CGRect(x: 14, y: g - 22, width: 72, height: 23))
        p.fill(facade, c.subject)
        p.shadeRight(facade, from: 56, c.shade, opacity: 0.3)
        let towers: [(x: Double, top: Double, w: Double)] = [
            (20, g - 44, 8), (31, g - 62, 9), (43, g - 78, 10), (57, g - 78, 10), (69, g - 62, 9), (80, g - 44, 8),
        ]
        for t in towers {
            let shoulder = t.top + 14
            var tower = Path()
            tower.move(to: pt(t.x - t.w / 2, g + 1))
            tower.addLine(to: pt(t.x - t.w / 2 + 0.7, shoulder))
            tower.addQuadCurve(to: pt(t.x, t.top), control: pt(t.x - t.w * 0.38, t.top + 6))
            tower.addQuadCurve(to: pt(t.x + t.w / 2 - 0.7, shoulder), control: pt(t.x + t.w * 0.38, t.top + 6))
            tower.addLine(to: pt(t.x + t.w / 2, g + 1))
            tower.closeSubpath()
            p.fill(tower, c.subject)
            p.shadeRight(tower, from: t.x, c.shade, opacity: 0.35)
            p.circle(t.x, t.top - 0.8, 1.3, c.light)
            // Bands of openings
            var y = t.top + 8
            while y < g - 24 {
                p.clearRect(t.x - 0.7, y, 1.4, 5)
                y += 9
            }
        }
        // Central spire with cross
        p.rect(49.4, g - 100, 1.2, 22, c.subject)
        p.rect(47.8, g - 96, 4.4, 1.2, c.subject)
        // Doors
        for x in [26.0, 50.0, 74.0] { p.clearArch(cx: x, y: g - 14, w: 7, h: 15) }
    }

    // MARK: Hill towns (Santorini, Cinque Terre, Chefchaouen)

    static func hillTown(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        var r = s.rng(11)
        let slope: [(Double, Double)] = [(-4, g - 48), (24, g - 44), (52, g - 28), (80, g - 12), (104, g - 2)]
        func slopeY(_ x: Double) -> Double {
            for i in 0..<(slope.count - 1) where x >= slope[i].0 && x <= slope[i + 1].0 {
                return lerp(slope[i].1, slope[i + 1].1, (x - slope[i].0) / (slope[i + 1].0 - slope[i].0))
            }
            return g
        }
        p.fill(Path.ridge(points: slope, baseY: g + 2), c.shade)

        let palette: [RGB]
        switch s.variant {
        case 1:
            palette = [RGB(r: 0.84, g: 0.67, b: 0.31), RGB(r: 0.73, g: 0.44, b: 0.29), RGB(r: 0.79, g: 0.56, b: 0.57),
                       RGB(r: 0.52, g: 0.66, b: 0.77), RGB(r: 0.93, g: 0.87, b: 0.74), RGB(r: 0.62, g: 0.70, b: 0.55)]
        case 2:
            palette = [c.tint, c.tint.lightened(0.25), c.tint.lightened(0.5), c.tint.darkened(0.12), RGB.white.mixed(c.tint, 0.2)]
        default:
            palette = [RGB.white.mixed(c.light, 0.12), RGB.white.mixed(c.light, 0.25), RGB.white.mixed(c.skyBottom, 0.12)]
        }
        let rows = 7
        for row in 0..<rows {
            var x = r.range(-2, 4)
            while x < 100 {
                let w = r.range(7, 12.5), h = r.range(6.5, 10.5)
                let yb = min(slopeY(x + w / 2) + 6 + Double(row) * 6.4, g + 1)
                if yb - h > slopeY(x + w / 2) - 1 {
                    let base = palette[r.int(0...(palette.count - 1))]
                    p.rect(x, yb - h, w, h, base)
                    p.rect(x + w * 0.72, yb - h, w * 0.28, h, base.darkened(0.16))
                    p.rect(x - 0.3, yb - h - 0.9, w + 0.6, 1.0, base.lightened(0.25))
                    p.rect(x + w * 0.22, yb - h * 0.58, 1.5, 2.5, s.variant == 0 ? c.tint : c.deep, opacity: 0.85)
                    if r.chance(0.5) { p.fillArch(cx: x + w * 0.55, y: yb - h * 0.5, w: 2.2, h: h * 0.5, c.deep, opacity: 0.75) }
                    if s.variant == 1 && r.chance(0.5) {
                        p.poly([(x - 0.8, yb - h - 0.9), (x + w / 2, yb - h - 4.2), (x + w + 0.8, yb - h - 0.9)],
                               RGB(r: 0.72, g: 0.4, b: 0.3))
                    }
                }
                x += w + r.range(0.4, 2.4)
            }
        }
        if s.variant == 0 {
            // Blue-domed churches
            for (dx, off) in [(26.0, 12.0), (60.0, 9.0)] {
                let yb = slopeY(dx) + off
                p.rect(dx - 4.5, yb - 8, 9, 8, RGB.white.mixed(c.light, 0.15))
                var dome = Path()
                dome.addArc(center: pt(dx, yb - 8), radius: 4.2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                dome.closeSubpath()
                p.fill(dome, c.tint)
                p.rect(dx - 0.25, yb - 14, 0.5, 2.2, RGB.white)
                p.rect(dx - 0.9, yb - 13, 1.8, 0.5, RGB.white)
            }
            // Bell tower
            let bx = 86.0, by = slopeY(bx) + 3
            p.rect(bx - 2.6, by - 17, 5.2, 17, RGB.white.mixed(c.light, 0.15))
            p.clearArch(cx: bx, y: by - 14, w: 3, h: 5)
            p.poly([(bx - 3, by - 17), (bx, by - 22), (bx + 3, by - 17)], c.tint)
        }
        if s.variant == 1 {
            // Quay with a few boats
            for bx in [18.0, 46.0] {
                p.poly([(bx, g + 3), (bx + 9, g + 3), (bx + 7.5, g + 5.4), (bx + 1.5, g + 5.4)], c.deep)
                p.rect(bx + 4.2, g - 2.5, 0.5, 5.5, c.deep)
            }
        }
    }

    // MARK: Canals (Venice, Amsterdam)

    static func canals(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let tones = [c.subject, c.subject.mixed(c.sun, 0.35), c.subject.mixed(c.tint, 0.35), c.light, c.subject.mixed(c.skyBottom, 0.3)]
        func render(_ q: ArtPen) {
            var r = s.rng(21)
            if s.variant == 0 {
                // Venice: low palazzi and a campanile
                var x = -2.0
                while x < 100 {
                    let w = r.range(12, 20), h = r.range(18, 30)
                    if x + w > 70 && x < 84 { x += w; continue }
                    let tone = tones[r.int(0...(tones.count - 1))]
                    q.rect(x, g - h, w, h + 1, tone)
                    q.rect(x + w - 2.5, g - h, 2.5, h + 1, tone.darkened(0.14))
                    q.rect(x - 0.4, g - h - 1.2, w + 0.8, 1.4, tone.lightened(0.3))
                    var wx = x + 2.2
                    while wx + 2.4 < x + w - 2 {
                        for row in 0..<2 { q.fillArch(cx: wx + 1.2, y: g - h + 4 + Double(row) * 8, w: 2.4, h: 5, c.deep, opacity: 0.85) }
                        wx += 5
                    }
                    x += w
                }
                // Campanile
                let tx = 77.0
                q.rect(tx - 3.6, g - 54, 7.2, 55, tones[0].lightened(0.1))
                q.rect(tx + 1.4, g - 54, 2.2, 55, tones[0].darkened(0.18))
                q.rect(tx - 4.2, g - 56, 8.4, 2.4, tones[3])
                q.clearArch(cx: tx, y: g - 52, w: 4, h: 7)
                q.poly([(tx - 4, g - 56), (tx, g - 69), (tx + 4, g - 56)], c.tint)
                q.circle(tx, g - 70, 1, c.sun)
            } else {
                // Amsterdam: narrow gabled houses
                var x = 0.0
                var i = 0
                while x < 98 {
                    let w = r.range(10, 13), h = r.range(24, 36)
                    let tone = [c.subject, c.subject.mixed(c.tint, 0.4), c.subject.darkened(0.12), c.subject.mixed(c.sun, 0.3)][i % 4]
                    q.rect(x, g - h, w, h + 1, tone)
                    switch i % 3 {
                    case 0:
                        q.poly([(x - 0.3, g - h), (x + w / 2, g - h - 6), (x + w + 0.3, g - h)], tone.lightened(0.18))
                    case 1:
                        q.poly([(x, g - h), (x, g - h - 3), (x + w * 0.25, g - h - 3), (x + w * 0.25, g - h - 6),
                                (x + w * 0.75, g - h - 6), (x + w * 0.75, g - h - 3), (x + w, g - h - 3), (x + w, g - h)],
                               tone.lightened(0.18))
                    default:
                        q.poly([(x - 0.3, g - h), (x + w * 0.3, g - h - 3), (x + w / 2, g - h - 7),
                                (x + w * 0.7, g - h - 3), (x + w + 0.3, g - h)], tone.lightened(0.18))
                    }
                    for row in 0..<3 {
                        for col in 0..<2 {
                            q.rect(x + 1.8 + Double(col) * (w - 4.6), g - h + 5 + Double(row) * 9, 2.4, 4.4, c.deep, opacity: 0.85)
                            q.rect(x + 1.8 + Double(col) * (w - 4.6), g - h + 5 + Double(row) * 9, 2.4, 0.8, c.light, opacity: 0.6)
                        }
                    }
                    x += w + 0.4
                    i += 1
                }
                // Humped bridge across the canal
                var bridge = Path()
                bridge.move(to: pt(-2, g + 3))
                bridge.addQuadCurve(to: pt(102, g + 3), control: pt(50, g - 10))
                q.stroke(bridge, width: 1.2, c.deep, opacity: 0.8)
            }
        }
        s.mirror(opacity: 0.26) { render($0) }
        render(p)

        if s.variant == 0 {
            // Gondola
            let y = g + 14
            var hull = Path()
            hull.move(to: pt(14, y - 5))
            hull.addQuadCurve(to: pt(26, y + 1), control: pt(17, y + 1))
            hull.addLine(to: pt(52, y + 1))
            hull.addQuadCurve(to: pt(62, y - 7), control: pt(59, y + 1))
            hull.addQuadCurve(to: pt(14, y - 5), control: pt(38, y - 2))
            hull.closeSubpath()
            p.fill(hull, c.deep)
            p.rect(46, y - 12, 1.7, 11, c.deep)
            p.circle(46.9, y - 13.6, 1.5, c.deep)
            p.line(47.4, y - 7, 38, y + 7, width: 0.7, c.deep)
            p.rect(30, y - 3, 10, 2, c.tint)
        }
    }

    // MARK: Charles Bridge

    static func stoneBridge(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            // Castle on the hill behind
            q.poly([(46, g - 8), (56, g - 28), (72, g - 34), (92, g - 24), (104, g - 8)], c.hillFar.mixed(c.subject, 0.35))
            let spires: [(Double, Double)] = [(60, 20), (66, 28), (72, 18), (78, 24)]
            for (x, h) in spires {
                q.rect(x - 1.6, g - 36 - h * 0.45, 3.2, h * 0.45 + 4, c.subject, opacity: 0.8)
                q.poly([(x - 2, g - 36 - h * 0.45), (x, g - 36 - h), (x + 2, g - 36 - h * 0.45)], c.subject, opacity: 0.85)
            }
            // Bridge deck and arches
            let bridge = Path(CGRect(x: -2, y: g - 14, width: 104, height: 16))
            q.fill(bridge, c.subject)
            q.shadeRight(bridge, from: 70, c.shade, opacity: 0.2)
            q.rect(-2, g - 16, 104, 2.6, c.light)
            for x in [10.0, 28.0, 46.0, 64.0, 82.0, 100.0] {
                q.clearArch(cx: x, y: g - 11, w: 12, h: 13)
            }
            // Statues on the parapet
            var x = 30.0
            while x < 94 {
                q.rect(x - 0.7, g - 22, 1.4, 5.5, c.deep)
                q.circle(x, g - 23, 0.9, c.deep)
                q.rect(x - 1.6, g - 17.5, 3.2, 1.4, c.deep)
                x += 9
            }
            // Old Town Bridge Tower
            let tower = Path(CGRect(x: 2, y: g - 44, width: 14, height: 32))
            q.fill(tower, c.subject)
            q.shadeRight(tower, from: 9, c.shade, opacity: 0.35)
            q.poly([(0.5, g - 44), (9, g - 62), (17.5, g - 44)], c.shade)
            for tx in [2.4, 13.6] { q.poly([(tx - 1.6, g - 44), (tx, g - 53), (tx + 1.6, g - 44)], c.shade) }
            q.clearArch(cx: 9, y: g - 38, w: 3.4, h: 8)
            q.clearArch(cx: 9, y: g - 26, w: 4, h: 14)
        }
        s.mirror(opacity: 0.25) { render($0) }
        render(p)
    }

    // MARK: Acropolis

    static func parthenon(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let rock = Path.ridge(points: [(-4, g + 1), (6, g - 8), (22, g - 15), (78, g - 15), (94, g - 9), (104, g + 1)], baseY: g + 2)
        p.fill(rock, c.shade)
        p.lightLeft(rock, to: 40, c.light, opacity: 0.12)
        // Steps
        p.rect(18, g - 18, 64, 3.2, c.light.darkened(0.08))
        p.rect(20, g - 20.4, 60, 2.6, c.light)
        // Columns
        var x = 23.0
        var i = 0
        while i < 8 {
            let broken = (i == 6)
            let hgt = broken ? 12.0 : 21.0
            p.rect(x, g - 20.4 - hgt, 3.4, hgt, c.light)
            p.rect(x + 2.4, g - 20.4 - hgt, 1.0, hgt, c.light.darkened(0.2))
            p.clearRect(x + 1.1, g - 20.4 - hgt + 1, 0.4, hgt - 2)
            p.rect(x - 0.6, g - 20.4 - hgt - 1, 4.6, 1.4, c.light)
            x += 7.3
            i += 1
        }
        // Entablature and pediment
        p.rect(21, g - 46, 58, 4.4, c.subject)
        for k in 0..<14 { p.rect(22 + Double(k) * 4.1, g - 45.4, 2.4, 3, c.subject.darkened(0.2)) }
        p.poly([(19, g - 46), (50, g - 59), (81, g - 46)], c.light)
        p.poly([(25, g - 47.6), (50, g - 56.4), (75, g - 47.6)], c.subject.mixed(c.light, 0.5))
        // Distant city
        for (bx, bw, bh) in [(2.0, 6.0, 7.0), (9.0, 5.0, 9.0), (88.0, 7.0, 6.0), (95.0, 6.0, 8.0)] {
            p.rect(bx, g - 2 - bh * 0.4, bw, bh * 0.4 + 3, c.hillNear.darkened(0.2))
        }
    }

    // MARK: Belém Tower

    static func towerFort(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            // Bulwark
            let bulwark = Path(CGRect(x: 16, y: g - 7, width: 68, height: 8))
            q.fill(bulwark, c.subject)
            q.shadeRight(bulwark, from: 60, c.shade, opacity: 0.3)
            var x = 16.5
            while x < 83 { q.rect(x, g - 9, 2.4, 2.2, c.subject); x += 4.4 }
            q.clearArch(cx: 40, y: g - 5, w: 3, h: 6)
            q.clearArch(cx: 60, y: g - 5, w: 3, h: 6)
            // Main keep
            let keep = Path(CGRect(x: 34, y: g - 42, width: 32, height: 35))
            q.fill(keep, c.subject.lightened(0.05))
            q.shadeRight(keep, from: 56, c.shade, opacity: 0.32)
            var cx = 34.4
            while cx < 65 { q.rect(cx, g - 44.2, 2.4, 2.4, c.subject); cx += 4.4 }
            // Loggia arches
            for ax in [41.0, 50.0, 59.0] { q.clearArch(cx: ax, y: g - 28, w: 4.4, h: 9) }
            q.rect(34, g - 31, 32, 1.2, c.light)
            for k in 0..<5 { q.clearArch(cx: 38 + Double(k) * 6, y: g - 40, w: 2, h: 4) }
            // Corner watch turrets
            for tx in [33.0, 67.0] {
                q.rect(tx - 3.2, g - 50, 6.4, 14, c.subject)
                q.shadeRight(Path(CGRect(x: tx - 3.2, y: g - 50, width: 6.4, height: 14)), from: tx, c.shade, opacity: 0.3)
                var dome = Path()
                dome.addArc(center: pt(tx, g - 50), radius: 3.9, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                dome.closeSubpath()
                q.fill(dome, c.light)
                q.circle(tx, g - 54.8, 0.8, c.light)
            }
            // Cross of the Order of Christ
            q.rect(49, g - 38, 2, 4, c.tint)
            q.rect(47.5, g - 36.6, 5, 1.6, c.tint)
        }
        s.mirror(opacity: 0.25) { render($0) }
        render(p)
        // Caravel
        p.poly([(80, g + 12), (94, g + 12), (91, g + 15.5), (83, g + 15.5)], c.deep)
        p.rect(86.8, g + 2, 0.7, 10, c.deep)
        p.poly([(87.6, g + 2.5), (94, g + 10.5), (87.6, g + 10.5)], c.light)
        p.poly([(86.8, g + 3.4), (81, g + 10.5), (86.8, g + 10.5)], c.light, opacity: 0.85)
    }

    // MARK: Edinburgh Castle

    static func castleHill(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let crag = Path.ridge(points: [(-4, g + 1), (6, g - 16), (20, g - 30), (60, g - 32), (76, g - 22), (88, g - 6), (104, g + 1)], baseY: g + 2)
        p.fill(crag, c.shade)
        p.lightLeft(crag, to: 40, c.light, opacity: 0.15)
        for i in 0..<6 {
            let y = g - 28 + Double(i) * 5
            p.line(12 + Double(i) * 2, y, 70 + Double(i) * 3, y + 1.4, width: 0.5, c.deep, opacity: 0.25)
        }
        // Castle
        let hall = Path(CGRect(x: 24, y: g - 52, width: 36, height: 22))
        p.fill(hall, c.subject)
        p.shadeRight(hall, from: 46, c.shade, opacity: 0.3)
        var x = 24.0
        while x < 59 { p.rect(x, g - 54, 2.2, 2.4, c.subject); x += 4.2 }
        let keep = Path(CGRect(x: 56, y: g - 64, width: 11, height: 34))
        p.fill(keep, c.subject.lightened(0.04))
        p.shadeRight(keep, from: 62, c.shade, opacity: 0.32)
        x = 56
        while x < 66 { p.rect(x, g - 66, 2, 2.4, c.subject); x += 3.6 }
        p.rect(26, g - 62, 8, 10, c.subject)
        p.poly([(25, g - 62), (30, g - 72), (35, g - 62)], c.shade)
        p.rect(29.7, g - 79, 0.6, 7, c.deep)
        p.poly([(30.3, g - 79), (36, g - 77), (30.3, g - 75)], c.tint)
        for wx in [30.0, 38.0, 46.0, 53.0] { p.fillArch(cx: wx, y: g - 48, w: 2.4, h: 5, c.deep, opacity: 0.85) }
        p.clearArch(cx: 61.5, y: g - 58, w: 2.6, h: 6)
        // Foreground rooftops of the Old Town
        for (rx, rw, rh) in [(0.0, 12.0, 8.0), (12.0, 10.0, 12.0), (74.0, 12.0, 9.0), (86.0, 14.0, 13.0)] {
            p.poly([(rx, g + 3), (rx, g + 3 - rh), (rx + rw / 2, g - rh - 4), (rx + rw, g + 3 - rh), (rx + rw, g + 3)], c.deep)
        }
    }

    // MARK: Neuschwanstein

    static func fairyCastle(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let hill = Path.ridge(points: [(-4, g + 1), (14, g - 18), (36, g - 28), (66, g - 26), (88, g - 14), (104, g + 1)], baseY: g + 2)
        p.fill(hill, c.shade)
        // Main block
        let hall = Path(CGRect(x: 30, y: g - 50, width: 44, height: 24))
        p.fill(hall, c.light)
        p.shadeRight(hall, from: 56, c.shade, opacity: 0.22)
        p.poly([(28, g - 50), (52, g - 62), (76, g - 50)], c.tint)
        // Towers with conical roofs
        func tower(_ x: Double, _ w: Double, _ top: Double, _ roof: Double) {
            let body = Path(CGRect(x: x - w / 2, y: top, width: w, height: g - 26 - top))
            p.fill(body, c.light)
            p.shadeRight(body, from: x, c.shade, opacity: 0.25)
            p.poly([(x - w / 2 - 1, top), (x, top - roof), (x + w / 2 + 1, top)], c.tint)
            p.fillArch(cx: x, y: top + 6, w: 2.2, h: 5, c.deep, opacity: 0.85)
            p.fillArch(cx: x, y: top + 16, w: 2.2, h: 5, c.deep, opacity: 0.85)
        }
        tower(40, 9, g - 76, 16)
        tower(65, 10, g - 66, 13)
        tower(28, 5.4, g - 58, 9)
        tower(78, 5.4, g - 56, 9)
        p.rect(48, g - 74, 0.6, 7, c.deep)
        // Windows on hall
        for wx in [34.0, 46.0, 54.0, 70.0] { p.fillArch(cx: wx, y: g - 46, w: 2.6, h: 7, c.deep, opacity: 0.8) }
        // Forest in front
        pineRow(s, from: -2, to: 102, base: g + 6, height: 14...26, color: c.deep.mixed(c.ground, 0.4), salt: 31)
    }

    // MARK: Hallgrímskirkja

    static func hallgrimskirkja(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Stepped wings, echoing basalt columns
        for dir in [-1.0, 1.0] {
            var wing = Path()
            wing.move(to: pt(50 + dir * 6, g + 1))
            wing.addLine(to: pt(50 + dir * 6, g - 46))
            wing.addLine(to: pt(50 + dir * 12, g - 40))
            wing.addLine(to: pt(50 + dir * 18, g - 34))
            wing.addLine(to: pt(50 + dir * 24, g - 28))
            wing.addLine(to: pt(50 + dir * 30, g - 20))
            wing.addLine(to: pt(50 + dir * 34, g - 12))
            wing.addLine(to: pt(50 + dir * 34, g + 1))
            wing.closeSubpath()
            p.fill(wing, c.subject)
            // Column fluting
            var k = 1.0
            while k < 34 {
                p.clearRect(50 + dir * k - 0.3, g - 40 + k * 0.78, 0.6, 38 - k * 0.78)
                k += 3.6
            }
        }
        // Tower
        let tower = Path(CGRect(x: 43, y: g - 62, width: 14, height: 63))
        p.fill(tower, c.subject.lightened(0.05))
        p.shadeRight(tower, from: 50, c.shade, opacity: 0.3)
        p.poly([(43, g - 62), (46, g - 66), (46, g - 62)], c.subject)
        p.poly([(54, g - 62), (54, g - 66), (57, g - 62)], c.subject)
        p.poly([(46, g - 66), (50, g - 86), (54, g - 66)], c.subject)
        p.rect(49.6, g - 94, 0.8, 9, c.subject)
        p.circle(50, g - 56, 3.4, c.light)
        p.circle(50, g - 56, 2.8, c.deep, opacity: 0.35)
        p.clearRect(47, g - 48, 1.2, 14)
        p.clearRect(51.8, g - 48, 1.2, 14)
        p.clearRect(49.4, g - 46, 1.2, 12)
        // Statue of Leifur Eiríksson on the plaza
        p.rect(18, g - 6, 3.4, 8, c.deep)
        p.rect(17, g - 8, 5.4, 2, c.deep)
        // Snowy roofs of Reykjavik
        let accent = c.tint.mixed(c.subject, 0.4)
        for (rx, rw, rh, rc) in [(0.0, 12.0, 8.0, c.tint), (12.0, 10.0, 10.0, accent), (74.0, 12.0, 9.0, accent), (86.0, 14.0, 12.0, c.tint)] {
            p.poly([(rx, g + 5), (rx, g + 5 - rh), (rx + rw / 2, g - rh), (rx + rw, g + 5 - rh), (rx + rw, g + 5)], rc.darkened(0.2))
        }
    }

    // MARK: Florence Duomo

    static func duomo(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Nave
        let nave = Path(CGRect(x: 16, y: g - 20, width: 68, height: 21))
        p.fill(nave, c.light)
        p.shadeRight(nave, from: 60, c.shade, opacity: 0.2)
        for i in 0..<9 {
            p.rect(18 + Double(i) * 7.4, g - 18, 0.8, 18, c.tint, opacity: 0.35)
            p.fillArch(cx: 21.5 + Double(i) * 7.4, y: g - 16, w: 2.4, h: 6, c.deep, opacity: 0.75)
        }
        p.rect(16, g - 22, 68, 2.2, c.tint, opacity: 0.8)
        // Drum + dome
        p.rect(33, g - 34, 34, 14, c.light)
        for i in 0..<4 { p.circle(38 + Double(i) * 8, g - 28, 1.7, c.deep, opacity: 0.85) }
        var dome = Path()
        dome.move(to: pt(33, g - 34))
        dome.addQuadCurve(to: pt(50, g - 66), control: pt(33, g - 62))
        dome.addQuadCurve(to: pt(67, g - 34), control: pt(67, g - 62))
        dome.closeSubpath()
        p.fill(dome, c.subject)
        p.shadeRight(dome, from: 55, c.shade, opacity: 0.35)
        for xi in [37.0, 42.0, 46.5, 50.0, 53.5, 58.0, 63.0] {
            var rib = Path()
            rib.move(to: pt(xi, g - 34))
            rib.addQuadCurve(to: pt(50, g - 65), control: pt(xi + (50 - xi) * 0.05, g - 58))
            p.stroke(rib, width: 0.55, c.light, opacity: 0.75, cap: .butt)
        }
        // Lantern
        p.rect(47.2, g - 76, 5.6, 11, c.light)
        p.poly([(46.6, g - 76), (50, g - 86), (53.4, g - 76)], c.subject)
        p.circle(50, g - 87.4, 1.4, c.sun)
        p.rect(49.8, g - 92, 0.4, 4, c.deep)
        // Giotto's bell tower
        let bell = Path(CGRect(x: 78, y: g - 56, width: 9, height: 57))
        p.fill(bell, c.light)
        p.shadeRight(bell, from: 83, c.shade, opacity: 0.22)
        for i in 0..<4 { p.clearArch(cx: 82.5, y: g - 50 + Double(i) * 10, w: 3.2, h: 6.5) }
        p.rect(77.2, g - 58, 10.6, 2.4, c.tint)
    }

    // MARK: Hungarian Parliament

    static func parliament(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            let wing = Path(CGRect(x: 6, y: g - 20, width: 88, height: 21))
            q.fill(wing, c.subject)
            q.shadeRight(wing, from: 70, c.shade, opacity: 0.2)
            // Spires along the roofline
            var x = 10.0
            var i = 0
            while x < 92 {
                if abs(x - 50) > 14 {
                    let h = (i % 2 == 0) ? 11.0 : 7.0
                    q.poly([(x - 1.6, g - 20), (x, g - 20 - h), (x + 1.6, g - 20)], c.subject)
                }
                x += 5.2
                i += 1
            }
            // Dome
            q.rect(40, g - 38, 20, 19, c.subject)
            q.shadeRight(Path(CGRect(x: 40, y: g - 38, width: 20, height: 19)), from: 52, c.shade, opacity: 0.25)
            var dome = Path()
            dome.move(to: pt(41, g - 38))
            dome.addQuadCurve(to: pt(50, g - 58), control: pt(41, g - 56))
            dome.addQuadCurve(to: pt(59, g - 38), control: pt(59, g - 56))
            dome.closeSubpath()
            q.fill(dome, c.shade.lightened(0.1))
            q.poly([(48.6, g - 58), (50, g - 72), (51.4, g - 58)], c.subject)
            q.rect(49.75, g - 76, 0.5, 5, c.sun)
            for k in 0..<4 { q.poly([(41.5 + Double(k) * 5.2, g - 38), (42.8 + Double(k) * 5.2, g - 44), (44.1 + Double(k) * 5.2, g - 38)], c.subject) }
            // Pavilions
            for px in [10.0, 90.0] {
                q.rect(px - 5, g - 28, 10, 9, c.subject)
                q.poly([(px - 5.5, g - 28), (px, g - 42), (px + 5.5, g - 28)], c.shade)
            }
            // Windows
            for k in 0..<24 {
                let wx = 9 + Double(k) * 3.5
                if abs(wx - 50) > 10 {
                    if s.variant == 1 {
                        q.fillArch(cx: wx, y: g - 15, w: 1.8, h: 5.5, c.sun, opacity: 0.9)
                    } else {
                        q.clearArch(cx: wx, y: g - 15, w: 1.8, h: 5.5)
                    }
                }
            }
            q.clearArch(cx: 50, y: g - 14, w: 5, h: 15)
        }
        s.mirror(opacity: 0.30) { render($0) }
        render(p)
    }

    // MARK: Hallstatt

    static func alpineVillage(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Rock face behind the village
        let face = Path.ridge(points: [(-4, g - 4), (10, g - 40), (28, g - 62), (44, g - 76), (62, g - 60), (80, g - 36), (104, g - 6)], baseY: g + 2)
        p.fill(face, c.hillFar.mixed(c.subject, 0.55))
        p.shadeRight(face, from: 54, c.shade, opacity: 0.35)
        p.clipped(to: face) { q in
            q.poly([(30, g - 60), (44, g - 78), (58, g - 62), (50, g - 64), (44, g - 56), (38, g - 63)], RGB.white, opacity: 0.85)
        }
        pineRow(s, from: 8, to: 92, base: g - 6, height: 6...11, color: c.deep.mixed(c.ground, 0.5), salt: 5)
        func render(_ q: ArtPen) {
            var r = s.rng(41)
            // Chalets along the shore
            var x = 6.0
            while x < 90 {
                let w = r.range(8, 12), h = r.range(6, 9)
                let wall = [RGB.white.mixed(c.light, 0.3), c.light, c.subject.lightened(0.3)][r.int(0...2)]
                q.rect(x, g - h, w, h + 1, wall)
                q.poly([(x - 0.8, g - h), (x + w / 2, g - h - 5), (x + w + 0.8, g - h)], c.tint.darkened(0.2))
                q.rect(x + w * 0.3, g - h * 0.6, 1.6, 2.2, c.deep, opacity: 0.85)
                x += w + r.range(0.6, 3)
            }
            // Church spire
            q.rect(47, g - 16, 6.5, 17, RGB.white.mixed(c.light, 0.2))
            q.poly([(46.4, g - 16), (50.25, g - 38), (54.1, g - 16)], c.shade)
            q.fillArch(cx: 50.25, y: g - 13, w: 2.4, h: 5, c.deep, opacity: 0.8)
        }
        s.mirror(opacity: 0.3) { render($0) }
        render(p)
    }

    // MARK: Louvre

    static func louvre(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Palace wings with mansard roofs
        for (x0, flip) in [(-2.0, false), (72.0, true)] {
            let w = 30.0
            let wall = Path(CGRect(x: x0, y: g - 22, width: w, height: 23))
            p.fill(wall, c.subject)
            p.shadeRight(wall, from: x0 + w * 0.6, c.shade, opacity: 0.2)
            let slope = flip ? [(x0 - 1, g - 22), (x0 + 5, g - 34), (x0 + w + 2, g - 34), (x0 + w + 2, g - 22)]
                             : [(x0 - 2, g - 22), (x0 - 2, g - 34), (x0 + w - 5, g - 34), (x0 + w + 1, g - 22)]
            p.poly(slope, c.shade)
            var wx = x0 + 3.5
            while wx < x0 + w - 2 {
                p.fillArch(cx: wx, y: g - 18, w: 2.2, h: 6.5, c.deep, opacity: 0.8)
                p.fillArch(cx: wx, y: g - 31, w: 2, h: 4, c.light, opacity: 0.7)
                wx += 6
            }
        }
        // Back wing
        let back = Path(CGRect(x: 26, y: g - 20, width: 48, height: 21))
        p.fill(back, c.subject.darkened(0.08))
        p.poly([(24, g - 20), (30, g - 29), (70, g - 29), (76, g - 20)], c.shade)
        // The glass pyramid
        let pyramid = Path { path in
            path.move(to: pt(32, g + 1))
            path.addLine(to: pt(50, g - 28))
            path.addLine(to: pt(68, g + 1))
            path.closeSubpath()
        }
        p.fill(pyramid, c.light, opacity: 0.88)
        p.shadeRight(pyramid, from: 50, c.skyTop.mixed(c.skyBottom, 0.5), opacity: 0.25)
        p.clipped(to: pyramid) { q in
            for i in 1..<8 {
                let t = Double(i) / 8
                q.line(lerp(32, 50, t), lerp(g + 1, g - 28, t), lerp(68, 50, t), lerp(g + 1, g - 28, t), width: 0.35, c.deep, opacity: 0.55)
                q.line(lerp(32, 68, t), g + 1, 50, g - 28, width: 0.35, c.deep, opacity: 0.4)
                q.line(lerp(68, 32, t), g + 1, 50, g - 28, width: 0.35, c.deep, opacity: 0.4)
            }
        }
        p.stroke(pyramid, width: 0.8, c.deep, opacity: 0.65)
        // Small satellite pyramids
        for (px, pw) in [(14.0, 7.0), (86.0, 7.0)] {
            p.poly([(px - pw, g + 6), (px, g - 2), (px + pw, g + 6)], c.light, opacity: 0.7)
        }
    }
}
