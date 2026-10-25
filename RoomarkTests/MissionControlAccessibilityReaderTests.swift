import XCTest
@testable import Roomark

final class MissionControlAccessibilityReaderTests: XCTestCase {
    func testEmptyTitleDoesNotHideLocalizedDescription() {
        XCTAssertEqual(MissionControlAccessibilityReader.nonemptyText(["", "  ", "桌面1"]), "桌面1")
    }

    func testExpandedDesktopThumbnailIsNeverAcceptedAsLabel() {
        let thumbnail = CGRect(x: 80, y: 40, width: 180, height: 120)
        XCTAssertNil(MissionControlAccessibilityReader.labelFrame(role: "AXButton", isTitleElement: false,
                                                                  axFrame: thumbnail, positionAndSize: thumbnail))
    }

    func testActualStaticTextGeometryCanBeUsed() {
        let label = CGRect(x: 80, y: 170, width: 80, height: 18)
        XCTAssertEqual(MissionControlAccessibilityReader.labelFrame(role: "AXStaticText", isTitleElement: false,
                                                                    axFrame: nil, positionAndSize: label), label)
    }

    func testTitleElementKeepsItsOwnGeometryRatherThanParentsThumbnail() {
        let label = CGRect(x: 80, y: 170, width: 80, height: 18)
        XCTAssertEqual(MissionControlAccessibilityReader.labelFrame(role: "AXUnknown", isTitleElement: true,
                                                                    axFrame: label, positionAndSize: nil), label)
    }

    func testMissingAndNonfiniteGeometryAreRejected() {
        XCTAssertNil(MissionControlAccessibilityReader.labelFrame(role: "AXStaticText", isTitleElement: false,
                                                                  axFrame: nil, positionAndSize: nil))
        XCTAssertNil(MissionControlAccessibilityReader.labelFrame(role: "AXStaticText", isTitleElement: false,
                                                                  axFrame: CGRect(x: CGFloat.infinity, y: 20, width: 80, height: 18), positionAndSize: nil))
    }
}
