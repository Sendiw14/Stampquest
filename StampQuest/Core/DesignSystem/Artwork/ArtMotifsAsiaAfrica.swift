import SwiftUI

// Asia, the Middle East and Africa.
nonisolated extension ArtMotifs {
    // MARK: Maiden's Tower, Istanbul

    static func maidenTower(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func mosque(_ q: ArtPen, cx: Double, scale k: Double, minarets: [Double]) {
            var dome = Path()
            dome.addArc(center: pt(cx, g - 7 * k), radius: 9 * k, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            dome.closeSubpath()
            q.fill(dome, c.subject)
            for dx in [-8.0, 8.0] {
                var half = Path()
                half.addArc(center: pt(cx + dx * k, g - 4 * k), radius: 5 * k, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                half.closeSubpath()
                q.fill(half, c.subject.darkened(0.08))
            }
            q.rect(cx - 13 * k, g - 5 * k, 26 * k, 6 * k, c.subject.darkened(0.1))
            for mx in minarets {
                q.rect(mx - 0.9 * k, g - 30 * k, 1.8 * k, 31 * k, c.subject.lightened(0.05))
                q.rect(mx - 1.6 * k, g - 21 * k, 3.2 * k, 1.1 * k, c.subject)
                q.poly([(mx - 1.2 * k, g - 30 * k), (mx, g - 37 * k), (mx + 1.2 * k, g - 30 * k)], c.shade)
            }
        }
        func render(_ q: ArtPen) {
            // Far shore skyline
            q.poly([(-4, g + 1), (-4, g - 3), (104, g - 3), (104, g + 1)], c.hillNear.darkened(0.12))
            mosque(q, cx: 18, scale: 1.0, minarets: [4, 33])
            mosque(q, cx: 86, scale: 0.7, minarets: [98])
            // Islet
            q.fill(Path.ridge(points: [(34, g + 3), (40, g - 4), (50, g - 8), (60, g - 4), (66, g + 3)], baseY: g + 4), c.shade)
            q.poly([(40, g - 2), (60, g - 2), (62, g + 1), (38, g + 1)], c.deep, opacity: 0.5)
            // Tower
            let body = Path(CGRect(x: 45, y: g - 30, width: 10, height: 24))
            q.fill(body, c.light)
            q.shadeRight(body, from: 51, c.shade, opacity: 0.3)
            q.rect(43.2, g - 33, 13.6, 3, c.subject)
            var dome = Path()
            dome.addArc(center: pt(50, g - 33), radius: 5.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            dome.closeSubpath()
            q.fill(dome, c.tint)
            q.rect(49.5, g - 42, 1, 4, c.deep)
            q.circle(50, g - 43, 0.9, c.sun)
            q.clearArch(cx: 50, y: g - 25, w: 3, h: 7)
        }
        s.mirror(opacity: 0.28) { render($0) }
        render(p)
        // A ferry crossing
        p.poly([(6, g + 13), (24, g + 13), (21, g + 16.5), (9, g + 16.5)], c.deep)
        p.rect(10, g + 9.5, 9, 3.5, c.light)
    }

    // MARK: Fushimi Inari

    static func torii(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Wooded slopes
        pineRow(s, from: -2, to: 34, base: g + 3, height: 20...34, color: c.deep.mixed(c.ground, 0.35), salt: 8)
        pineRow(s, from: 66, to: 102, base: g + 3, height: 20...34, color: c.deep.mixed(c.ground, 0.35), salt: 9)
        // Pathway
        p.poly([(36, 131), (64, 131), (53, g), (47, g)], c.light, opacity: 0.35)
        // Gates, far to near
        for i in (0..<6).reversed() {
            let k = 1 - Double(i) * 0.16
            let base = g + 16 - Double(i) * 3.4
            let h = 54 * k, half = 17.5 * k, pillar = 4.6 * k
            let top = base - h
            let tone = i % 2 == 0 ? c.subject : c.subject.darkened(0.08)
            p.rect(50 - half - pillar / 2, top, pillar, h, tone)
            p.rect(50 + half - pillar / 2, top, pillar, h, tone)
            p.rect(50 - half - pillar / 2, base - 5 * k, pillar, 5 * k, c.deep)
            p.rect(50 + half - pillar / 2, base - 5 * k, pillar, 5 * k, c.deep)
            // Nuki (lower beam)
            p.rect(50 - half - pillar * 1.2, top + 13 * k, 2 * half + pillar * 2.4, 3.2 * k, tone)
            // Kasagi (upswept top beam) and shimaki
            let ext = half + pillar * 2.3
            p.poly([(50 - ext - 1.5 * k, top - 3.2 * k), (50 - ext + 3 * k, top + 4.2 * k),
                    (50 + ext - 3 * k, top + 4.2 * k), (50 + ext + 1.5 * k, top - 3.2 * k),
                    (50 + ext - 1 * k, top - 1.0 * k), (50 - ext + 1 * k, top - 1.0 * k)], c.deep)
            p.rect(50 - ext + 2 * k, top + 3.0 * k, 2 * ext - 4 * k, 2.4 * k, tone)
        }
        // Lanterns of light through the gates
        p.circle(50, g - 8, 1.2, c.sun, opacity: 0.6)
    }

    // MARK: Mount Fuji

    static func fuji(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            var cone = Path()
            cone.move(to: pt(-4, g + 1))
            cone.addCurve(to: pt(43, g - 56), control1: pt(26, g - 6), control2: pt(36, g - 36))
            cone.addQuadCurve(to: pt(57, g - 56), control: pt(50, g - 60))
            cone.addCurve(to: pt(104, g + 1), control1: pt(64, g - 36), control2: pt(74, g - 6))
            cone.closeSubpath()
            q.fill(cone, c.subject)
            q.shadeRight(cone, from: 52, c.shade, opacity: 0.32)
            q.clipped(to: cone) { clip in
                clip.poly([(30, g - 70), (70, g - 70), (70, g - 44), (63, g - 39), (58, g - 46), (54, g - 36),
                           (50, g - 45), (46, g - 35), (42, g - 46), (37, g - 38), (30, g - 44)], RGB.white.mixed(c.skyBottom, 0.12))
                clip.poly([(50, g - 70), (70, g - 70), (70, g - 44), (63, g - 39), (58, g - 46), (54, g - 36), (50, g - 45)],
                          c.skyTop, opacity: 0.18)
            }
        }
        s.mirror(opacity: 0.35) { render($0) }
        render(p)
        // Cherry blossom branch in the foreground
        var r = s.rng(51)
        var branch = Path()
        branch.move(to: pt(-2, g - 36))
        branch.addQuadCurve(to: pt(34, g - 52), control: pt(14, g - 40))
        p.stroke(branch, width: 1.2, c.deep)
        for _ in 0..<26 {
            let t = r.unit()
            let bx = lerp(-2, 34, t), by = lerp(g - 36, g - 52, t) + r.range(-7, 6)
            p.circle(bx + r.range(-3, 3), by, r.range(0.9, 1.9), RGB(r: 0.98, g: 0.78, b: 0.82), opacity: r.range(0.7, 1))
        }
    }

    // MARK: Taj Mahal

    static func tajMahal(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            let white = c.light.mixed(.white, 0.5)
            // Plinth
            q.rect(8, g - 8, 84, 9, white.darkened(0.06))
            q.rect(12, g - 11, 76, 3.4, white)
            // Main hall
            let hall = Path(CGRect(x: 32, y: g - 34, width: 36, height: 24))
            q.fill(hall, white)
            q.shadeRight(hall, from: 56, c.shade, opacity: 0.18)
            q.clearArch(cx: 50, y: g - 30, w: 11, h: 19)
            q.fillArch(cx: 50, y: g - 30, w: 11, h: 19, c.deep, opacity: 0.35)
            for dx in [-12.0, 12.0] { q.clearArch(cx: 50 + dx, y: g - 26, w: 4.4, h: 9) }
            // Main dome
            var dome = Path()
            dome.move(to: pt(38, g - 34))
            dome.addCurve(to: pt(50, g - 62), control1: pt(35, g - 48), control2: pt(45, g - 52))
            dome.addCurve(to: pt(62, g - 34), control1: pt(55, g - 52), control2: pt(65, g - 48))
            dome.closeSubpath()
            q.fill(dome, white)
            q.shadeRight(dome, from: 52, c.shade, opacity: 0.2)
            q.rect(49.65, g - 74, 0.7, 13, c.sun)
            q.circle(50, g - 66, 1.3, c.sun)
            // Chhatris
            for dx in [-14.0, 14.0] {
                var small = Path()
                small.addArc(center: pt(50 + dx, g - 34), radius: 3.2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                small.closeSubpath()
                q.fill(small, white)
                q.rect(50 + dx - 2.2, g - 34, 4.4, 4, white)
            }
            // Minarets
            for mx in [14.0, 86.0] {
                q.rect(mx - 1.7, g - 50, 3.4, 40, white)
                q.shadeRight(Path(CGRect(x: mx - 1.7, y: g - 50, width: 3.4, height: 40)), from: mx, c.shade, opacity: 0.2)
                for gy in [-40.0, -30.0, -20.0] { q.rect(mx - 2.5, g + gy, 5, 1.1, white) }
                var cap = Path()
                cap.addArc(center: pt(mx, g - 50), radius: 2.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                cap.closeSubpath()
                q.fill(cap, white)
            }
        }
        s.mirror(opacity: 0.32) { render($0) }
        render(p)
        // Cypress trees
        for x in [24.0, 76.0] {
            p.poly([(x - 2, g + 3), (x, g - 12), (x + 2, g + 3)], c.deep.mixed(c.ground, 0.5))
        }
    }

    // MARK: Angkor Wat

    static func angkor(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func prangTower(_ q: ArtPen, cx: Double, h: Double, w: Double) {
            var x = cx
            _ = x
            let tiers = 5
            for i in 0..<tiers {
                let t = Double(i) / Double(tiers)
                let tw = w * (1 - t * 0.55)
                let th = h * 0.13
                let y = g - h * 0.22 - Double(i) * th
                q.rect(cx - tw / 2, y - th, tw, th + 0.5, c.subject)
                q.rect(cx - tw / 2 - 0.6, y - 0.9, tw + 1.2, 1.0, c.light, opacity: 0.6)
            }
            var bud = Path()
            let by = g - h * 0.22 - Double(tiers) * h * 0.13
            bud.move(to: pt(cx - w * 0.22, by))
            bud.addQuadCurve(to: pt(cx, by - h * 0.28), control: pt(cx - w * 0.3, by - h * 0.14))
            bud.addQuadCurve(to: pt(cx + w * 0.22, by), control: pt(cx + w * 0.3, by - h * 0.14))
            bud.closeSubpath()
            q.fill(bud, c.subject)
            q.shadeRight(bud, from: cx, c.shade, opacity: 0.3)
            q.rect(cx - 0.3, by - h * 0.28 - 3, 0.6, 3.4, c.subject)
            x = cx
            q.rect(cx - w * 0.5, g - h * 0.22, w, h * 0.22 + 1, c.subject)
            q.clearArch(cx: cx, y: g - h * 0.18, w: w * 0.22, h: h * 0.18)
        }
        func render(_ q: ArtPen) {
            // Terraces
            q.rect(4, g - 9, 92, 10, c.subject.darkened(0.06))
            q.rect(12, g - 13, 76, 4.4, c.subject)
            q.rect(20, g - 16, 60, 3.4, c.subject.lightened(0.04))
            for k in 0..<18 { q.clearArch(cx: 8 + Double(k) * 5.1, y: g - 6, w: 2.0, h: 6.5) }
            prangTower(q, cx: 14, h: 26, w: 9)
            prangTower(q, cx: 86, h: 26, w: 9)
            prangTower(q, cx: 31, h: 40, w: 11)
            prangTower(q, cx: 69, h: 40, w: 11)
            prangTower(q, cx: 50, h: 56, w: 14)
        }
        s.mirror(opacity: 0.30) { render($0) }
        render(p)
        palm(p, x: 2, base: g + 8, h: 32, lean: 5, color: c.deep)
        palm(p, x: 98, base: g + 8, h: 28, lean: -5, color: c.deep)
    }

    // MARK: Great Wall

    static func greatWall(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Layered ridges behind
        p.fill(Path.ridge(points: [(-4, g - 20), (16, g - 44), (30, g - 30), (50, g - 58), (70, g - 36), (86, g - 54), (104, g - 22)], baseY: g + 2),
               c.hillFar.mixed(c.subject, 0.25))
        p.fill(Path.ridge(points: [(-4, g - 8), (22, g - 28), (44, g - 16), (66, g - 34), (88, g - 20), (104, g - 10)], baseY: g + 2),
               c.hillNear.mixed(c.subject, 0.35))
        // The wall following the ridge
        let route: [(Double, Double)] = [(-4, g - 2), (12, g - 12), (26, g - 22), (40, g - 33), (54, g - 38), (66, g - 50), (80, g - 58), (104, g - 62)]
        var wall = Path()
        wall.move(to: pt(route[0].0, route[0].1))
        for q in route.dropFirst() { wall.addLine(to: pt(q.0, q.1)) }
        p.stroke(wall, width: 5.2, c.subject, cap: .butt)
        var top = Path()
        top.move(to: pt(route[0].0, route[0].1 - 2.4))
        for q in route.dropFirst() { top.addLine(to: pt(q.0, q.1 - 2.4)) }
        p.stroke(top, width: 1.1, c.light, cap: .butt)
        // Watchtowers
        for i in [2, 4, 6] {
            let (x, y) = route[i]
            p.rect(x - 4.6, y - 14, 9.2, 14, c.subject)
            p.shadeRight(Path(CGRect(x: x - 4.6, y: y - 14, width: 9.2, height: 14)), from: x, c.shade, opacity: 0.3)
            for k in 0..<3 { p.rect(x - 4.6 + Double(k) * 3.6, y - 16.4, 2, 2.4, c.subject) }
            p.fillArch(cx: x, y: y - 11, w: 2.6, h: 5, c.deep, opacity: 0.85)
        }
        // Autumn foreground trees
        var r = s.rng(61)
        for _ in 0..<14 {
            let x = r.range(-2, 102)
            if x > 22 && x < 80 && r.chance(0.7) { continue }
            p.circle(x, g + r.range(-1, 6), r.range(3, 6), c.tint.mixed(c.sun, r.unit()), opacity: 0.9)
        }
    }

    // MARK: Marina Bay

    static func marinaBay(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            // Skyline back
            var r = s.rng(71)
            var x = -2.0
            while x < 100 {
                let w = r.range(5, 9), h = r.range(10, 26)
                q.rect(x, g - h, w, h + 1, c.hillFar.mixed(c.subject, 0.3))
                x += w + r.range(0, 1.5)
            }
            // Three towers leaning toward each other
            let tops: [(base: Double, top: Double)] = [(30, 34), (50, 50), (70, 66)]
            for (i, t) in tops.enumerated() {
                let lean = [-1.0, 0.0, 1.0][i]
                let tower = Path { path in
                    path.move(to: pt(t.base - 7, g + 1))
                    path.addLine(to: pt(t.base - 5 - lean * 3.5 + 0.0, g - 54))
                    path.addLine(to: pt(t.base + 5 - lean * 3.5, g - 54))
                    path.addLine(to: pt(t.base + 7, g + 1))
                    path.closeSubpath()
                }
                _ = t.top
                q.fill(tower, c.subject)
                q.shadeRight(tower, from: t.base, c.shade, opacity: 0.35)
                var y = g - 50
                while y < g - 2 {
                    q.rect(t.base - 5.5 - lean * 1.2, y, 10.4 + lean * 0, 0.55, c.light, opacity: 0.5)
                    y += 3.6
                }
            }
            // SkyPark
            var park = Path()
            park.move(to: pt(12, g - 58))
            park.addLine(to: pt(88, g - 58))
            park.addQuadCurve(to: pt(80, g - 51), control: pt(88, g - 52))
            park.addLine(to: pt(20, g - 51))
            park.addQuadCurve(to: pt(12, g - 58), control: pt(12, g - 52))
            park.closeSubpath()
            q.fill(park, c.subject)
            q.rect(12, g - 58.6, 76, 1.2, c.light)
            for k in 0..<10 { q.circle(60 + Double(k) * 2.6, g - 59.8, 1.0, c.ground, opacity: 0.9) }
            // ArtScience lotus
            for k in 0..<5 {
                let a = Double(k) / 4.0
                var petal = Path()
                petal.move(to: pt(6, g + 1))
                petal.addQuadCurve(to: pt(lerp(-4, 14, a), g - 12 - sin(a * .pi) * 8), control: pt(lerp(-6, 16, a), g - 3))
                petal.addQuadCurve(to: pt(14, g + 1), control: pt(lerp(0, 18, a), g - 4))
                petal.closeSubpath()
                q.fill(petal, c.light, opacity: 0.9)
            }
        }
        s.mirror(opacity: 0.3) { render($0) }
        render(p)
    }

    // MARK: Tanah Lot / Balinese water temple

    static func pagoda(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func render(_ q: ArtPen) {
            // Sea rock with a natural arch
            var rock = Path()
            rock.move(to: pt(18, g + 3))
            rock.addQuadCurve(to: pt(30, g - 14), control: pt(20, g - 10))
            rock.addQuadCurve(to: pt(52, g - 20), control: pt(40, g - 22))
            rock.addQuadCurve(to: pt(76, g - 8), control: pt(68, g - 20))
            rock.addQuadCurve(to: pt(84, g + 3), control: pt(82, g - 2))
            rock.closeSubpath()
            q.fill(rock, c.shade)
            q.shadeRight(rock, from: 60, c.deep, opacity: 0.3)
            q.clearArch(cx: 40, y: g - 8, w: 9, h: 11)
            // Meru tiers
            let cx = 54.0
            let tiers = s.variant == 0 ? 5 : 3
            for i in 0..<tiers {
                let w = 12 - Double(i) * 2.0
                let y = g - 20 - Double(i) * 7
                q.poly([(cx - w - 1.5, y), (cx + w + 1.5, y), (cx + w * 0.62, y - 5), (cx - w * 0.62, y - 5)], c.subject)
                q.rect(cx - w * 0.5, y, w, 2.4, c.deep)
                q.rect(cx - w - 1.5, y - 0.4, 2 * w + 3, 0.9, c.light, opacity: 0.6)
            }
            let topY = g - 20 - Double(tiers) * 7
            q.rect(cx - 0.4, topY - 7, 0.8, 7, c.subject)
            q.poly([(cx - 1.8, topY - 3), (cx, topY - 10), (cx + 1.8, topY - 3)], c.subject)
            // Side shrine
            q.rect(66, g - 18, 7, 6, c.subject)
            q.poly([(64.5, g - 18), (69.5, g - 24), (74.5, g - 18)], c.subject)
        }
        s.mirror(opacity: 0.28) { render($0) }
        render(p)
        // Surf at the base
        var r = s.rng(81)
        for _ in 0..<10 {
            let x = r.range(14, 86)
            p.ellipse(x, g + r.range(2, 5), r.range(2.5, 6), 0.9, .white, opacity: 0.55)
        }
    }

    // MARK: Burj Khalifa

    static func burj(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Skyline of lower towers
        var r = s.rng(91)
        var x = -2.0
        while x < 100 {
            let w = r.range(5, 9), h = r.range(12, 34)
            if x + w > 40 && x < 60 { x += w + 1; continue }
            p.rect(x, g - h, w, h + 1, c.hillFar.mixed(c.subject, 0.5))
            x += w + r.range(0.5, 2)
        }
        // The tower
        let pts: [(Double, Double)] = [(44, g + 1), (44, g - 28), (45.6, g - 28), (45.6, g - 48), (47.2, g - 48), (47.2, g - 64),
                                       (48.6, g - 64), (48.6, g - 78), (49.5, g - 78), (49.5, g - 90), (50, g - 96),
                                       (50.5, g - 90), (50.5, g - 78), (51.4, g - 78), (51.4, g - 64), (52.8, g - 64),
                                       (52.8, g - 48), (54.4, g - 48), (54.4, g - 28), (56, g - 28), (56, g + 1)]
        p.poly(pts, c.subject)
        var shade = Path()
        shade.move(to: pt(50, g + 1))
        shade.addLine(to: pt(50, g - 96))
        shade.addLine(to: pt(56, g - 28))
        shade.addLine(to: pt(56, g + 1))
        shade.closeSubpath()
        p.clipped(to: shade) { clip in
            clip.poly(pts, c.shade, opacity: 0.55)
        }
        for k in 0..<10 {
            let y = g - 8 - Double(k) * 8
            p.rect(46, y, 8, 0.4, c.light, opacity: 0.4)
        }
    }

    // MARK: Petra

    static func petra(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Back wall
        p.rect(-2, 0, 104, g + 2, c.subject.mixed(c.skyBottom, 0.2))
        // Canyon walls
        let left = Path { path in
            path.move(to: pt(-2, g + 2))
            path.addLine(to: pt(-2, 0))
            path.addLine(to: pt(24, 0))
            path.addQuadCurve(to: pt(22, 30), control: pt(32, 14))
            path.addQuadCurve(to: pt(24, 58), control: pt(14, 44))
            path.addQuadCurve(to: pt(18, g + 2), control: pt(30, 78))
            path.closeSubpath()
        }
        let right = Path { path in
            path.move(to: pt(102, g + 2))
            path.addLine(to: pt(102, 0))
            path.addLine(to: pt(78, 0))
            path.addQuadCurve(to: pt(82, 28), control: pt(70, 12))
            path.addQuadCurve(to: pt(78, 60), control: pt(90, 44))
            path.addQuadCurve(to: pt(84, g + 2), control: pt(72, 80))
            path.closeSubpath()
        }
        p.fill(left, c.shade)
        p.fill(right, c.shade.darkened(0.12))
        var r = s.rng(101)
        for path in [left, right] {
            p.clipped(to: path) { q in
                for i in 0..<9 {
                    let y = Double(i) * 11 + r.range(0, 4)
                    q.rect(-2, y, 104, r.range(1.2, 2.6), c.subject.mixed(c.tint, 0.5), opacity: 0.35)
                }
            }
        }
        // Treasury facade
        let facade = Path(CGRect(x: 33, y: g - 50, width: 34, height: 51))
        p.fill(facade, c.light.mixed(c.tint, 0.3))
        p.shadeRight(facade, from: 52, c.shade, opacity: 0.25)
        // Lower portico
        p.poly([(32, g - 27), (50, g - 37), (68, g - 27)], c.light.mixed(c.tint, 0.2))
        for i in 0..<6 { p.rect(35 + Double(i) * 5.7, g - 27, 2.4, 25, c.light) }
        p.rect(32, g - 28, 36, 2, c.light.darkened(0.05))
        p.clearArch(cx: 50, y: g - 22, w: 7, h: 23)
        p.fillArch(cx: 50, y: g - 22, w: 7, h: 23, c.deep, opacity: 0.85)
        // Upper tholos
        p.rect(44, g - 56, 12, 20, c.light.mixed(c.tint, 0.15))
        p.poly([(42.4, g - 56), (50, g - 66), (57.6, g - 56)], c.light.mixed(c.tint, 0.1))
        p.poly([(34, g - 40), (44, g - 47), (44, g - 40)], c.light.mixed(c.tint, 0.2))
        p.poly([(66, g - 40), (56, g - 47), (56, g - 40)], c.light.mixed(c.tint, 0.2))
        p.fillArch(cx: 50, y: g - 50, w: 3.4, h: 8, c.deep, opacity: 0.75)
        p.circle(50, g - 67.5, 1.2, c.light)
        // Steps and shadow
        p.rect(30, g - 1, 40, 2.4, c.light.darkened(0.12))
        figure(p, x: 44, base: g + 8, h: 5, color: c.deep)
        figure(p, x: 58, base: g + 9, h: 5.4, color: c.deep)
    }

    // MARK: Ha Long Bay

    static func halong(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func karst(_ q: ArtPen, cx: Double, w: Double, h: Double, tone: RGB, cap: RGB) {
            var path = Path()
            path.move(to: pt(cx - w / 2, g + 1))
            path.addCurve(to: pt(cx - w * 0.12, g - h), control1: pt(cx - w / 2, g - h * 0.55), control2: pt(cx - w * 0.38, g - h))
            path.addQuadCurve(to: pt(cx + w * 0.2, g - h * 0.96), control: pt(cx + w * 0.04, g - h * 1.04))
            path.addCurve(to: pt(cx + w / 2, g + 1), control1: pt(cx + w * 0.4, g - h * 0.9), control2: pt(cx + w / 2, g - h * 0.5))
            path.closeSubpath()
            q.fill(path, tone)
            q.shadeRight(path, from: cx + w * 0.05, c.shade, opacity: 0.3)
            q.clipped(to: path) { clip in
                clip.rect(cx - w, g - h - 1, w * 2, h * 0.14, cap, opacity: 0.9)
            }
        }
        // Distant, hazy islands
        karst(p, cx: 14, w: 22, h: 26, tone: c.hillFar, cap: c.hillNear)
        karst(p, cx: 82, w: 28, h: 30, tone: c.hillFar, cap: c.hillNear)
        func render(_ q: ArtPen) {
            karst(q, cx: 36, w: 24, h: 44, tone: c.subject.mixed(c.hillFar, 0.3), cap: c.ground.darkened(0.2))
            karst(q, cx: 62, w: 30, h: 56, tone: c.subject, cap: c.ground.darkened(0.25))
            karst(q, cx: 92, w: 20, h: 38, tone: c.subject.darkened(0.05), cap: c.ground.darkened(0.2))
        }
        s.mirror(opacity: 0.3) { render($0) }
        render(p)
        // Junk boat
        let bx = 18.0, by = g + 12.0
        p.poly([(bx - 8, by), (bx + 10, by), (bx + 7, by + 3.4), (bx - 5, by + 3.4)], c.deep)
        p.rect(bx - 0.4, by - 14, 0.8, 14, c.deep)
        p.poly([(bx + 0.6, by - 14), (bx + 9, by - 10), (bx + 8, by - 1), (bx + 0.6, by - 1)], c.tint)
        for k in 1..<4 { p.line(bx + 0.6, by - 14 + Double(k) * 3.4, bx + 8.8, by - 11 + Double(k) * 2.8, width: 0.35, c.deep, opacity: 0.6) }
        p.poly([(bx - 0.6, by - 12), (bx - 6, by - 7), (bx - 0.6, by - 1)], c.tint, opacity: 0.9)
    }

    // MARK: Gyeongbokgung

    static func hanokPalace(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Mountain behind
        p.fill(Path.ridge(points: [(-4, g - 20), (14, g - 38), (30, g - 56), (50, g - 66), (66, g - 54), (84, g - 36), (104, g - 18)], baseY: g + 2),
               c.hillFar.mixed(c.subject, 0.4))
        p.shadeRight(Path.ridge(points: [(-4, g - 20), (14, g - 38), (30, g - 56), (50, g - 66), (66, g - 54), (84, g - 36), (104, g - 18)], baseY: g + 2),
                     from: 58, c.shade, opacity: 0.25)
        // Stone terraces
        p.rect(6, g - 4, 88, 5, c.light.darkened(0.1))
        p.rect(10, g - 9, 80, 5.4, c.light)
        // Hall body
        p.rect(18, g - 28, 64, 19, c.deep.mixed(c.tint, 0.35))
        var x = 20.0
        while x < 80 {
            p.rect(x, g - 28, 2.0, 19, c.tint)
            p.rect(x + 2, g - 25, 5.0, 14, c.deep, opacity: 0.7)
            x += 7
        }
        // Lower and upper roofs
        p.poly([(6, g - 29), (24, g - 24.5), (76, g - 24.5), (94, g - 29), (80, g - 37), (20, g - 37)], c.subject)
        p.rect(20, g - 25.4, 60, 1.3, c.light, opacity: 0.5)
        p.poly([(18, g - 51), (32, g - 46), (68, g - 46), (82, g - 51), (72, g - 59), (50, g - 66), (28, g - 59)], c.subject)
        p.shadeRight(Path { path in
            path.move(to: pt(50, g - 66)); path.addLine(to: pt(72, g - 59)); path.addLine(to: pt(82, g - 51))
            path.addLine(to: pt(68, g - 46)); path.addLine(to: pt(50, g - 46)); path.closeSubpath()
        }, from: 50, c.shade, opacity: 0.3)
        p.rect(28, g - 46, 44, 9, c.deep.mixed(c.tint, 0.3))
        for k in 0..<7 { p.rect(30 + Double(k) * 6.2, g - 46, 1.6, 9, c.tint) }
        p.circle(50, g - 66.8, 1.2, c.deep)
        // Courtyard figures
        figure(p, x: 24, base: g + 8, h: 5, color: c.deep)
        figure(p, x: 74, base: g + 10, h: 5.4, color: c.deep)
    }

    // MARK: Wat Arun

    static func prang(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func corncob(_ q: ArtPen, cx: Double, h: Double, w: Double) {
            var body = Path()
            body.move(to: pt(cx - w / 2, g + 1))
            body.addCurve(to: pt(cx, g - h), control1: pt(cx - w * 0.52, g - h * 0.45), control2: pt(cx - w * 0.2, g - h * 0.72))
            body.addCurve(to: pt(cx + w / 2, g + 1), control1: pt(cx + w * 0.2, g - h * 0.72), control2: pt(cx + w * 0.52, g - h * 0.45))
            body.closeSubpath()
            q.fill(body, c.light)
            q.shadeRight(body, from: cx, c.shade, opacity: 0.22)
            q.clipped(to: body) { clip in
                var y = g - 3.0
                var k = 0
                while y > g - h {
                    clip.rect(cx - w, y, w * 2, 0.8, c.tint, opacity: 0.55)
                    var nx = cx - w / 2
                    while nx < cx + w / 2 {
                        clip.circle(nx, y - 1.8, 0.6, c.tint, opacity: 0.55)
                        nx += 2.4
                    }
                    y -= 4.2 + Double(k) * 0.3
                    k += 1
                }
            }
            q.rect(cx - 0.3, g - h - 6, 0.6, 6.4, c.light)
            q.poly([(cx - 1.4, g - h - 1), (cx, g - h - 6), (cx + 1.4, g - h - 1)], c.tint)
        }
        func render(_ q: ArtPen) {
            q.rect(14, g - 8, 72, 9, c.light.darkened(0.06))
            corncob(q, cx: 24, h: 24, w: 12)
            corncob(q, cx: 76, h: 24, w: 12)
            corncob(q, cx: 50, h: 62, w: 24)
            q.clearArch(cx: 50, y: g - 14, w: 6, h: 14)
        }
        s.mirror(opacity: 0.28) { render($0) }
        render(p)
    }

    // MARK: Sigiriya

    static func sigiriya(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        var rock = Path()
        rock.move(to: pt(14, g + 2))
        rock.addQuadCurve(to: pt(24, g - 34), control: pt(20, g - 12))
        rock.addQuadCurve(to: pt(32, g - 66), control: pt(24, g - 56))
        rock.addLine(to: pt(66, g - 68))
        rock.addQuadCurve(to: pt(78, g - 34), control: pt(78, g - 58))
        rock.addQuadCurve(to: pt(88, g + 2), control: pt(80, g - 12))
        rock.closeSubpath()
        p.fill(rock, c.subject)
        p.shadeRight(rock, from: 56, c.shade, opacity: 0.4)
        p.lightLeft(rock, to: 36, c.light, opacity: 0.2)
        p.clipped(to: rock) { q in
            var r = s.rng(111)
            for k in 0..<12 {
                let x = 22 + Double(k) * 5.2
                q.rect(x, g - 66, r.range(0.5, 1.2), 70, c.deep, opacity: 0.22)
            }
        }
        // Summit ruins
        p.rect(36, g - 73, 6, 5, c.subject.darkened(0.15))
        p.rect(46, g - 71, 10, 3.4, c.subject.darkened(0.15))
        p.rect(58, g - 72, 5, 4.2, c.subject.darkened(0.15))
        p.poly([(35, g - 73), (39, g - 78), (43, g - 73)], c.tint)
        // Zig-zag stairway
        var stairs = Path()
        stairs.move(to: pt(48, g - 2))
        for (i, x) in [60.0, 44.0, 62.0, 46.0, 58.0].enumerated() {
            stairs.addLine(to: pt(x, g - 2 - Double(i + 1) * 9))
        }
        p.stroke(stairs, width: 0.9, c.light, opacity: 0.6, cap: .butt)
        // Water gardens and jungle
        var r = s.rng(112)
        for _ in 0..<16 {
            let x = r.range(-2, 102)
            if x > 30 && x < 70 { continue }
            p.circle(x, g + r.range(0, 8), r.range(4, 8), c.ground.mixed(c.deep, 0.4), opacity: 0.95)
        }
        for x in [36.0, 64.0] { p.circle(x, g + 3, 4.6, c.ground.mixed(c.deep, 0.3)) }
    }

    // MARK: Galle lighthouse and fort

    static func lighthouseFort(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Rampart
        p.rect(-2, g - 12, 104, 13, c.subject)
        p.shadeRight(Path(CGRect(x: -2, y: g - 12, width: 104, height: 13)), from: 60, c.shade, opacity: 0.18)
        var x = -1.0
        while x < 100 { p.rect(x, g - 14.2, 2.6, 2.4, c.subject); x += 4.6 }
        p.poly([(70, g - 12), (76, g - 22), (92, g - 22), (100, g - 12)], c.subject.darkened(0.06))
        p.clearArch(cx: 84, y: g - 11, w: 4, h: 8)
        // Lighthouse
        let tower = Path { path in
            path.move(to: pt(44.5, g - 12)); path.addLine(to: pt(46.6, g - 52)); path.addLine(to: pt(53.4, g - 52))
            path.addLine(to: pt(55.5, g - 12)); path.closeSubpath()
        }
        p.fill(tower, RGB.white.mixed(c.light, 0.2))
        p.shadeRight(tower, from: 50, c.shade, opacity: 0.28)
        p.clipped(to: tower) { q in
            q.rect(40, g - 44, 20, 5, c.tint, opacity: 0.9)
            q.rect(40, g - 28, 20, 5, c.tint, opacity: 0.9)
        }
        p.rect(44.8, g - 54.4, 10.4, 2.6, c.deep)
        p.rect(47, g - 61, 6, 7, c.sun, opacity: 0.85)
        p.rect(47, g - 61, 6, 0.8, c.deep)
        var cap = Path()
        cap.addArc(center: pt(50, g - 61), radius: 3.6, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        cap.closeSubpath()
        p.fill(cap, c.deep)
        // Beam
        p.poly([(53, g - 58), (104, g - 70), (104, g - 50)], c.sun, opacity: 0.16)
        palm(p, x: 14, base: g + 3, h: 38, lean: 7, color: c.deep)
        palm(p, x: 26, base: g + 3, h: 26, lean: -4, color: c.deep)
        // Surf
        var r = s.rng(121)
        for _ in 0..<12 {
            p.ellipse(r.range(0, 100), g + r.range(3, 6), r.range(3, 7), 1, .white, opacity: 0.6)
        }
    }

    // MARK: Pyramids of Giza

    static func pyramids(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        let pyramids: [(l: Double, apex: Double, r: Double, h: Double)] = [
            (-8, 12, 32, 36), (64, 82, 100, 28), (14, 52, 90, 58),
        ]
        for pm in pyramids {
            let face = Path { path in
                path.move(to: pt(pm.l, g + 1)); path.addLine(to: pt(pm.apex, g - pm.h)); path.addLine(to: pt(pm.r, g + 1)); path.closeSubpath()
            }
            p.fill(face, c.subject)
            let dark = Path { path in
                path.move(to: pt(pm.apex, g - pm.h)); path.addLine(to: pt(pm.r, g + 1)); path.addLine(to: pt(pm.apex + 2, g + 1)); path.closeSubpath()
            }
            p.fill(dark, c.shade, opacity: 0.85)
            p.clipped(to: face) { q in
                var y = g - pm.h + 4
                while y < g {
                    q.rect(pm.l, y, pm.r - pm.l, 0.35, c.deep, opacity: 0.22)
                    y += 3.6
                }
            }
        }
        // Camel and rider
        let bx = 20.0, by = g + 17.0
        p.ellipse(bx, by - 8, 6.5, 3.2, c.deep)
        p.ellipse(bx - 1.5, by - 11.4, 1.8, 1.9, c.deep)
        for dx in [-4.0, -1.6, 2.0, 4.2] { p.rect(bx + dx - 0.35, by - 6, 0.7, 7, c.deep) }
        var neck = Path()
        neck.move(to: pt(bx + 5, by - 9))
        neck.addQuadCurve(to: pt(bx + 9.4, by - 16), control: pt(bx + 8, by - 10))
        p.stroke(neck, width: 1.5, c.deep)
        p.ellipse(bx + 10.4, by - 16.6, 1.8, 1.0, c.deep)
        figure(p, x: bx - 0.5, base: by - 9.6, h: 7, color: c.deep)
    }

    // MARK: Table Mountain

    static func tableMountain(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Lion's Head
        p.fill(Path.ridge(points: [(-6, g + 1), (4, g - 14), (14, g - 26), (24, g - 24), (32, g - 8), (38, g + 1)], baseY: g + 2), c.hillFar.mixed(c.subject, 0.5))
        // The table
        var mtn = Path()
        mtn.move(to: pt(22, g + 1))
        mtn.addLine(to: pt(26, g - 20))
        mtn.addCurve(to: pt(34, g - 46), control1: pt(26, g - 30), control2: pt(28, g - 42))
        mtn.addLine(to: pt(78, g - 46))
        mtn.addCurve(to: pt(92, g - 24), control1: pt(86, g - 44), control2: pt(90, g - 34))
        mtn.addLine(to: pt(106, g + 1))
        mtn.closeSubpath()
        p.fill(mtn, c.subject)
        p.shadeRight(mtn, from: 62, c.shade, opacity: 0.35)
        p.clipped(to: mtn) { q in
            var r = s.rng(131)
            for k in 0..<16 {
                let x = 28 + Double(k) * 4.4 + r.range(-1, 1)
                q.rect(x, g - 46, r.range(0.6, 1.4), 50, c.deep, opacity: 0.2)
            }
        }
        // The tablecloth of cloud
        for (x, y, rx, ry) in [(40.0, g - 46.0, 14.0, 3.0), (58.0, g - 47.0, 16.0, 3.6), (76.0, g - 45.0, 14.0, 3.2), (88.0, g - 38.0, 10.0, 3.6), (94.0, g - 30.0, 8.0, 3.0)] {
            p.ellipse(x, y, rx, ry, RGB.white, opacity: 0.88)
        }
        // City at the foot
        var r = s.rng(132)
        var x = 24.0
        while x < 98 {
            let w = r.range(3, 6), h = r.range(4, 11)
            p.rect(x, g - h + 1, w, h + 1, c.hillNear.darkened(0.2))
            x += w + 0.4
        }
    }

    // MARK: Serengeti

    static func savanna(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        func acacia(_ x: Double, _ h: Double, _ w: Double) {
            var trunk = Path()
            trunk.move(to: pt(x, g + 2))
            trunk.addQuadCurve(to: pt(x + 1, g - h * 0.6), control: pt(x - 2, g - h * 0.3))
            p.stroke(trunk, width: max(1.3, w * 0.07), c.deep)
            for (dx, dy, rx, ry) in [(0.0, 0.0, 0.5, 0.11), (-0.28, 0.07, 0.3, 0.08), (0.3, 0.06, 0.32, 0.08)] {
                p.ellipse(x + dx * w + 1, g - h + dy * w, rx * w, ry * w, c.deep)
            }
            var branch = Path()
            branch.move(to: pt(x + 1, g - h * 0.6))
            branch.addLine(to: pt(x - w * 0.22, g - h + 2))
            branch.move(to: pt(x + 1, g - h * 0.6))
            branch.addLine(to: pt(x + w * 0.24, g - h + 2))
            p.stroke(branch, width: 1.0, c.deep)
        }
        func giraffe(_ x: Double, _ k: Double) {
            let base = g + 4
            p.ellipse(x, base - 10 * k, 5.6 * k, 2.6 * k, c.deep)
            for dx in [-4.2, -2.2, 2.2, 4.2] { p.rect(x + dx * k - 0.35 * k, base - 9 * k, 0.8 * k, 9 * k, c.deep) }
            p.poly([(x + 3.4 * k, base - 10.6 * k), (x + 4.6 * k, base - 11 * k), (x + 7.4 * k, base - 22 * k), (x + 6.2 * k, base - 22.4 * k)], c.deep)
            p.ellipse(x + 8.2 * k, base - 22.8 * k, 1.9 * k, 1.0 * k, c.deep)
            p.rect(x - 5.8 * k, base - 11 * k, 1.2 * k, 0.5 * k, c.deep)
        }
        // Distant herd
        var r = s.rng(141)
        for _ in 0..<14 {
            let x = r.range(2, 98)
            p.ellipse(x, g + r.range(-0.5, 2.6), 1.6, 0.8, c.deep, opacity: 0.8)
            p.rect(x - 0.9, g + 0.2, 0.3, 1.2, c.deep, opacity: 0.8)
            p.rect(x + 0.7, g + 0.2, 0.3, 1.2, c.deep, opacity: 0.8)
        }
        acacia(24, 38, 40)
        acacia(80, 24, 26)
        giraffe(56, 1.0)
        giraffe(68, 0.72)
        // Tall grass
        for _ in 0..<40 {
            let x = r.range(0, 100), y = r.range(g + 6, 128)
            p.line(x, y, x + r.range(-1, 1), y - r.range(3, 7), width: 0.5, c.ground.darkened(0.35), opacity: 0.8)
        }
    }

    // MARK: Koutoubia Mosque

    static func minaret(_ s: ArtSceneContext) {
        let p = s.pen, c = s.c, g = s.g
        // Flat medina roofs behind
        var r = s.rng(151)
        var x = -2.0
        while x < 100 {
            let w = r.range(8, 14), h = r.range(4, 8)
            p.rect(x, g - h, w, h + 1, c.hillNear.mixed(c.subject, 0.35))
            x += w + 0.5
        }
        // The minaret
        let shaft = Path(CGRect(x: 38, y: g - 58, width: 24, height: 59))
        p.fill(shaft, c.subject)
        p.shadeRight(shaft, from: 52, c.shade, opacity: 0.32)
        // Bands of blind arches
        for (i, y) in [g - 52.0, g - 40.0, g - 28.0, g - 16.0].enumerated() {
            p.rect(38, y - 1.2, 24, 1.2, c.light, opacity: 0.55)
            let n = i % 2 == 0 ? 3 : 2
            for k in 0..<n {
                let cx = 38 + 24 * (Double(k) + 0.5) / Double(n)
                p.fillArch(cx: cx, y: y + 1.5, w: 24 / Double(n) * 0.52, h: 8.6, c.deep, opacity: 0.55)
            }
        }
        // Lantern tower and finial
        p.rect(44, g - 70, 12, 12, c.subject.lightened(0.04))
        p.rect(43, g - 59, 14, 1.2, c.light, opacity: 0.6)
        p.fillArch(cx: 50, y: g - 67, w: 4, h: 7, c.deep, opacity: 0.6)
        var dome = Path()
        dome.addArc(center: pt(50, g - 70), radius: 4.6, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.closeSubpath()
        p.fill(dome, c.shade.lightened(0.1))
        p.rect(49.7, g - 80, 0.6, 6, c.subject)
        for k in 0..<3 { p.circle(50, g - 77 - Double(k) * 2.2 + 3.4, 1.1 - Double(k) * 0.2, c.sun) }
        palm(p, x: 14, base: g + 5, h: 44, lean: 5, color: c.deep)
        palm(p, x: 28, base: g + 5, h: 32, lean: -3, color: c.deep)
        palm(p, x: 84, base: g + 5, h: 40, lean: -5, color: c.deep)
    }
}
