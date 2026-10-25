import XCTest
@testable import Roomark

final class ScreenCoordinateConverterTests: XCTestCase {
    func testPrimaryDisplayConversion() {
        let rect = CGRect(x: 100, y: 20, width: 80, height: 18)
        XCTAssertEqual(ScreenCoordinateConverter.appKitRect(fromAX: rect, primaryScreenHeight: 982),
                       CGRect(x: 100, y: 944, width: 80, height: 18))
    }

    func testDisplayAbovePrimaryKeepsGlobalCoordinates() {
        let rect = CGRect(x: -1200, y: -800, width: 80, height: 18)
        XCTAssertEqual(ScreenCoordinateConverter.appKitRect(fromAX: rect, primaryScreenHeight: 982),
                       CGRect(x: -1200, y: 1764, width: 80, height: 18))
    }

    func testRecognizesSupportedDesktopLabelsWithoutParsingAppNames() {
        XCTAssertEqual(SpaceLabelResolver.ordinal(in: "桌面 3"), 3)
        XCTAssertEqual(SpaceLabelResolver.ordinal(in: "Desktop 2"), 2)
        XCTAssertEqual(SpaceLabelResolver.ordinal(in: "デスクトップ1"), 1)
        XCTAssertNil(SpaceLabelResolver.ordinal(in: "Safari 3"))
    }

    func testIncompleteMappingNeverProducesOverlayFrame() {
        let identity = SpaceIdentity(displayID: "Main", uuid: "test", runtimeID: 4)
        let snapshot = SpaceSnapshot(desktops: [.init(identity: identity, ordinal: 1),
                                                 .init(identity: .init(displayID: "Main", uuid: "other", runtimeID: 9), ordinal: 2)],
                                     displayIDs: ["Main"], otherSpaceCount: 0)
        XCTAssertNil(SpaceLabelResolver.firstDesktopFrame(labels: [.init(text: "桌面 1", frame: CGRect(x: 0, y: 0, width: 50, height: 20))], snapshot: snapshot))
    }
}
