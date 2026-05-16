import Foundation

public enum SolarCalculator {

    /// Computes sunrise and sunset (UTC) for the given location and calendar date.
    /// `date` is interpreted in UTC: any moment on the desired civil day in UTC.
    /// Returns `nil` for polar day or polar night (sun does not cross the horizon).
    public static func sunTimes(latitude: Double, longitude: Double, date: Date) -> SunTimes? {
        let jd = julianDay(for: date)
        guard let sunrise = sunEvent(jd: jd, latitude: latitude, longitude: longitude, rising: true),
              let sunset  = sunEvent(jd: jd, latitude: latitude, longitude: longitude, rising: false)
        else { return nil }
        return SunTimes(sunrise: sunrise, sunset: sunset)
    }

    // MARK: - NOAA implementation

    private static let zenith = 90.833  // official zenith for sunrise/sunset (incl. refraction)

    /// Julian Day Number for noon UTC of the given date.
    private static func julianDay(for date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        var Y = c.year!
        var M = c.month!
        let D = c.day!
        if M <= 2 { Y -= 1; M += 12 }
        let A = Y / 100
        let B = 2 - A + A / 4
        let jd = floor(365.25 * Double(Y + 4716))
              + floor(30.6001 * Double(M + 1))
              + Double(D) + Double(B) - 1524.5
        return jd + 0.5  // noon
    }

    private static func sunEvent(jd: Double, latitude: Double, longitude: Double, rising: Bool) -> Date? {
        let n = jd - 2451545.0 + 0.0008
        let J = n - longitude / 360.0
        let M = (357.5291 + 0.98560028 * J).truncatingRemainder(dividingBy: 360)
        let Mrad = M * .pi / 180
        let C = 1.9148 * sin(Mrad) + 0.0200 * sin(2 * Mrad) + 0.0003 * sin(3 * Mrad)
        let lambda = (M + C + 180 + 102.9372).truncatingRemainder(dividingBy: 360)
        let lambdaRad = lambda * .pi / 180
        let Jtransit = 2451545.0 + J + 0.0053 * sin(Mrad) - 0.0069 * sin(2 * lambdaRad)
        let sinDelta = sin(lambdaRad) * sin(23.4397 * .pi / 180)
        let delta = asin(sinDelta)
        let latRad = latitude * .pi / 180
        let cosH = (cos(zenith * .pi / 180) - sin(latRad) * sinDelta) / (cos(latRad) * cos(delta))
        guard cosH >= -1.0 && cosH <= 1.0 else { return nil }   // polar
        let H = acos(cosH) * 180 / .pi
        let Jevent = rising ? Jtransit - H / 360.0 : Jtransit + H / 360.0
        return date(fromJulianDay: Jevent)
    }

    private static func date(fromJulianDay jd: Double) -> Date {
        // JD 2440587.5 == 1970-01-01 00:00 UTC
        let seconds = (jd - 2440587.5) * 86400
        return Date(timeIntervalSince1970: seconds)
    }
}
