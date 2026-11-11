import SwiftUI

/// How an interest looks on its stamp.
extension Interest {
    /// Position in the grid (row-major).
    var index: Int { Interest.allCases.firstIndex(of: self) ?? 0 }

    /// Pastel paper colour of the stamp border; the same in both appearances.
    var paper: Color {
        switch self {
        case .cities: OnbColor.stampCities
        case .coasts: OnbColor.stampCoasts
        case .mountains: OnbColor.stampMountains
        case .food: OnbColor.stampFood
        case .history: OnbColor.stampHistory
        case .hiddenGems: OnbColor.stampHiddenGems
        }
    }

    /// Resting rotation of the picked stamp in degrees.
    var pickedTilt: Double { InterestsMetrics.tilt(forIndex: index) }

    var accessibilityIdentifier: String { "interest." + rawValue }
}

/// Which layers a slot shows: the empty slot with its ghost, or the picked stamp with its badge and postmark. Selection
/// never relies on colour alone, so the badge and the postmark are present exactly when the stamp is picked.
struct InterestSlotLayers: Equatable {
    let ghost: Bool
    let stamp: Bool
    let badge: Bool
    let postmark: Bool

    init(isSelected: Bool) {
        ghost = !isSelected
        stamp = isSelected
        badge = isSelected
        postmark = isSelected
    }
}
