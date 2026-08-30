import CoreGraphics
import XCTest
@testable import NFOCore

final class NFOLayoutPolicyTests: XCTestCase {
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 1_000)
    private let currentFrame = CGRect(x: 100, y: 100, width: 800, height: 600)

    func testDifferentDocumentsProduceIndependentWidths() {
        let narrow = NFOLayoutPolicy.autoFitFrame(
            idealWindowSize: CGSize(width: 420, height: 400),
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )
        let wide = NFOLayoutPolicy.autoFitFrame(
            idealWindowSize: CGSize(width: 1_100, height: 400),
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(narrow.width, 420)
        XCTAssertEqual(wide.width, 1_100)
    }

    func testContentThatFitsUsesItsNaturalHeight() {
        let frame = NFOLayoutPolicy.autoFitFrame(
            idealWindowSize: CGSize(width: 500, height: 760),
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.size, CGSize(width: 500, height: 760))
    }

    func testOversizedContentUsesSeventyFivePercentHeightAndScreenWidth() {
        let frame = NFOLayoutPolicy.autoFitFrame(
            idealWindowSize: CGSize(width: 2_000, height: 1_200),
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.width, visibleFrame.width)
        XCTAssertEqual(frame.height, 750)
        XCTAssertEqual(frame.minX, visibleFrame.minX)
    }

    func testSmallContentUsesMinimumWindowSize() {
        let frame = NFOLayoutPolicy.autoFitFrame(
            idealWindowSize: CGSize(width: 100, height: 80),
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.size, CGSize(width: 240, height: 240))
    }

    func testPreviewUsesNaturalSizeWhenItFits() {
        let size = NFOLayoutPolicy.autoFitSize(
            idealSize: CGSize(width: 620, height: 540),
            visibleSize: visibleFrame.size
        )

        XCTAssertEqual(size, CGSize(width: 620, height: 540))
    }

    func testOversizedPreviewIsConstrainedForScrolling() {
        let size = NFOLayoutPolicy.autoFitSize(
            idealSize: CGSize(width: 2_000, height: 1_200),
            visibleSize: visibleFrame.size
        )

        XCTAssertEqual(size, CGSize(width: 1_440, height: 750))
    }

    func testAlignmentUsesTheViewportWithoutHorizontalScrolling() {
        let left = NFOLayoutPolicy.contentLayout(
            contentWidth: 300,
            availableWidth: 1_000,
            alignment: .left
        )
        let center = NFOLayoutPolicy.contentLayout(
            contentWidth: 300,
            availableWidth: 1_000,
            alignment: .center
        )
        let right = NFOLayoutPolicy.contentLayout(
            contentWidth: 300,
            availableWidth: 1_000,
            alignment: .right
        )

        XCTAssertEqual(left.horizontalInset, 20)
        XCTAssertEqual(center.horizontalInset, 350)
        XCTAssertEqual(right.horizontalInset, 680)
        XCTAssertFalse(left.scrollsHorizontally)
        XCTAssertFalse(center.scrollsHorizontally)
        XCTAssertFalse(right.scrollsHorizontally)
        XCTAssertEqual(right.textViewWidth, 1_000)
    }

    func testWideContentEnablesHorizontalScrolling() {
        let layout = NFOLayoutPolicy.contentLayout(
            contentWidth: 1_000,
            availableWidth: 800,
            alignment: .right
        )

        XCTAssertTrue(layout.scrollsHorizontally)
        XCTAssertEqual(layout.textViewWidth, 1_040)
        XCTAssertEqual(layout.textContainerWidth, 1_040)
        XCTAssertEqual(layout.horizontalInset, 20)
    }

    func testContentThatExactlyFitsDoesNotEnableHorizontalScrolling() {
        let layout = NFOLayoutPolicy.contentLayout(
            contentWidth: 300,
            availableWidth: 340,
            alignment: .right
        )

        XCTAssertFalse(layout.scrollsHorizontally)
        XCTAssertEqual(layout.textViewWidth, 340)

        let fractionalLayout = NFOLayoutPolicy.contentLayout(
            contentWidth: 300,
            availableWidth: 339.5,
            alignment: .right
        )
        XCTAssertFalse(fractionalLayout.scrollsHorizontally)
    }
}
