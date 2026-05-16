import XCTest
@testable import Twilight

final class SolarCalculatorTests: XCTestCase {

    // Reference values from NOAA Solar Calculator (https://gml.noaa.gov/grad/solcalc/)
    // Tolerance: ±2 minutes (algorithm is accurate to ~1 min).

    func test_bangkok_equinox_march_2024() throws {
        // Bangkok 13.7563° N, 100.5018° E, 2024-03-20
        let date = Self.utcDate(2024, 3, 20)
        let sun = try XCTUnwrap(SolarCalculator.sunTimes(latitude: 13.7563, longitude: 100.5018, date: date))
        // NOAA: sunrise 06:25 ICT (= 23:25 UTC prior day), sunset 18:31 ICT (= 11:31 UTC)
        // Compare in UTC.
        Self.assertTimeOfDay(sun.sunrise, hourUTC: 23, minuteUTC: 25, dayOffset: -1, file: #filePath, line: #line)
        Self.assertTimeOfDay(sun.sunset, hourUTC: 11, minuteUTC: 31, dayOffset: 0, file: #filePath, line: #line)
    }

    func test_newyork_summer_solstice_2024() throws {
        // NYC 40.7128° N, -74.0060° W, 2024-06-20
        let date = Self.utcDate(2024, 6, 20)
        let sun = try XCTUnwrap(SolarCalculator.sunTimes(latitude: 40.7128, longitude: -74.0060, date: date))
        // NOAA: sunrise 05:24 EDT (09:24 UTC), sunset 20:31 EDT (00:31 UTC next day)
        Self.assertTimeOfDay(sun.sunrise, hourUTC: 9, minuteUTC: 24, dayOffset: 0, file: #filePath, line: #line)
        Self.assertTimeOfDay(sun.sunset, hourUTC: 0, minuteUTC: 31, dayOffset: 1, file: #filePath, line: #line)
    }

    func test_sydney_winter_solstice_2024() throws {
        // Sydney -33.8688° S, 151.2093° E, 2024-06-21
        let date = Self.utcDate(2024, 6, 21)
        let sun = try XCTUnwrap(SolarCalculator.sunTimes(latitude: -33.8688, longitude: 151.2093, date: date))
        // NOAA: sunrise 07:01 AEST (21:01 UTC prior day), sunset 16:54 AEST (06:54 UTC)
        Self.assertTimeOfDay(sun.sunrise, hourUTC: 21, minuteUTC: 1, dayOffset: -1, file: #filePath, line: #line)
        Self.assertTimeOfDay(sun.sunset, hourUTC: 6, minuteUTC: 54, dayOffset: 0, file: #filePath, line: #line)
    }

    func test_tromso_polar_day_returns_nil() {
        // Tromsø 69.6492° N — polar day on 2024-06-21 (sun never sets)
        let date = Self.utcDate(2024, 6, 21)
        let sun = SolarCalculator.sunTimes(latitude: 69.6492, longitude: 18.9553, date: date)
        XCTAssertNil(sun)
    }

    func test_tromso_polar_night_returns_nil() {
        // Tromsø — polar night on 2024-12-21 (sun never rises)
        let date = Self.utcDate(2024, 12, 21)
        let sun = SolarCalculator.sunTimes(latitude: 69.6492, longitude: 18.9553, date: date)
        XCTAssertNil(sun)
    }

    func test_equator_equinox_roughly_six_to_six() throws {
        let date = Self.utcDate(2024, 3, 20)
        let sun = try XCTUnwrap(SolarCalculator.sunTimes(latitude: 0.0, longitude: 0.0, date: date))
        // At lat=0, lng=0 on equinox: sunrise ~06:06 UTC, sunset ~18:13 UTC (equation of time).
        Self.assertTimeOfDay(sun.sunrise, hourUTC: 6, minuteUTC: 6, dayOffset: 0, file: #filePath, line: #line)
        Self.assertTimeOfDay(sun.sunset, hourUTC: 18, minuteUTC: 13, dayOffset: 0, file: #filePath, line: #line)
    }

    // MARK: - Helpers

    private static func utcDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private static func assertTimeOfDay(_ date: Date,
                                        hourUTC: Int,
                                        minuteUTC: Int,
                                        dayOffset: Int,
                                        file: StaticString,
                                        line: UInt) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let totalActual = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let totalExpected = hourUTC * 60 + minuteUTC
        let delta = abs(totalActual - totalExpected)
        XCTAssertLessThanOrEqual(delta, 2,
            "expected \(hourUTC):\(minuteUTC) UTC (dayOffset \(dayOffset)), got \(comps.hour ?? -1):\(comps.minute ?? -1)",
            file: file, line: line)
    }
}
