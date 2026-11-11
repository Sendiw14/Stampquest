import SwiftUI

/// What a fan stamp shows: the onboarding artwork where it exists, otherwise the catalog illustration.
enum FanArt {
    case onboarding(StampArtStyle)
    case catalog(StampDesign)
}

/// One stamp of the Welcome fan: its place in the fan, its artwork and its printed caption.
struct WelcomeStamp: Identifiable {
    let slot: WelcomeMetrics.FanSlot
    let art: FanArt
    let label: String
    let number: String
    let paper: Color

    var id: WelcomeMetrics.FanSlot { slot }

    /// The five fan stamps. Paris, Santorini and Kyoto use their onboarding artwork, Rome and New York the catalog
    /// illustrations; a stamp missing from the catalog is left out.
    static func fan(catalog: Catalog) -> [WelcomeStamp] {
        WelcomeMetrics.FanSlot.allCases.compactMap { slot in
            switch slot {
            case .paris: onboarding(slot, .paris)
            case .santorini: onboarding(slot, .santorini)
            case .kyoto: onboarding(slot, .kyoto)
            case .rome: catalogStamp(slot, number: 4, catalog: catalog)
            case .newYork: catalogStamp(slot, number: 5, catalog: catalog)
            }
        }
    }

    private static func onboarding(_ slot: WelcomeMetrics.FanSlot, _ destination: StampDestination) -> WelcomeStamp {
        WelcomeStamp(slot: slot, art: .onboarding(destination.style), label: destination.label, number: destination.numberLabel,
                     paper: StampArt.borderColor(destination.style))
    }

    private static func catalogStamp(_ slot: WelcomeMetrics.FanSlot, number: Int, catalog: Catalog) -> WelcomeStamp? {
        guard let design = catalog.stamp(forDestination: slot.destinationID) else { return nil }
        return WelcomeStamp(slot: slot, art: .catalog(design), label: design.title.uppercased(),
                            number: String(format: "No. %02d", number), paper: design.borderTint.color)
    }
}
