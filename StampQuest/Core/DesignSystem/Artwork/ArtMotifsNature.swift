import SwiftUI

// Natural wonders, the Americas and Oceania.
nonisolated extension ArtMotifs {
    // MARK: Geirangerfjord

    static func fjord(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Distant peaks at the end of the fjord
        p.fill(Path.ridge(points: [(30, g), (40, g - 24), (50, g - 38), (60, g - 22), (70, g)], baseY: g + 1), c.hillFar)
        let left = Path { path in
            path.move(to: pt(-2, g + 1)); path.addLine(to: pt(-2, 14)); path.addLine(to: pt(14, 22))
            path.addLine(to: pt(22, 42)); path.addLine(to: pt(30, 60)); path.addLine(to: pt(38, 78)); path.addLine(to: pt(46, g + 1))
            path.closeSubpath()
        }
        let right = Path { path in
            path.move(to: pt(102, g + 1)); path.addLine(to: pt(102, 6)); path.addLine(to: pt(88, 18))
            path.addLine(to: pt(80, 38)); path.addLine(to: pt(72, 62)); path.addLine(to: pt(64, 80)); path.addLine(to: pt(56, g + 1))
            path.closeSubpath()
        }
        p.fill(left, c.subject)
        p.fill(right, c.shade)
        p.lightLeft(left, to: 24, c.light, opacity: 0.18)
        // Strata streaks and snow
        var r = s.rng(161)
        for path in [left, right] {
            p.clipped(to: path) { q in
                for _ in 0..<14 {
                    let x = r.range(-2, 102), y = r.range(10, g)
                    q.line(x, y, x + r.range(-3, 3), y + r.range(6, 16), width: 0.5, c.deep, opacity: 0.25)
                }
            }
        }
        p.clipped(to: left) { q in q.poly([(-2, 14), (14, 22), (22, 42), (14, 38), (6, 46), (-2, 36)], RGB.white, opacity: 0.88) }
        p.clipped(to: right) { q in q.poly([(102, 6), (88, 18), (80, 38), (90, 34), (96, 44), (102, 30)], RGB.white, opacity: 0.88) }
        // Waterfalls
        for (x0, y0, y1) in [(27.0, 54.0, g - 6), (75.0, 50.0, g - 8)] {
            var f = Path()
            f.move(to: pt(x0, y0))
            f.addQuadCurve(to: pt(x0 + (x0 < 50 ? 4 : -4), y1), control: pt(x0 + (x0 < 50 ? -1 : 1), (y0 + y1) / 2))
            p.stroke(f, width: 1.5, .white, opacity: 0.85)
        }
        // Forest on the shorelines
        pineRow(s, from: 30, to: 46, base: g + 1, height: 7...12, color: c.deep.mixed(c.ground, 0.4), salt: 6)
        pineRow(s, from: 56, to: 70, base: g + 1, height: 7...12, color: c.deep.mixed(c.ground, 0.4), salt: 7)
        // Ferry
        p.poly([(46, g + 12), (62, g + 12), (59.5, g + 15), (48.5, g + 15)], c.deep)
        p.rect(50, g + 8, 8, 4, c.light)
        p.rect(53, g + 5.5, 2.4, 2.6, c.light)
    }

    // MARK: Peaks (Matterhorn, Torres del Paine)

    static func peaks(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func peak(_ points: [(Double, Double)], snowLine: Double, shadeFrom: Double) {
            let path = Path { path in
                path.move(to: pt(points[0].0, points[0].1))
                for q in points.dropFirst() { path.addLine(to: pt(q.0, q.1)) }
                path.closeSubpath()
            }
            p.fill(path, c.subject)
            p.shadeRight(path, from: shadeFrom, c.shade, opacity: 0.5)
            p.clipped(to: path) { q in
                var snow = Path()
                snow.move(to: pt(0, 0)); snow.addLine(to: pt(100, 0)); snow.addLine(to: pt(100, snowLine))
                var x = 100.0
                var up = false
                while x > 0 { snow.addLine(to: pt(x, snowLine + (up ? -4 : 3))); x -= 5; up.toggle() }
                snow.addLine(to: pt(0, snowLine)); snow.closeSubpath()
                q.fill(snow, RGB.white.mixed(c.skyBottom, 0.1), opacity: 0.92)
                q.shadeRight(snow, from: shadeFrom, c.shade.mixed(c.skyBottom, 0.6), opacity: 0.35)
            }
        }
        if s.variant == 1 {
            // Torres del Paine: three granite towers
            peak([(6, g + 1), (14, g - 26), (24, g - 52), (28, g - 54), (32, g - 30), (34, g + 1)], snowLine: g - 40, shadeFrom: 28)
            peak([(26, g + 1), (36, g - 36), (44, g - 66), (50, g - 72), (56, g - 64), (64, g - 34), (72, g + 1)], snowLine: g - 54, shadeFrom: 50)
            peak([(60, g + 1), (68, g - 28), (76, g - 50), (80, g - 52), (86, g - 30), (96, g + 1)], snowLine: g - 40, shadeFrom: 80)
            // Foreground lake shore and shrubs
            var r = s.rng(171)
            for _ in 0..<30 {
                p.circle(r.range(-2, 102), g + r.range(2, 10), r.range(1.6, 3.4), c.ground.mixed(c.deep, 0.5), opacity: 0.9)
            }
        } else {
            // The Matterhorn
            peak([(10, g + 1), (24, g - 24), (38, g - 50), (47, g - 74), (50, g - 80), (54, g - 66), (62, g - 52), (72, g - 36), (92, g + 1)],
                 snowLine: g - 54, shadeFrom: 50)
            p.fill(Path.ridge(points: [(-4, g + 1), (10, g - 10), (24, g - 4)], baseY: g + 2), c.hillNear)
            pineRow(s, from: -2, to: 100, base: g + 6, height: 10...20, color: c.deep.mixed(c.ground, 0.4), salt: 12)
        }
    }

    // MARK: Meteora

    static func meteora(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func pillar(_ cx: Double, _ w: Double, _ h: Double, tone: RGB, monastery: Bool) {
            var r = s.rng(UInt64(cx * 10))
            var path = Path()
            path.move(to: pt(cx - w / 2, g + 1))
            var y = g + 1.0
            var xl = cx - w / 2
            while y > g - h {
                y -= r.range(5, 9)
                xl += r.range(-1.4, 1.8)
                path.addLine(to: pt(xl, max(y, g - h)))
            }
            path.addLine(to: pt(cx - w * 0.34, g - h - 1))
            path.addLine(to: pt(cx + w * 0.38, g - h - 0.5))
            var xr = cx + w * 0.5
            var yy = g - h
            var rightPts: [CGPoint] = []
            while yy < g {
                yy += r.range(5, 9)
                xr += r.range(-1.6, 1.4)
                rightPts.append(pt(xr, min(yy, g + 1)))
            }
            for q in rightPts { path.addLine(to: q) }
            path.closeSubpath()
            p.fill(path, tone)
            p.shadeRight(path, from: cx + w * 0.1, c.shade, opacity: 0.4)
            p.clipped(to: path) { q in
                for k in 0..<Int(w / 2.2) {
                    q.rect(cx - w / 2 + Double(k) * 2.4 + r.range(0, 1.2), g - h, r.range(0.4, 0.9), h + 2, c.deep, opacity: 0.22)
                }
            }
            if monastery {
                let top = g - h - 1
                p.rect(cx - w * 0.34, top - 6, w * 0.52, 6, c.light)
                p.poly([(cx - w * 0.38, top - 6), (cx - w * 0.08, top - 11), (cx + w * 0.22, top - 6)], c.tint)
                p.rect(cx + w * 0.18, top - 9, w * 0.14, 9, c.light.darkened(0.08))
                p.fillArch(cx: cx - w * 0.14, y: top - 4.4, w: 1.6, h: 3.2, c.deep, opacity: 0.8)
            }
        }
        pillar(10, 12, 36, tone: c.hillFar.mixed(c.subject, 0.5), monastery: false)
        pillar(90, 12, 34, tone: c.hillFar.mixed(c.subject, 0.5), monastery: false)
        pillar(27, 18, 58, tone: c.subject, monastery: true)
        pillar(56, 20, 74, tone: c.subject.lightened(0.04), monastery: true)
        pillar(80, 15, 46, tone: c.subject.darkened(0.04), monastery: true)
        pineRow(s, from: -2, to: 100, base: g + 7, height: 7...12, color: c.deep.mixed(c.ground, 0.5), salt: 14)
    }

    // MARK: Cappadocia

    static func cappadocia(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let balloonTones = [c.tint, RGB(r: 0.86, g: 0.42, b: 0.33), c.sun.lightened(0.2), RGB(r: 0.45, g: 0.62, b: 0.78)]
        for (i, b) in [(24.0, 30.0, 8.0), (46.0, 18.0, 7.0), (74.0, 38.0, 9.0), (88.0, 20.0, 5.6)].enumerated() {
            let (x, y, r) = b
            var env = Path()
            env.move(to: pt(x - r * 0.35, y + r * 1.25))
            env.addCurve(to: pt(x - r, y), control1: pt(x - r * 0.45, y + r * 0.9), control2: pt(x - r, y + r * 0.6))
            env.addCurve(to: pt(x + r, y), control1: pt(x - r, y - r * 1.35), control2: pt(x + r, y - r * 1.35))
            env.addCurve(to: pt(x + r * 0.35, y + r * 1.25), control1: pt(x + r, y + r * 0.6), control2: pt(x + r * 0.45, y + r * 0.9))
            env.closeSubpath()
            p.fill(env, balloonTones[i % balloonTones.count])
            p.clipped(to: env) { q in
                q.rect(x - r * 0.3, y - r * 1.4, r * 0.28, r * 3, .white, opacity: 0.35)
                q.rect(x + r * 0.3, y - r * 1.4, r * 0.28, r * 3, c.deep, opacity: 0.2)
            }
            p.rect(x - r * 0.18, y + r * 1.5, r * 0.36, r * 0.34, c.deep)
        }
        // Rocky plateau
        p.fill(Path.ridge(points: [(-4, g - 4), (20, g - 14), (50, g - 8), (80, g - 16), (104, g - 6)], baseY: g + 2), c.hillNear.mixed(c.subject, 0.5))
        // Fairy chimneys
        var r = s.rng(181)
        let spots: [(Double, Double, Double)] = [(10, 30, 7), (22, 44, 9), (36, 26, 7), (48, 52, 11), (62, 34, 8), (74, 46, 9.5), (88, 28, 7)]
        for (x, h, w) in spots {
            var cone = Path()
            cone.move(to: pt(x - w, g + 3))
            cone.addQuadCurve(to: pt(x - w * 0.18, g - h + 5), control: pt(x - w * 0.5, g - h * 0.45))
            cone.addQuadCurve(to: pt(x + w * 0.18, g - h + 5), control: pt(x, g - h - 1))
            cone.addQuadCurve(to: pt(x + w, g + 3), control: pt(x + w * 0.5, g - h * 0.45))
            cone.closeSubpath()
            let tone = c.subject.mixed(c.light, r.range(0, 0.35))
            p.fill(cone, tone)
            p.shadeRight(cone, from: x, c.shade, opacity: 0.35)
            p.poly([(x - w * 0.34, g - h + 6), (x, g - h - 3), (x + w * 0.34, g - h + 6)], c.subject.darkened(0.18))
            if r.chance(0.6) { p.fillArch(cx: x - w * 0.15, y: g - h * 0.42, w: 1.8, h: 3.4, c.deep, opacity: 0.9) }
        }
    }

    // MARK: Waterfalls (Victoria, Niagara, Iguazú)

    static func waterfall(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let foam = RGB.white.mixed(c.skyBottom, 0.15)
        func curtain(_ x0: Double, _ x1: Double, top: Double, bottom: Double, salt: UInt64) {
            var r = s.rng(salt)
            var x = x0
            while x < x1 {
                let w = r.range(0.8, 2.4)
                p.rect(x, top, w, bottom - top, foam, opacity: r.range(0.55, 0.95))
                x += w + r.range(0, 0.7)
            }
        }
        func spray(_ x: Double, _ y: Double, _ w: Double) {
            for k in 0..<6 {
                p.ellipse(x + Double(k - 3) * w * 0.14, y - Double(k % 3) * 2.2, w * 0.22, 3 + Double(k % 2) * 1.5, foam, opacity: 0.55)
            }
        }
        switch s.variant {
        case 1:
            // Horseshoe
            let rim = Path { path in
                path.move(to: pt(-2, g - 30)); path.addQuadCurve(to: pt(102, g - 30), control: pt(50, g - 52))
                path.addLine(to: pt(102, g - 14)); path.addLine(to: pt(-2, g - 14)); path.closeSubpath()
            }
            p.fill(Path(CGRect(x: -2, y: g - 26, width: 104, height: 30)), c.subject.mixed(c.deep, 0.2))
            p.clipped(to: rim) { q in
                var r = s.rng(191)
                var x = -2.0
                while x < 102 {
                    let t = x / 100
                    let rimY = (1 - t) * (1 - t) * (g - 30) + 2 * t * (1 - t) * (g - 52) + t * t * (g - 30)
                    let w = r.range(0.9, 2.4)
                    q.rect(x, rimY + 1, w, g - 6 - rimY, foam, opacity: r.range(0.55, 0.95))
                    x += w + r.range(0, 0.6)
                }
            }
            spray(50, g - 4, 60)
            spray(18, g - 5, 30)
            // Maid of the Mist
            p.poly([(70, g + 10), (82, g + 10), (80, g + 13), (72, g + 13)], c.tint)
            p.rect(73.4, g + 6.6, 5, 3.4, .white)
        case 2:
            // Iguazú: many cascades between jungle islands
            for (x, w, top) in [(2.0, 20.0, g - 36), (28.0, 16.0, g - 44), (52.0, 22.0, g - 38), (80.0, 18.0, g - 42)] {
                p.rect(x - 1, top - 4, w + 2, 6, c.ground.mixed(c.deep, 0.35))
                curtain(x, x + w, top: top, bottom: g - 2, salt: UInt64(x * 7))
                spray(x + w / 2, g - 1, w + 6)
            }
            p.fill(Path.ridge(points: [(-4, g - 36), (24, g - 46), (46, g - 40), (76, g - 48), (104, g - 38)], baseY: g - 34), c.ground.mixed(c.deep, 0.45))
            for x in [24.0, 48.0, 76.0] { palm(p, x: x, base: g - 36, h: 14, lean: 2, color: c.deep) }
        default:
            // Victoria Falls: a mile-wide curtain with a gorge opposite
            p.rect(-2, g - 44, 104, 6, c.ground.mixed(c.deep, 0.4))
            p.rect(-2, g - 38, 104, 36, c.subject.mixed(c.deep, 0.25))
            curtain(2, 98, top: g - 38, bottom: g - 2, salt: 193)
            spray(30, g - 2, 40)
            spray(70, g - 3, 40)
            pineRow(s, from: -2, to: 100, base: g - 38, height: 6...11, color: c.deep.mixed(c.ground, 0.4), salt: 15)
            // Rainbow in the spray
            for (i, col) in [RGB(r: 0.95, g: 0.45, b: 0.4), RGB(r: 0.97, g: 0.8, b: 0.4), RGB(r: 0.5, g: 0.8, b: 0.6), RGB(r: 0.45, g: 0.6, b: 0.9)].enumerated() {
                var arc = Path()
                arc.addArc(center: pt(62, g - 2), radius: 28 - Double(i) * 1.1, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                p.stroke(arc, width: 1.0, col, opacity: 0.5, cap: .butt)
            }
        }
    }

    // MARK: Statue of Liberty

    static func statueOfLiberty(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            // Star fort base
            q.poly([(26, g + 1), (32, g - 5), (68, g - 5), (74, g + 1)], c.subject.darkened(0.1))
            // Pedestal
            q.poly([(34, g - 5), (36, g - 20), (64, g - 20), (66, g - 5)], c.light)
            q.rect(36, g - 22, 28, 2.4, c.light.darkened(0.08))
            q.rect(39, g - 34, 22, 12, c.light)
            q.shadeRight(Path(CGRect(x: 39, y: g - 34, width: 22, height: 12)), from: 52, c.shade, opacity: 0.25)
            q.rect(38, g - 35.4, 24, 1.8, c.light.darkened(0.06))
            for k in 0..<3 { q.clearRect(41.6 + Double(k) * 7, g - 31, 2.4, 6) }
            // Robe
            let robe = Path { path in
                path.move(to: pt(41, g - 35))
                path.addQuadCurve(to: pt(44.6, g - 66), control: pt(41, g - 52))
                path.addLine(to: pt(54.6, g - 66))
                path.addQuadCurve(to: pt(59, g - 35), control: pt(59, g - 52))
                path.closeSubpath()
            }
            q.fill(robe, c.subject)
            q.shadeRight(robe, from: 52, c.shade, opacity: 0.4)
            q.clipped(to: robe) { clip in
                for k in 0..<5 { clip.line(44 + Double(k) * 3, g - 66, 42 + Double(k) * 3.6, g - 35, width: 0.45, c.deep, opacity: 0.3) }
            }
            // Raised arm and torch
            q.poly([(53.4, g - 64), (56.6, g - 62.4), (60.6, g - 90), (57.8, g - 91)], c.subject)
            q.rect(57, g - 94, 4.8, 3.6, c.subject.darkened(0.1))
            var flame = Path()
            flame.move(to: pt(57.6, g - 94))
            flame.addQuadCurve(to: pt(59.4, g - 103), control: pt(56.4, g - 99))
            flame.addQuadCurve(to: pt(61.2, g - 94), control: pt(62.6, g - 99))
            flame.closeSubpath()
            q.fill(flame, c.sun)
            // Tablet arm
            q.poly([(44.6, g - 62), (47, g - 64), (42.4, g - 56), (39.8, g - 56)], c.subject)
            q.rect(37.4, g - 60, 6.4, 9, c.subject.lightened(0.05))
            // Head and crown
            q.circle(49.6, g - 70, 3.6, c.subject)
            q.circle(49.6, g - 69.4, 2.4, c.subject.darkened(0.06))
            for k in 0..<7 {
                let a = (Double(k) - 3) * 0.34 - .pi / 2
                q.line(49.6 + cos(a) * 3.4, g - 71 + sin(a) * 3.4, 49.6 + cos(a) * 7.6, g - 71 + sin(a) * 7.4, width: 0.8, c.subject)
            }
        }
        s.mirror(opacity: 0.22) { render($0) }
        render(p)
        // Manhattan skyline across the harbour
        var r = s.rng(201)
        var x = -2.0
        while x < 100 {
            let w = r.range(4, 8), h = r.range(6, 18)
            if x > 22 && x < 78 { x += w + 0.4; continue }
            p.rect(x, g - h, w, h + 1, c.hillFar.mixed(c.subject, 0.3))
            x += w + 0.4
        }
    }

    // MARK: Golden Gate

    static func suspensionBridge(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Far headland
        p.fill(Path.ridge(points: [(60, g), (74, g - 18), (92, g - 24), (104, g - 12)], baseY: g + 1), c.hillFar.mixed(c.ground, 0.4))
        func render(_ q: ArtPen) {
            let deckY = g - 12
            for tx in [30.0, 72.0] {
                q.rect(tx - 2.2, g - 66, 1.8, 66 + 6, c.subject)
                q.rect(tx + 0.4, g - 66, 1.8, 66 + 6, c.subject)
                q.shadeRight(Path(CGRect(x: tx - 2.2, y: g - 66, width: 4.4, height: 72)), from: tx, c.shade, opacity: 0.35)
                for ty in [-62.0, -48.0, -34.0, -22.0] { q.rect(tx - 2.2, g + ty, 4.4, 2.4, c.subject) }
                q.rect(tx - 2.8, g - 67.4, 5.6, 1.8, c.subject)
            }
            // Deck
            q.rect(-2, deckY, 104, 2.2, c.subject)
            q.rect(-2, deckY + 2.2, 104, 1, c.deep, opacity: 0.5)
            // Main cables
            var cable = Path()
            cable.move(to: pt(-2, g - 24))
            cable.addQuadCurve(to: pt(30, g - 66), control: pt(14, g - 36))
            cable.addQuadCurve(to: pt(72, g - 66), control: pt(51, g - 12))
            cable.addQuadCurve(to: pt(102, g - 22), control: pt(88, g - 36))
            q.stroke(cable, width: 1.1, c.subject)
            // Suspenders
            var x = 33.0
            while x < 70 {
                let t = (x - 30) / 42
                let y = (1 - t) * (1 - t) * (g - 66) + 2 * t * (1 - t) * (g - 12) + t * t * (g - 66)
                q.line(x, y, x, deckY, width: 0.35, c.subject, opacity: 0.85)
                x += 3
            }
            for sx in stride(from: 2.0, to: 28.0, by: 3.0) {
                let t = (sx + 2) / 32
                let y = (1 - t) * (1 - t) * (g - 24) + 2 * t * (1 - t) * (g - 36) + t * t * (g - 66)
                q.line(sx, y, sx, deckY, width: 0.35, c.subject, opacity: 0.85)
            }
            for sx in stride(from: 75.0, to: 100.0, by: 3.0) {
                let t = (sx - 72) / 30
                let y = (1 - t) * (1 - t) * (g - 66) + 2 * t * (1 - t) * (g - 36) + t * t * (g - 22)
                q.line(sx, y, sx, deckY, width: 0.35, c.subject, opacity: 0.85)
            }
        }
        s.mirror(opacity: 0.22) { render($0) }
        render(p)
        // Fog rolling through the towers
        mist(p, y: g - 36, color: .white, opacity: 0.4, salt: 23)
        mist(p, y: g - 22, color: .white, opacity: 0.35, salt: 24)
    }

    // MARK: Grand Canyon

    static func canyon(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Distant far rim
        p.rect(-2, g - 34, 104, 36, c.hillFar.mixed(c.subject, 0.35))
        var r = s.rng(211)
        // Buttes
        for (x, w, h) in [(34.0, 12.0, 26.0), (56.0, 16.0, 34.0), (74.0, 10.0, 20.0)] {
            let tone = c.subject.mixed(c.shade, 0.25)
            p.poly([(x - w / 2, g + 1), (x - w / 2 + 1.4, g - h), (x + w / 2 - 1.4, g - h), (x + w / 2, g + 1)], tone)
            p.shadeRight(Path(CGRect(x: x - w / 2, y: g - h, width: w, height: h + 1)), from: x + 1, c.shade, opacity: 0.35)
            var y = g - h + 4
            while y < g {
                p.rect(x - w / 2, y, w, 0.7, c.deep, opacity: 0.2)
                y += r.range(3, 5)
            }
        }
        // Strata on the near walls
        let layers: [RGB] = [c.subject, c.subject.mixed(c.tint, 0.4), c.subject.mixed(c.sun, 0.3), c.subject.darkened(0.12), c.subject.mixed(c.tint, 0.25)]
        func wall(left: Bool) {
            // Each band is a strata layer; the canyon narrows as it deepens.
            let bands: [(width: Double, top: Double)] = [(18, 36), (26, 46), (32, 56), (38, 66), (42, 78)]
            for (i, band) in bands.enumerated() {
                let bottom = i + 1 < bands.count ? bands[i + 1].top : g + 2
                let x = left ? -2 : 100 - band.width
                p.rect(x, band.top, band.width + 2, bottom - band.top,
                       layers[i % layers.count].mixed(c.shade, left ? 0 : 0.18))
                p.rect(x, band.top, band.width + 2, 0.8, c.light, opacity: 0.35)
            }
        }
        wall(left: true)
        wall(left: false)
        // The Colorado River
        var river = Path()
        river.move(to: pt(42, g + 1))
        river.addQuadCurve(to: pt(58, g + 1), control: pt(50, g - 5))
        p.stroke(river, width: 2.4, c.tint, opacity: 0.85)
        // Condor
        p.poly([(24, 22), (30, 19), (36, 22), (30, 21)], c.deep)
    }

    // MARK: Mountain lakes (Lake Louise, Milford Sound)

    static func lakeReflection(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            let outline: [(Double, Double)]
            if s.variant == 1 {
                outline = [(-4, g + 1), (14, g - 22), (30, g - 40), (44, g - 66), (48, g - 72), (52, g - 64), (62, g - 42), (76, g - 26), (104, g + 1)]
            } else {
                outline = [(-4, g + 1), (10, g - 30), (22, g - 58), (30, g - 46), (42, g - 74), (50, g - 56), (60, g - 66), (74, g - 40), (88, g - 28), (104, g + 1)]
            }
            let path = Path { path in
                path.move(to: pt(outline[0].0, outline[0].1))
                for p2 in outline.dropFirst() { path.addLine(to: pt(p2.0, p2.1)) }
                path.closeSubpath()
            }
            q.fill(path, c.subject)
            q.shadeRight(path, from: s.variant == 1 ? 48 : 46, c.shade, opacity: 0.4)
            q.clipped(to: path) { clip in
                var snow = Path()
                let cap = s.variant == 1 ? g - 48 : g - 52
                snow.move(to: pt(0, 0)); snow.addLine(to: pt(100, 0)); snow.addLine(to: pt(100, cap))
                var x = 100.0
                var up = false
                while x > 0 { snow.addLine(to: pt(x, cap + (up ? -3 : 4))); x -= 6; up.toggle() }
                snow.closeSubpath()
                clip.fill(snow, RGB.white.mixed(c.skyBottom, 0.1), opacity: 0.9)
            }
            // Shoreline conifers
            pineRow(s, on: q, from: -2, to: 34, base: g + 1, height: 10...18, color: c.deep.mixed(c.ground, 0.45), salt: 16)
            pineRow(s, on: q, from: 66, to: 102, base: g + 1, height: 10...18, color: c.deep.mixed(c.ground, 0.45), salt: 17)
        }
        s.mirror(opacity: 0.5) { render($0) }
        render(p)
        if s.variant == 0 {
            // Red canoes at the dock
            p.poly([(44, g + 9), (58, g + 9), (55.4, g + 11.4), (46.6, g + 11.4)], RGB(r: 0.78, g: 0.25, b: 0.2))
            p.poly([(62, g + 14), (74, g + 14), (72, g + 16), (64, g + 16)], RGB(r: 0.78, g: 0.25, b: 0.2))
        }
    }

    // MARK: Chichén Itzá

    static func mayanPyramid(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Jungle behind
        var r = s.rng(221)
        for _ in 0..<18 {
            p.circle(r.range(-2, 102), g - r.range(2, 12), r.range(5, 9), c.ground.mixed(c.deep, 0.5), opacity: 0.95)
        }
        // Nine terraces
        for i in 0..<9 {
            let w = 64 - Double(i) * 5.4
            let y = g - Double(i + 1) * 4.6
            p.rect(50 - w / 2, y, w, 5, i % 2 == 0 ? c.subject : c.subject.lightened(0.05))
            p.rect(50 - w / 2, y, w, 0.8, c.light, opacity: 0.6)
            p.shadeRight(Path(CGRect(x: 50 - w / 2, y: y, width: w, height: 5)), from: 50, c.shade, opacity: 0.2)
        }
        // Stairway
        p.poly([(45, g + 1), (55, g + 1), (52.6, g - 42), (47.4, g - 42)], c.light)
        for k in 0..<10 { p.rect(46 + Double(k) * 0.2, g - Double(k) * 4.2 - 1, 8 - Double(k) * 0.4, 0.55, c.deep, opacity: 0.3) }
        // Temple
        let tx = 50.0, ty = g - 41.4 - 9.0
        p.rect(tx - 9, ty, 18, 9, c.subject.lightened(0.06))
        p.rect(tx - 10, ty - 1.6, 20, 1.8, c.light)
        p.rect(tx - 5, ty - 5, 10, 4, c.subject)
        p.clearArch(cx: tx, y: ty + 2.4, w: 4.6, h: 6.6)
        p.fillArch(cx: tx, y: ty + 2.4, w: 4.6, h: 6.6, c.deep, opacity: 0.9)
        // Foreground palms
        palm(p, x: 8, base: g + 10, h: 34, lean: 4, color: c.deep)
        palm(p, x: 94, base: g + 10, h: 28, lean: -4, color: c.deep)
    }

    // MARK: Old Faithful

    static func geyser(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        pineRow(s, from: -4, to: 40, base: g + 1, height: 16...30, color: c.deep.mixed(c.ground, 0.4), salt: 18)
        pineRow(s, from: 62, to: 104, base: g + 1, height: 16...30, color: c.deep.mixed(c.ground, 0.4), salt: 19)
        // Cone mound
        let mound = Path.ridge(points: [(24, g + 4), (40, g - 2), (50, g - 6), (60, g - 2), (76, g + 4)], baseY: g + 6)
        p.fill(mound, c.subject.mixed(c.light, 0.3))
        // Eruption plume
        var r = s.rng(231)
        for i in 0..<16 {
            let t = Double(i) / 15
            let y = g - 6 - t * 66
            let w = 1.6 + t * 8.5
            let drift = t * t * 9
            p.ellipse(50 + drift + r.range(-1.2, 1.2), y, w, 2.6 + t * 3.4, RGB.white.mixed(c.skyBottom, 0.1), opacity: 0.92 - t * 0.35)
        }
        for _ in 0..<14 {
            p.circle(50 + r.range(-6, 14), g - r.range(34, 78), r.range(1.2, 3), .white, opacity: 0.55)
        }
        // Boardwalk and visitors
        p.poly([(8, g + 12), (92, g + 12), (92, g + 14.4), (8, g + 14.4)], c.light, opacity: 0.8)
        for x in [20.0, 28.0, 66.0, 74.0, 80.0] { figure(p, x: x, base: g + 12, h: 5, color: c.deep) }
    }

    // MARK: French Quarter

    static func balconyRow(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let tones = [c.tint, c.sun.mixed(c.subject, 0.25).lightened(0.15), c.subject, c.light.mixed(c.tint, 0.3), RGB(r: 0.55, g: 0.66, b: 0.62)]
        var x = -2.0
        var i = 0
        while x < 100 {
            let w = i % 2 == 0 ? 25.0 : 22.0
            let top = g - 62 + Double(i % 3) * 3
            let tone = tones[i % tones.count]
            p.rect(x, top, w, g - top + 1, tone)
            p.rect(x + w - 2.2, top, 2.2, g - top + 1, tone.darkened(0.18))
            p.rect(x - 0.4, top - 1.6, w + 0.8, 1.8, tone.lightened(0.28))
            // Upper floors: shuttered windows
            for row in 0..<2 {
                for col in 0..<2 {
                    let wx = x + 3.2 + Double(col) * (w * 0.46)
                    let wy = top + 5 + Double(row) * 17
                    p.fillArch(cx: wx + 2.2, y: wy, w: 4.4, h: 11.5, c.deep, opacity: 0.9)
                    p.rect(wx - 0.6, wy + 3, 1.3, 8, tone.darkened(0.28))
                    p.rect(wx + 3.9, wy + 3, 1.3, 8, tone.darkened(0.28))
                }
                // Iron gallery
                let gy = top + 17 + Double(row) * 17 + 2.6
                p.rect(x - 1, gy, w + 2, 0.8, c.deep)
                var bx = x
                while bx < x + w { p.line(bx, gy + 0.8, bx, gy + 4.2, width: 0.4, c.deep); bx += 1.6 }
                p.rect(x - 1, gy + 4.2, w + 2, 0.7, c.deep)
            }
            // Ground floor arches
            for col in 0..<2 { p.fillArch(cx: x + 6 + Double(col) * (w * 0.5), y: g - 14, w: 5.2, h: 14.5, c.deep, opacity: 0.88) }
            x += w
            i += 1
        }
        // Gas lamp
        p.rect(88.6, g - 30, 0.9, 38, c.deep)
        p.poly([(86.8, g - 30), (91.2, g - 30), (90.2, g - 36), (87.8, g - 36)], c.deep)
        p.circle(89, g - 33, 3.6, c.sun, opacity: 0.35)
        p.rect(87.9, g - 34.6, 2.2, 3.8, c.sun)
    }

    // MARK: Island beaches

    static func palmBeach(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        switch s.variant {
        case 1:
            // Bora Bora: volcanic peak, motu and bungalows
            p.fill(Path.ridge(points: [(-4, g), (8, g - 6), (20, g - 3)], baseY: g + 1), c.ground.mixed(c.deep, 0.35))
            let peak = Path { path in
                path.move(to: pt(30, g + 1)); path.addLine(to: pt(38, g - 32)); path.addLine(to: pt(44, g - 54))
                path.addLine(to: pt(48, g - 58)); path.addLine(to: pt(54, g - 44)); path.addLine(to: pt(62, g - 24)); path.addLine(to: pt(76, g + 1))
                path.closeSubpath()
            }
            func render(_ q: ArtPen) {
                q.fill(peak, c.subject)
                q.shadeRight(peak, from: 48, c.shade, opacity: 0.45)
                q.clipped(to: peak) { clip in
                    for k in 0..<7 { clip.line(36 + Double(k) * 4, g - 56, 33 + Double(k) * 6, g + 1, width: 0.6, c.deep, opacity: 0.3) }
                    clip.rect(30, g - 8, 50, 10, c.ground.mixed(c.deep, 0.3), opacity: 0.9)
                }
                q.fill(Path.ridge(points: [(60, g + 2), (70, g - 4), (82, g - 6), (96, g - 2), (104, g + 2)], baseY: g + 2), c.ground.mixed(c.deep, 0.3))
            }
            s.mirror(opacity: 0.3) { render($0) }
            render(p)
            // Overwater bungalows on a jetty
            p.rect(-2, g + 12, 70, 1.4, c.deep)
            for k in 0..<5 {
                let x = 6.0 + Double(k) * 13
                p.rect(x, g + 6.4, 8, 5.6, c.light)
                p.poly([(x - 1.6, g + 6.4), (x + 4, g + 0.6), (x + 9.6, g + 6.4)], c.subject.mixed(c.sun, 0.35))
                for lx in [x + 0.6, x + 6.8] { p.rect(lx, g + 12, 0.6, 3.8, c.deep) }
                p.rect(x + 3, g + 8.4, 2, 3.6, c.deep, opacity: 0.7)
            }
            palm(p, x: 84, base: g + 8, h: 26, lean: -4, color: c.deep)
        case 2:
            // Diamond Head crater above Waikiki
            let crater = Path.ridge(points: [(-4, g + 1), (8, g - 8), (28, g - 22), (50, g - 31), (62, g - 28), (80, g - 12), (104, g + 1)], baseY: g + 2)
            func render(_ q: ArtPen) {
                q.fill(crater, c.subject)
                q.shadeRight(crater, from: 56, c.shade, opacity: 0.4)
                q.clipped(to: crater) { clip in
                    var r = s.rng(241)
                    for _ in 0..<18 {
                        let x = r.range(0, 100)
                        clip.line(x, g - 32, x + r.range(-4, 6), g + 2, width: r.range(0.5, 1.2), c.deep, opacity: 0.25)
                    }
                }
            }
            s.mirror(opacity: 0.18) { render($0) }
            render(p)
            // Sand and palms
            p.fill(Path.ridge(points: [(-4, g + 8), (30, g + 5), (70, g + 8), (104, g + 6)], baseY: 131), RGB.white.mixed(c.sun, 0.45), opacity: 1)
            palm(p, x: 14, base: g + 16, h: 40, lean: 6, color: c.deep)
            palm(p, x: 88, base: g + 16, h: 34, lean: -5, color: c.deep)
        default:
            // Whitehaven: swirling sand and turquoise
            p.fill(Path.ridge(points: [(-4, g - 2), (10, g - 12), (26, g - 6), (40, g)], baseY: g + 1), c.ground.mixed(c.deep, 0.35))
            p.fill(Path.ridge(points: [(60, g), (76, g - 9), (92, g - 4), (104, g - 8)], baseY: g + 1), c.ground.mixed(c.deep, 0.35))
            var r = s.rng(242)
            for k in 0..<5 {
                var swirl = Path()
                let y = g + 4 + Double(k) * 7
                swirl.move(to: pt(-4, y + 2))
                swirl.addCurve(to: pt(104, y), control1: pt(30, y + 10 - Double(k) * 1.4), control2: pt(60, y - 12 + Double(k) * 1.6))
                p.stroke(swirl, width: 3.6 - Double(k) * 0.3, RGB.white.mixed(c.sun, 0.25), opacity: 0.85 - Double(k) * 0.1)
                _ = r.unit()
            }
            var tide = Path()
            tide.move(to: pt(-4, g + 16))
            tide.addCurve(to: pt(104, g + 12), control1: pt(24, g + 30), control2: pt(66, g + 2))
            p.stroke(tide, width: 7, c.tint, opacity: 0.45)
            palm(p, x: 8, base: g + 3, h: 24, lean: 4, color: c.deep)
            palm(p, x: 16, base: g + 3, h: 18, lean: -2, color: c.deep)
        }
    }

    // MARK: Machu Picchu

    static func machuPicchu(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Misty background ridge
        p.fill(Path.ridge(points: [(-4, g - 10), (14, g - 40), (30, g - 52), (44, g - 34), (60, g - 16)], baseY: g + 2), c.hillFar.mixed(c.subject, 0.4))
        // Huayna Picchu
        let peak = Path { path in
            path.move(to: pt(48, g + 1)); path.addLine(to: pt(56, g - 30)); path.addLine(to: pt(62, g - 58)); path.addLine(to: pt(67, g - 66))
            path.addLine(to: pt(72, g - 54)); path.addLine(to: pt(80, g - 28)); path.addLine(to: pt(94, g + 1))
            path.closeSubpath()
        }
        p.fill(peak, c.subject)
        p.shadeRight(peak, from: 66, c.shade, opacity: 0.45)
        p.clipped(to: peak) { q in
            var r = s.rng(251)
            for _ in 0..<14 {
                let x = r.range(52, 92)
                q.line(x, g - 66, x + r.range(-6, 6), g + 1, width: 0.6, c.deep, opacity: 0.28)
            }
        }
        mist(p, y: g - 28, color: .white, opacity: 0.55, salt: 31)
        // Agricultural terraces
        for i in 0..<7 {
            let y = g - 24 + Double(i) * 4.2
            var terrace = Path()
            terrace.move(to: pt(-4, y + 6))
            terrace.addQuadCurve(to: pt(70, y - 2 + Double(i)), control: pt(30, y - 6))
            terrace.addLine(to: pt(70, y + 6)); terrace.addLine(to: pt(-4, y + 6)); terrace.closeSubpath()
            p.fill(terrace, i % 2 == 0 ? c.ground : c.ground.lightened(0.14))
            p.stroke(Path { path in
                path.move(to: pt(-4, y + 6)); path.addQuadCurve(to: pt(70, y - 2 + Double(i)), control: pt(30, y - 6))
            }, width: 0.9, c.light, opacity: 0.8, cap: .butt)
        }
        // Stone houses with thatch
        for (x, y) in [(18.0, g - 8.0), (28.0, g - 4.0), (40.0, g - 9.0), (50.0, g - 2.0)] {
            p.rect(x, y, 7, 4.4, c.light)
            p.poly([(x - 1, y), (x + 3.5, y - 3.8), (x + 8, y)], c.tint.mixed(c.sun, 0.5))
        }
        // Llama
        let lx = 82.0, ly = g + 15.0
        p.ellipse(lx, ly - 6, 5.2, 2.6, c.deep)
        for dx in [-3.4, -1.6, 2.0, 3.8] { p.rect(lx + dx - 0.3, ly - 5, 0.7, 6, c.deep) }
        p.poly([(lx - 4, ly - 7), (lx - 5.6, ly - 14), (lx - 4.2, ly - 14.4), (lx - 2.6, ly - 8)], c.deep)
        p.ellipse(lx - 5.4, ly - 15, 1.6, 1.1, c.deep)
        p.poly([(lx - 6, ly - 16), (lx - 5.7, ly - 18.4), (lx - 5.0, ly - 16.2)], c.deep)
    }

    // MARK: Christ the Redeemer

    static func christRedeemer(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Sugarloaf in the distance
        p.fill(Path.ridge(points: [(70, g), (80, g - 16), (90, g - 18), (100, g - 6), (106, g)], baseY: g + 1), c.hillFar.mixed(c.subject, 0.4))
        // Corcovado
        let mtn = Path.ridge(points: [(-4, g + 1), (14, g - 18), (32, g - 36), (46, g - 44), (54, g - 44), (68, g - 34), (86, g - 16), (104, g + 1)], baseY: g + 2)
        p.fill(mtn, c.subject)
        p.shadeRight(mtn, from: 56, c.shade, opacity: 0.4)
        pineRow(s, from: 4, to: 96, base: g + 3, height: 8...14, color: c.deep.mixed(c.ground, 0.5), salt: 20)
        // Statue
        let bx = 50.0, by = g - 43.0
        p.rect(bx - 4.6, by - 5, 9.2, 6, c.light.darkened(0.08))
        p.rect(bx - 3.6, by - 9, 7.2, 4.6, c.light)
        let robe = Path { path in
            path.move(to: pt(bx - 3.2, by - 9)); path.addLine(to: pt(bx - 1.3, by - 31)); path.addLine(to: pt(bx + 1.3, by - 31)); path.addLine(to: pt(bx + 3.2, by - 9)); path.closeSubpath()
        }
        p.fill(robe, c.light)
        p.shadeRight(robe, from: bx, c.shade, opacity: 0.25)
        // Outstretched arms
        p.poly([(bx - 19, by - 27), (bx - 1.4, by - 31.4), (bx + 1.4, by - 31.4), (bx + 19, by - 27), (bx + 19, by - 24.8), (bx + 1.4, by - 28.4), (bx - 1.4, by - 28.4), (bx - 19, by - 24.8)], c.light)
        p.circle(bx, by - 34, 2.1, c.light)
        // Cloud wisp through the summit
        p.ellipse(34, by + 2, 14, 2.2, .white, opacity: 0.6)
        p.ellipse(68, by - 4, 12, 2, .white, opacity: 0.55)
    }

    // MARK: Sydney Opera House

    static func operaHouse(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Harbour Bridge in the distance
        var arch = Path()
        arch.move(to: pt(60, g - 2))
        arch.addQuadCurve(to: pt(104, g - 2), control: pt(82, g - 36))
        p.stroke(arch, width: 1.6, c.hillFar.mixed(c.subject, 0.4), cap: .butt)
        p.rect(60, g - 6, 44, 1.2, c.hillFar.mixed(c.subject, 0.4))
        func shell(_ q: ArtPen, _ x0: Double, _ x1: Double, _ peakX: Double, _ peakY: Double, tone: RGB) {
            let base = g - 4
            var path = Path()
            path.move(to: pt(x0, base))
            path.addCurve(to: pt(peakX, peakY), control1: pt(x0 + 1, peakY + (base - peakY) * 0.5), control2: pt(peakX - (peakX - x0) * 0.55, peakY + 8))
            path.addQuadCurve(to: pt(x1, base), control: pt(peakX + (x1 - peakX) * 0.5, base - (base - peakY) * 0.45))
            path.closeSubpath()
            q.fill(path, tone)
            q.shadeRight(path, from: peakX, c.shade, opacity: 0.22)
            q.clipped(to: path) { clip in
                for k in 1..<6 {
                    let t = Double(k) / 6
                    clip.line(peakX, peakY + 1, lerp(x0, x1, t), base, width: 0.3, c.deep, opacity: 0.22)
                }
            }
        }
        func render(_ q: ArtPen) {
            q.rect(6, g - 5, 90, 6, c.shade)
            q.rect(2, g - 1, 98, 3, c.subject.darkened(0.15))
            // Concert hall shells (left cluster)
            shell(q, 10, 38, 28, g - 40, tone: c.light)
            shell(q, 16, 46, 38, g - 34, tone: c.light.mixed(c.subject, 0.1))
            shell(q, 24, 54, 47, g - 28, tone: c.light)
            // Opera theatre shells (right cluster)
            shell(q, 52, 82, 70, g - 38, tone: c.light)
            shell(q, 62, 92, 82, g - 30, tone: c.light.mixed(c.subject, 0.1))
            shell(q, 72, 98, 92, g - 22, tone: c.light)
            // Small restaurant shell
            shell(q, 0, 14, 8, g - 14, tone: c.light)
        }
        s.mirror(opacity: 0.28) { render($0) }
        render(p)
        // Ferry
        p.poly([(10, g + 14), (30, g + 14), (27, g + 17.4), (13, g + 17.4)], c.deep)
        p.rect(14, g + 10.6, 11, 3.4, c.light)
    }

    // MARK: Uluru

    static func monolith(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        var rock = Path()
        rock.move(to: pt(-2, g + 2))
        rock.addCurve(to: pt(18, g - 22), control1: pt(2, g - 10), control2: pt(8, g - 20))
        rock.addCurve(to: pt(52, g - 30), control1: pt(28, g - 28), control2: pt(40, g - 32))
        rock.addCurve(to: pt(84, g - 22), control1: pt(66, g - 30), control2: pt(76, g - 28))
        rock.addCurve(to: pt(102, g + 2), control1: pt(94, g - 16), control2: pt(100, g - 8))
        rock.closeSubpath()
        p.fill(rock, c.subject)
        p.shadeRight(rock, from: 66, c.shade, opacity: 0.45)
        p.lightLeft(rock, to: 38, c.light, opacity: 0.25)
        p.clipped(to: rock) { q in
            var r = s.rng(261)
            for _ in 0..<16 {
                let x = r.range(6, 96)
                var f = Path()
                f.move(to: pt(x, g - 30))
                f.addQuadCurve(to: pt(x + r.range(-6, 6), g + 2), control: pt(x + r.range(-3, 3), g - 14))
                q.stroke(f, width: r.range(0.6, 1.5), c.deep, opacity: 0.28, cap: .butt)
            }
        }
        // Desert scrub
        var r = s.rng(262)
        for _ in 0..<28 {
            p.circle(r.range(-2, 102), g + r.range(0, 4), r.range(1.2, 2.6), c.ground.mixed(c.deep, 0.5), opacity: 0.9)
        }
        figure(p, x: 28, base: g + 16, h: 5, color: c.deep)
        figure(p, x: 34, base: g + 18, h: 5.4, color: c.deep)
    }
}
