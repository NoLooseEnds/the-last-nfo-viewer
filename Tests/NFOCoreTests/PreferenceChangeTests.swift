import Foundation
import XCTest
@testable import NFOCore

final class PreferenceChangeTests: XCTestCase {
    func testNotificationCarriesOnlySpecifiedChanges() {
        let expected: Set<PreferenceChange> = [.copyFormat, .windowSizing]
        let notification = Notification(
            name: Constants.Notifications.preferencesChanged,
            userInfo: PreferenceChange.userInfo(for: expected)
        )

        XCTAssertEqual(PreferenceChange.changes(from: notification), expected)
    }

    func testLegacyNotificationFallsBackToAllChanges() {
        let notification = Notification(name: Constants.Notifications.preferencesChanged)
        XCTAssertEqual(
            PreferenceChange.changes(from: notification),
            Set(PreferenceChange.allCases)
        )
    }
}
