import SwiftUI

/// The physical look of a cover: three gradient stops and a deep colour. They are the leather, not UI chrome, so they are
/// the same in light and dark and live next to the drawing, not in the asset catalog.
extension CoverStyle {
    struct Leather {
        let top: UInt32
        let mid: UInt32
        let bottom: UInt32
        let deep: UInt32
    }

    var leather: Leather {
        switch self {
        case .clay: Leather(top: 0xC27A50, mid: 0xA65C3A, bottom: 0x86472C, deep: 0x3A1A0C)
        case .forest: Leather(top: 0x5C7F68, mid: 0x40604C, bottom: 0x2F4639, deep: 0x0F1E16)
        case .midnight: Leather(top: 0x3C4560, mid: 0x272D43, bottom: 0x1B1F31, deep: 0x06080F)
        case .harbor: Leather(top: 0x5C86AB, mid: 0x3F6A8E, bottom: 0x2D5577, deep: 0x0D2236)
        case .rosewood: Leather(top: 0xB06A76, mid: 0x8C5059, bottom: 0x733E49, deep: 0x2A0E15)
        }
    }

    /// The 135 degree body gradient, stops at 0, .55 and 1.
    var gradient: Gradient {
        let leather = leather
        return Gradient(stops: [.init(color: StampArt.ink(leather.top), location: 0), .init(color: StampArt.ink(leather.mid), location: 0.55),
                                .init(color: StampArt.ink(leather.bottom), location: 1)])
    }
}
