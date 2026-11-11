import Foundation

/// The light at a destination right now, derived offline from its coordinates and the current instant.
nonisolated enum DestinationPhase: Equatable, Sendable {
    case night, firstLight, eveningLight, sunrise, sunset, morningLight, goldenHour, morning, midday, afternoon

    var phrase: String {
        switch self {
        case .night: String(localized: "night")
        case .firstLight: String(localized: "first light")
        case .eveningLight: String(localized: "evening light")
        case .sunrise: String(localized: "sunrise")
        case .sunset: String(localized: "sunset")
        case .morningLight: String(localized: "morning light")
        case .goldenHour: String(localized: "golden hour")
        case .morning: String(localized: "morning")
        case .midday: String(localized: "midday")
        case .afternoon: String(localized: "afternoon")
        }
    }
}

/// NOAA-style simplified solar position: good to about a degree, which is all a phase label needs. No network.
nonisolated enum DestinationPhaseCalculator {
    /// Sun altitude and hour angle in degrees. A negative hour angle means the sun has not yet crossed the meridian.
    static func solar(latitude: Double, longitude: Double, at date: Date) -> (altitude: Double, hourAngle: Double) {
        let rad = Double.pi / 180
        let n = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let meanLongitude = (280.460 + 0.9856474 * n).truncatingRemainder(dividingBy: 360)
        let anomaly = ((357.528 + 0.9856003 * n).truncatingRemainder(dividingBy: 360)) * rad
        let eclipticLongitude = (meanLongitude + 1.915 * sin(anomaly) + 0.020 * sin(2 * anomaly)) * rad
        let obliquity = (23.439 - 0.0000004 * n) * rad
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude)) / rad
        let gmstDegrees = ((18.697374558 + 24.06570982441908 * n).truncatingRemainder(dividingBy: 24)) * 15
        var hour = (gmstDegrees + longitude - rightAscension).truncatingRemainder(dividingBy: 360)
        if hour > 180 { hour -= 360 }
        if hour < -180 { hour += 360 }
        let lat = latitude * rad
        let altitude = asin(sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hour * rad)) / rad
        return (altitude, hour)
    }

    static func phase(latitude: Double, longitude: Double, at date: Date) -> DestinationPhase {
        let (alt, hour) = solar(latitude: latitude, longitude: longitude, at: date)
        let rising = hour < 0
        switch alt {
        case ..<(-12): return .night
        case ..<(-0.8): return rising ? .firstLight : .eveningLight
        case ..<4: return rising ? .sunrise : .sunset
        case ..<15: return rising ? .morningLight : .goldenHour
        default: return abs(hour) < 15 ? .midday : (rising ? .morning : .afternoon)
        }
    }
}
