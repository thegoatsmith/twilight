import Foundation

public enum Mode: String, Codable, Equatable {
    case auto
    case manualLight
    case manualDark
}

public struct Location: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let displayName: String?

    public init(latitude: Double, longitude: Double, displayName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.displayName = displayName
    }
}

public struct SunTimes: Equatable {
    public let sunrise: Date
    public let sunset: Date

    public init(sunrise: Date, sunset: Date) {
        self.sunrise = sunrise
        self.sunset = sunset
    }
}

public enum Appearance: String, Equatable {
    case light
    case dark
}
