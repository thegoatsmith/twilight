import XCTest
@testable import Twilight

final class ScheduleStoreTests: XCTestCase {

    // Use a fixed sun day to keep tests readable:
    // sunrise 06:00 UTC, sunset 18:00 UTC on 2026-05-16.
    private let sunrise = utc(2026, 5, 16, 6, 0)
    private let sunset  = utc(2026, 5, 16, 18, 0)
    private let nextSunrise = utc(2026, 5, 17, 6, 5)   // 5 min later next day
    private let nextSunset  = utc(2026, 5, 17, 17, 55) // 5 min earlier next day

    private func sun() -> SunTimes { SunTimes(sunrise: sunrise, sunset: sunset) }
    private func tomorrow() -> SunTimes { SunTimes(sunrise: nextSunrise, sunset: nextSunset) }

    // MARK: - auto desired appearance

    func test_auto_beforeSunrise_isDark() {
        let now = utc(2026, 5, 16, 4, 0)
        XCTAssertEqual(ScheduleStore.desired(mode: .auto, now: now, today: sun()), .dark)
    }

    func test_auto_betweenSunriseAndSunset_isLight() {
        let now = utc(2026, 5, 16, 12, 0)
        XCTAssertEqual(ScheduleStore.desired(mode: .auto, now: now, today: sun()), .light)
    }

    func test_auto_afterSunset_isDark() {
        let now = utc(2026, 5, 16, 20, 0)
        XCTAssertEqual(ScheduleStore.desired(mode: .auto, now: now, today: sun()), .dark)
    }

    func test_manualLight_alwaysLight() {
        let now = utc(2026, 5, 16, 23, 0)
        XCTAssertEqual(ScheduleStore.desired(mode: .manualLight, now: now, today: sun()), .light)
    }

    func test_manualDark_alwaysDark() {
        let now = utc(2026, 5, 16, 12, 0)
        XCTAssertEqual(ScheduleStore.desired(mode: .manualDark, now: now, today: sun()), .dark)
    }

    // MARK: - next transition

    func test_nextTransition_auto_beforeSunrise_isSunriseToday() {
        let now = utc(2026, 5, 16, 4, 0)
        XCTAssertEqual(ScheduleStore.nextTransition(mode: .auto, now: now, today: sun(), tomorrow: tomorrow()), sunrise)
    }

    func test_nextTransition_auto_betweenSunriseSunset_isSunsetToday() {
        let now = utc(2026, 5, 16, 12, 0)
        XCTAssertEqual(ScheduleStore.nextTransition(mode: .auto, now: now, today: sun(), tomorrow: tomorrow()), sunset)
    }

    func test_nextTransition_auto_afterSunset_isSunriseTomorrow() {
        let now = utc(2026, 5, 16, 20, 0)
        XCTAssertEqual(ScheduleStore.nextTransition(mode: .auto, now: now, today: sun(), tomorrow: tomorrow()), nextSunrise)
    }

    // MARK: - override expiry

    func test_overrideExpiry_manualLight_expiresAtNextSunset() {
        // Daytime: next sunset is today.
        let now = utc(2026, 5, 16, 12, 0)
        XCTAssertEqual(ScheduleStore.overrideExpiry(mode: .manualLight, now: now, today: sun(), tomorrow: tomorrow()), sunset)
    }

    func test_overrideExpiry_manualLight_afterSunset_expiresAtTomorrowSunset() {
        let now = utc(2026, 5, 16, 20, 0)
        XCTAssertEqual(ScheduleStore.overrideExpiry(mode: .manualLight, now: now, today: sun(), tomorrow: tomorrow()), nextSunset)
    }

    func test_overrideExpiry_manualDark_beforeSunrise_expiresAtSunriseToday() {
        let now = utc(2026, 5, 16, 4, 0)
        XCTAssertEqual(ScheduleStore.overrideExpiry(mode: .manualDark, now: now, today: sun(), tomorrow: tomorrow()), sunrise)
    }

    func test_overrideExpiry_manualDark_betweenSunriseSunset_expiresAtTomorrowSunrise() {
        let now = utc(2026, 5, 16, 12, 0)
        XCTAssertEqual(ScheduleStore.overrideExpiry(mode: .manualDark, now: now, today: sun(), tomorrow: tomorrow()), nextSunrise)
    }

    func test_overrideExpiry_auto_isNil() {
        let now = utc(2026, 5, 16, 12, 0)
        XCTAssertNil(ScheduleStore.overrideExpiry(mode: .auto, now: now, today: sun(), tomorrow: tomorrow()))
    }

    // MARK: - helpers

    private static func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }
    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        Self.utc(y, mo, d, h, mi)
    }
}
