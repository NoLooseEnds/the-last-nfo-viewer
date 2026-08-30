import XCTest
@testable import NFOCore

final class FontSizeTests: XCTestCase {
    func testInvalidAndOutOfRangeStoredValuesAreNormalized() {
        XCTAssertEqual(Constants.FontSize.normalized(0), 14)
        XCTAssertEqual(Constants.FontSize.normalized(.infinity), 14)
        XCTAssertEqual(Constants.FontSize.normalized(2), 8)
        XCTAssertEqual(Constants.FontSize.normalized(100), 72)
        XCTAssertEqual(Constants.FontSize.normalized(18), 18)
    }
}
