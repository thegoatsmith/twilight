import XCTest
@testable import Twilight

final class PreferencesStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var prefs: PreferencesStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PreferencesStoreTests-\(UUID().uuidString)")
        prefs = PreferencesStore(defaults: defaults)
    }

    override func tearDown() {
        defaults = nil
        prefs = nil
        super.tearDown()
    }

    func test_didFinishOnboarding_defaultsToFalse() {
        XCTAssertFalse(prefs.didFinishOnboarding)
    }

    func test_didFinishOnboarding_persists() {
        prefs.didFinishOnboarding = true
        XCTAssertTrue(prefs.didFinishOnboarding)

        let reread = PreferencesStore(defaults: defaults)
        XCTAssertTrue(reread.didFinishOnboarding)
    }
}
