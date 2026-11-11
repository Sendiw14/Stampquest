import Testing
import SwiftUI
import UIKit
@testable import StampQuest

struct FontAndColorTests {
    @Test func everyBundledFontResolves() {
        let missing = FontRegistration.unresolvedNames()
        #expect(missing.isEmpty, "Unresolved: \(missing). Registered: \(FontRegistration.availableNames())")
    }

    @Test func everyColorTokenResolvesInBothAppearances() {
        for name in OBColor.assetNames {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let color = UIColor(named: name, in: .main, compatibleWith: UITraitCollection(userInterfaceStyle: style))
                #expect(color != nil, "\(name) missing in \(style.rawValue)")
            }
        }
    }
}

struct GeometryTests {
    @Test func arcTextTopIsCentredAndLeansOutward() {
        let glyphs = ArcText.layout(characters: Array("ABC"), advances: [4, 4, 4], radius: 24, tracking: 1, placement: .top)
        #expect(glyphs.count == 3)
        #expect(abs(glyphs[1].position.x) < 0.001 && abs(glyphs[1].position.y + 24) < 0.001, "middle glyph sits at 12 o'clock")
        #expect(abs(glyphs[1].angle) < 0.001)
        #expect(glyphs[0].angle < 0 && glyphs[2].angle > 0, "reads left to right, tops point outward")
        #expect(glyphs[0].position.x < 0 && glyphs[2].position.x > 0)
        #expect(abs(glyphs[0].angle + glyphs[2].angle) < 0.001, "symmetric")
    }

    @Test func arcTextBottomReadsLeftToRightWithTopsInward() {
        let glyphs = ArcText.layout(characters: Array("ABC"), advances: [4, 4, 4], radius: 30, tracking: 0.8, placement: .bottom)
        #expect(abs(glyphs[1].position.x) < 0.001 && abs(glyphs[1].position.y - 30) < 0.001, "middle glyph sits at 6 o'clock")
        #expect(glyphs[0].position.x < glyphs[1].position.x && glyphs[1].position.x < glyphs[2].position.x)
        #expect(glyphs[0].angle > 0 && glyphs[2].angle < 0)
    }

    @Test func arcTextEdgeCases() {
        #expect(ArcText.layout(characters: [], advances: [], radius: 10, tracking: 0, placement: .top).isEmpty)
        #expect(ArcText.layout(characters: ["A"], advances: [4], radius: 0, tracking: 0, placement: .top).isEmpty)
        let one = ArcText.layout(characters: ["A"], advances: [4], radius: 10, tracking: 3, placement: .top)
        #expect(abs(one[0].angle) < 0.001, "a single glyph is centred; tracking only goes between glyphs")
    }

    @Test func svgArcMakesATopSemicircle() {
        let dome = SVGPath.path("M28.5 26 A6 6 0 0 1 40.5 26 Z").boundingRect
        #expect(abs(dome.minX - 28.5) < 0.05 && abs(dome.maxX - 40.5) < 0.05)
        #expect(abs(dome.minY - 20) < 0.05 && abs(dome.maxY - 26) < 0.05, "sweep=1 from left to right passes over the top")
    }

    @Test func svgParserHandlesRelativeFreeCommandsAndUnicodeMinus() {
        let tower = SVGPath.path("M50.4 10 H51.6 L52.3 30 H49.7 Z").boundingRect
        #expect(abs(tower.minY - 10) < 0.001 && abs(tower.maxY - 30) < 0.001)
        let torii = SVGPath.path("M\u{2212}3 15 L105 15 Q100 25 94 25 H8 Q2 25 \u{2212}3 15 Z").boundingRect
        #expect(abs(torii.minX + 3) < 0.001 && abs(torii.maxX - 105) < 0.001)
    }

    @Test func stampOutlineHas56HolesInA120By160Frame() {
        #expect(HolePunchedStampShape.holeCenters.count == HolePunchedStampShape.holeCount)
        #expect(HolePunchedStampShape.holeCenters.contains(CGPoint(x: 0, y: 0)), "corners are punched")
        #expect(HolePunchedStampShape.holeCenters.contains(CGPoint(x: 120, y: 160)))
        let bounds = HolePunchedStampShape().path(in: CGRect(x: 0, y: 0, width: 240, height: 320)).boundingRect
        #expect(abs(bounds.width - 240) < 1 && abs(bounds.height - 320) < 1)
    }

    @Test func starFitsTheThirtyUnitBox() {
        let bounds = StarShape.unitPath.boundingRect
        #expect(abs(bounds.width - 30) < 0.01 && abs(bounds.height - 30) < 0.01)
        #expect(abs(bounds.midX) < 0.01 && abs(bounds.midY) < 0.01)
    }

}

struct OnboardingStampRenderTests {
    @Test func renderCacheProducesTheRequestedPixelSizeOnce() throws {
        let cache = StampRenderCache()
        let rendered = cache.image(for: StampDestination.paris, width: 60, scale: 2)
        let image = try #require(rendered)
        #expect(Int(image.size.width * image.scale) == 120)
        #expect(Int(image.size.height * image.scale) == 160)
        _ = cache.image(for: StampDestination.paris, width: 60, scale: 2)
        #expect(cache.count == 1)
        _ = cache.image(for: StampDestination.kyoto, width: 60, scale: 2)
        #expect(cache.count == 2)
    }

    @Test func everyStampStyleRendersSomething() throws {
        let cache = StampRenderCache()
        for destination in StampDestination.catalog {
            let rendered = cache.image(for: destination, width: 40, scale: 1)
            #expect(rendered?.cgImage != nil, "\(destination.id) rendered nothing")
        }
    }
}
