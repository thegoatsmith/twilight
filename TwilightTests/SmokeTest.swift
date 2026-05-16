import XCTest
@testable import Twilight

final class SmokeTest: XCTestCase {
    func test_bundleLoads() {
        XCTAssertNotNil(Bundle.main)
    }
}
