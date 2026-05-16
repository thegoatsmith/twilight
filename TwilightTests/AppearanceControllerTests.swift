import XCTest
import Combine
@testable import Twilight

final class AppearanceControllerTests: XCTestCase {

    // Bangkok: UTC+7. Sunrise ~23:25 UTC prior day, sunset ~11:31 UTC same day.
    // Daytime Bangkok local noon = 05:00 UTC. Night = 17:00 UTC.
    private let bangkok = Location(latitude: 13.7563, longitude: 100.5018, displayName: "Bangkok")
    private let daytimeUTC = utc(2026, 5, 16, 5, 0)   // noon ICT
    private let nighttimeUTC = utc(2026, 5, 16, 17, 0) // midnight ICT
    private var clock: FakeClock!
    private var applier: SpyThemeApplier!
    private var location: StubLocationProvider!
    private var prefs: PreferencesStore!
    private var defaults: UserDefaults!
    private var controller: AppearanceController!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "TwilightTests.\(UUID().uuidString)")!
        prefs = PreferencesStore(defaults: defaults)
        clock = FakeClock(daytimeUTC)
        applier = SpyThemeApplier()
        location = StubLocationProvider(initial: bangkok)
        controller = AppearanceController(
            clock: clock,
            applier: applier,
            locationProvider: location,
            preferences: prefs
        )
    }

    func test_start_inAutoMode_applies_light_during_bangkok_daytime() {
        applier.current = .dark
        controller.start()
        XCTAssertEqual(applier.applied.last, .light)
        XCTAssertEqual(controller.mode, .auto)
    }

    func test_switchToDark_during_daytime_setsManualDark_andApplies() {
        applier.current = .light    // auto wants light during daytime, system is light
        controller.start()
        applier.applied.removeAll()
        controller.switchToDark()
        XCTAssertEqual(controller.mode, .manualDark)
        XCTAssertEqual(applier.applied.last, .dark)
    }

    func test_switchToLight_during_nighttime_setsManualLight_andApplies() {
        clock.current = nighttimeUTC
        applier.current = .dark     // auto wants dark at night, system is dark
        controller.start()
        applier.applied.removeAll()
        controller.switchToLight()
        XCTAssertEqual(controller.mode, .manualLight)
        XCTAssertEqual(applier.applied.last, .light)
    }

    func test_resumeAuto_returnsToAuto_andRe_applies() {
        applier.current = .light
        controller.start()
        controller.switchToDark()   // now manualDark, applier.current = .dark
        applier.applied.removeAll()
        controller.resumeAuto()
        XCTAssertEqual(controller.mode, .auto)
        // Daytime: auto wants light; currently dark from the manual override → must re-apply light.
        XCTAssertEqual(applier.applied.last, .light)
    }

    func test_overrideExpiry_storedInPrefs() {
        controller.start()
        controller.switchToDark()
        XCTAssertNotNil(prefs.overrideExpiresAt)
        XCTAssertEqual(prefs.mode, .manualDark)
    }

    func test_locationUpdate_recomputes_andApplies() {
        applier.current = .light
        controller.start()
        applier.applied.removeAll()
        // Move clock to night and re-emit location to trigger re-evaluation.
        clock.current = nighttimeUTC
        location.emit(bangkok)
        XCTAssertEqual(applier.applied.last, .dark)
    }
}

private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    c.timeZone = TimeZone(identifier: "UTC")
    return Calendar(identifier: .gregorian).date(from: c)!
}
