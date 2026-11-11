import SwiftUI

/// Colour tokens of the Home screen (Design Z2). Views ask for a role; the hex values live only here.
enum HomeColor {
    static let page = Color(light: 0xF6F1E7, dark: 0x1C1B19)
    static let card = Color(light: 0xFBF7EE, dark: 0x2B2927)
    static let cardLine = Color(light: 0xC8BFB3, dark: 0x484540)
    static let ink = Color(light: 0x211E1A, dark: 0xF6F0E5, lightHC: 0x000000, darkHC: 0xFFFFFF)
    static let sub = Color(light: 0x5F5A51, dark: 0xBDB6A8, lightHC: 0x403C35, darkHC: 0xD9D3C6)
    static let ink3 = Color(light: 0x6B655A, dark: 0xA8A296, lightHC: 0x4A453C, darkHC: 0xC9C3B6)
    static let cta = Color(light: 0xA25A38, dark: 0xDB8D66)
    static let ctaText = Color(light: 0xFFF9F1, dark: 0x221A14)
    static let label = Color(light: 0x8A4526, dark: 0xF0A982, lightHC: 0x6E3319, darkHC: 0xF7BFA0)
    static let tint = Color(light: 0xEBDDCC, dark: 0x3A302A)
    static let shadow1 = Color(light: 0x462A14, dark: 0x000000)
    static let posterTop = Color(light: 0xA55B3A, dark: 0x262321)
    static let posterMid = Color(light: 0x97502F, dark: 0x1F1D1B)
    static let posterBottom = Color(light: 0x82442A, dark: 0x1B1A18)
    static let glow = Color(light: 0xFFCD96, dark: 0xE29654)
    static let onPoster = Color(hex: 0xFFF9F1)
    static let chipFill = Color(hex: 0xF4C783)
    static let chipInk = Color(hex: 0x7E4126)
    static let numeralEdge = Color(light: 0xFFF3DE, dark: 0x7A5240)
    static let numeralFallback = Color(light: 0xFFF3DE, dark: 0xEE9A68)
    /// Gold is the Verified colour. Nothing else on Home uses it.
    static let verifiedGold = Color(hex: 0xE9BE62)
    static let litCountry = Color(hex: 0xE39A74)
    static let thereNow = Color(hex: 0x4AA06E)
    static let atlasTop = Color(light: 0x2E2823, dark: 0x15110F)
    static let atlasBottom = Color(light: 0x1F1B18, dark: 0x0F0D0B)
    static let cream = Color(hex: 0xF6F0E5)
    static let postcard = Color(light: 0xFFFDF7, dark: 0x34302C)
    static let glassFill = Color(light: 0x3C1608, dark: 0xFFFFFF)
}
