#if DEBUG
import Foundation
import UIKit

/// A location provider driven by a launch argument, so UI tests can exercise every
/// verification outcome deterministically. DEBUG builds only.
///
/// Script formats: `denied`, `restricted`, `disabled`, `timeout`, `undetermined-then-allow`,
/// or `lat,lon[,accuracy[,ageSeconds]]` for an authorised device at that position.
@MainActor
final class ScriptedLocationProvider: LocationProviding {
    private enum Mode {
        case denied, restricted, disabled, timeout, allowAfterPrompt
        case fix(lat: Double, lon: Double, accuracy: Double, age: TimeInterval)
    }

    private let mode: Mode
    private var granted = false

    init(script: String) {
        switch script {
        case "denied": mode = .denied
        case "restricted": mode = .restricted
        case "disabled": mode = .disabled
        case "timeout": mode = .timeout
        case "undetermined-then-allow": mode = .allowAfterPrompt
        default:
            let parts = script.split(separator: ",").compactMap { Double($0) }
            if parts.count >= 2 {
                mode = .fix(lat: parts[0], lon: parts[1], accuracy: parts.count > 2 ? parts[2] : 10, age: parts.count > 3 ? parts[3] : 1)
            } else {
                mode = .denied
            }
        }
    }

    func servicesEnabled() async -> Bool {
        if case .disabled = mode { return false }
        return true
    }

    var authorization: LocationAuthorization {
        switch mode {
        case .denied: .denied
        case .restricted: .restricted
        case .allowAfterPrompt: granted ? .authorized : .notDetermined
        default: .authorized
        }
    }

    func requestAuthorization() async -> LocationAuthorization {
        if case .allowAfterPrompt = mode { granted = true }
        return authorization
    }

    func currentReading(timeout: Duration) async throws -> LocationReading {
        switch mode {
        case .timeout:
            try await Task.sleep(for: .milliseconds(300))
            throw VerificationFailure.timeout
        case .fix(let lat, let lon, let accuracy, let age):
            try await Task.sleep(for: .milliseconds(400))
            return LocationReading(latitude: lat, longitude: lon, horizontalAccuracy: accuracy, timestamp: Date().addingTimeInterval(-age))
        case .allowAfterPrompt:
            throw VerificationFailure.unavailable
        default:
            throw VerificationFailure.unavailable
        }
    }
}

/// Fills a debug build with believable data for screenshots and performance checks.
@MainActor
enum DebugSeeder {
    static func seed(_ mode: LaunchConfiguration.Seed, into env: AppEnvironment) {
        if mode == .islandAlmost { seedAlmostCompleteCollection(into: env); return }
        if mode == .memories { seed(.few, into: env); seedMemories(into: env); return }
        let ids = env.catalog.destinations.map(\.id)
        let calendar = Calendar.current
        let count = mode == .many ? min(ids.count - 6, 52) : 5
        let ordered = mode == .many ? ids : ["paris-eiffel-tower", "kyoto-fushimi-inari", "santorini-oia", "rome-colosseum", "sigiriya"]
        let context = env.container.mainContext

        for (i, id) in ordered.prefix(count).enumerated() {
            guard let destination = env.catalog.destination(id: id) else { continue }
            let date = calendar.date(byAdding: .day, value: -(count - i) * 3, to: .now) ?? .now
            let stamp = UserStamp(stampID: destination.stampID, destinationID: id, titleSnapshot: destination.name,
                                  countryCodeSnapshot: destination.countryCode, collectedAt: date, method: .manual)
            if i % 4 == 0 {
                stamp.verification = VisitVerification(id: UUID(), verifiedAt: date, distanceMeters: 120, horizontalAccuracyMeters: 20,
                                                       radiusMeters: destination.verificationRadius, policyVersion: 1)
            }
            stamp.isFavorite = i % 7 == 0
            context.insert(stamp)
        }
        for id in ordered.suffix(from: min(count, ordered.count)).prefix(3) { context.insert(WishlistItem(destinationID: id, addedAt: .now)) }

        if let first = ordered.first {
            let trip = Trip(title: "Summer wanderings", startDate: calendar.date(byAdding: .day, value: -40, to: .now),
                            endDate: calendar.date(byAdding: .day, value: -30, to: .now), notes: "Slow trains and long lunches.",
                            destinationIDs: Array(ordered.prefix(3)), createdAt: .now)
            context.insert(trip)
            context.insert(MemoryEntry(title: "Golden hour", text: "We stayed until the lights came on and nobody wanted to leave.",
                                       createdAt: .now, eventDate: calendar.startOfDay(for: .now), destinationID: first, tripID: trip.id, tags: ["sunset", "friends"]))
            context.insert(MemoryEntry(title: "Best lunch of the trip", text: "A tiny place with no menu. We just pointed and smiled.",
                                       createdAt: .now.addingTimeInterval(-86_400 * 12), eventDate: calendar.date(byAdding: .day, value: -12, to: .now) ?? .now,
                                       destinationID: ordered.dropFirst().first, tags: ["food"]))
        }
        try? context.save()
    }
}

extension DebugSeeder {
    /// Four of the five "Island Escapes" stamps, leaving Oahu to complete the collection.
    static func seedAlmostCompleteCollection(into env: AppEnvironment) {
        let context = env.container.mainContext
        for (i, id) in ["santorini-oia", "bali-tanah-lot", "bora-bora", "whitehaven-beach"].enumerated() {
            guard let d = env.catalog.destination(id: id) else { continue }
            context.insert(UserStamp(stampID: d.stampID, destinationID: id, titleSnapshot: d.name, countryCodeSnapshot: d.countryCode,
                                     collectedAt: Date().addingTimeInterval(Double(-(10 - i)) * 86_400), method: .manual))
        }
        try? context.save()
    }
}

extension DebugSeeder {
    /// Ten memories in three months with every shape (0, 1, 2 and 3 photos), places with and without a stamp, a verified place and
    /// tags. The photos are drawn here (gradients), so nothing real ships and nothing needs the photo library.
    static func seedMemories(into env: AppEnvironment) {
        let context = env.container.mainContext
        let calendar = Calendar.current
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .now }
        func photos(_ n: Int, hue: CGFloat) -> [String] {
            (0..<n).map { i in
                let size = CGSize(width: 900, height: 700)
                let image = UIGraphicsImageRenderer(size: size).image { ctx in
                    let colors = [UIColor(hue: hue + CGFloat(i) * 0.05, saturation: 0.45, brightness: 0.92, alpha: 1).cgColor,
                                  UIColor(hue: hue + 0.08 + CGFloat(i) * 0.05, saturation: 0.6, brightness: 0.62, alpha: 1).cgColor]
                    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
                    ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
                    UIColor.white.withAlphaComponent(0.55).setFill()
                    ctx.cgContext.fillEllipse(in: CGRect(x: 560 - CGFloat(i) * 60, y: 120, width: 120, height: 120))
                }
                let name = UUID().uuidString + ".jpg"
                try? image.jpegData(compressionQuality: 0.8)?.write(to: env.photos.url(for: name))
                return name
            }
        }
        let rows: [(String, String, Date, String?, [String], Int, CGFloat)] = [
            ("Rooftop, last light", "We found the terrace by accident. Bread, a bottle of something local, and the whole city going gold.", day(2026, 11, 5), "rome-colosseum", ["Sunset", "Food"], 3, 0.05),
            ("Trastevere, no map", "Left the phone in the room. Got lost twice and found the best pasta of the trip.", day(2026, 11, 2), "rome-colosseum", ["Food"], 1, 0.08),
            ("Clear at 6:40", "Waited an hour in the cold. The clouds lifted all at once.", day(2026, 10, 28), "mount-fuji", [], 1, 0.58),
            ("Torii at the quiet hour", "Before the tour groups the path belongs to the cedars and one old man sweeping.", day(2026, 10, 27), "kyoto-fushimi-inari", ["Walks", "Early"], 2, 0.02),
            ("", "Mornings are for the river. Nobody talks until the coffee arrives.", day(2026, 10, 19), nil, ["Slow"], 0, 0),
            ("Gelato at midnight", "Third night in a row.", day(2026, 10, 12), "paris-eiffel-tower", ["Food", "Night", "Friends", "Sweet"], 0, 0),
            ("Island ferry", "Salt on everything. Slept the whole way back.", day(2026, 9, 21), "santorini-oia", ["Sea"], 2, 0.55),
            ("Train window", "", day(2026, 9, 14), nil, [], 3, 0.33),
            ("Notes from the market", "Counted six kinds of olives and bought none. Bought apricots instead, which was the right call.", day(2026, 9, 3), "rome-colosseum", ["Food", "Walks"], 0, 0),
            ("The long way home", "Missed the connection, found a bakery.", day(2026, 9, 1), nil, ["Walks"], 1, 0.12),
        ]
        for (title, text, date, place, tags, count, hue) in rows {
            let m = MemoryEntry(title: title, text: text, createdAt: date, eventDate: date, destinationID: place,
                                stampID: place.map { StampID.make(for: $0) }, tags: tags, photoFilenames: photos(count, hue: hue))
            context.insert(m)
        }
        // A memory whose photo file is gone (for example after a restore): it must show the Unavailable tile and stay readable.
        context.insert(MemoryEntry(title: "Lost photo", text: "The file went missing but the words did not.", createdAt: day(2026, 8, 20), eventDate: day(2026, 8, 20),
                                   tags: ["Slow"], photoFilenames: ["missing-photo.jpg"]))
        try? context.save()
    }
}
#endif
