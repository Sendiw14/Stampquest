import Foundation

/// The three stamps that have onboarding artwork. The app must not invent more until new art exists.
nonisolated enum StampArtStyle: String, CaseIterable, Sendable {
    case paris, kyoto, santorini
}

/// A destination offered during onboarding. `id` is the id of the matching entry in the main catalog,
/// so collecting it goes through `PassportStore` like any other stamp.
nonisolated struct StampDestination: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let country: String
    /// Printed as "No. 0N" on the stamp.
    let number: Int
    let style: StampArtStyle

    /// Upper-case label printed on the stamp.
    var label: String { name.uppercased() }
    var numberLabel: String { String(format: "No. %02d", number) }

    static let paris = StampDestination(id: "paris-eiffel-tower", name: "Paris", country: "France", number: 1,
                                        style: .paris)
    static let santorini = StampDestination(id: "santorini-oia", name: "Santorini", country: "Greece", number: 2,
                                            style: .santorini)
    static let kyoto = StampDestination(id: "kyoto-fushimi-inari", name: "Kyoto", country: "Japan", number: 3,
                                        style: .kyoto)

    /// Catalog order (Paris, Kyoto, Santorini), used for ties and for the empty-interests tray.
    static let catalog: [StampDestination] = [.paris, .kyoto, .santorini]

    static func with(id: String) -> StampDestination? { catalog.first { $0.id == id } }
}
