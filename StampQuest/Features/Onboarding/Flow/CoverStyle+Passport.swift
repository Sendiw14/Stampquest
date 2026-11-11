import Foundation

extension CoverStyle {
    /// The main app's cover colour for this style (the base colours are identical), so the finished passport matches
    /// what was chosen.
    var passportStyle: PassportStyle {
        switch self {
        case .clay: .terracotta
        case .forest: .forest
        case .midnight: .ink
        case .harbor: .sky
        case .rosewood: .rose
        }
    }
}
