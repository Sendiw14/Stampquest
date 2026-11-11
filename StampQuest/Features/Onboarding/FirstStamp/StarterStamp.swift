import SwiftUI

/// One of the three stamps on the desk: its destination, caption, pastel and place in the desk.
enum StarterStamp: String, CaseIterable, Identifiable {
    case paris, kyoto, santorini

    var id: String { rawValue }

    var destination: StampDestination {
        switch self {
        case .paris: .paris
        case .kyoto: .kyoto
        case .santorini: .santorini
        }
    }

    init?(destination: StampDestination) {
        guard let match = Self.allCases.first(where: { $0.destination == destination }) else { return nil }
        self = match
    }

    var paper: Color {
        switch self {
        case .paris: OnbColor.stampCities
        case .kyoto: OnbColor.stampFood
        case .santorini: OnbColor.stampCoasts
        }
    }

    /// Resting tilt on the desk in degrees.
    var deskRotation: Double {
        switch self {
        case .paris: -6
        case .kyoto: 3
        case .santorini: -3
        }
    }

    /// The tilt of the stamp once it sits in slot 1: the page's tilt plus one more degree.
    static let collectedRotation: Double = FirstStampMetrics.pageTilt - 1

    var accessibilityIdentifier: String { "starter." + rawValue }
}
