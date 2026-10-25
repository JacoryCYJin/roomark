import XCTest
@testable import Roomark

final class MissionControlGeometryTests: XCTestCase {
    private func button(y: CGFloat, barHeight: CGFloat) -> MissionControlDesktopButton {
        MissionControlDesktopButton(title: "桌面1", position: CGPoint(x: 501.55078125, y: y),
            size: CGSize(width: 168.57433808553972, height: 129),
            barFrame: CGRect(x: 0, y: 0, width: 1512, height: barHeight),
            displayFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), host: .windowManager)
    }

    func testCapturedExpandedGeometryCoversObservedTextBelowPreview() throws {
        let frame = try XCTUnwrap(MissionControlGeometry.labelFrame(for: button(y: 119.5, barHeight: 188),
            nativeTextWidth: 34, customTextWidth: 24, availableWidth: 164))
        // Text bounds independently read from the user's expanded screenshot.
        let observedText = CGRect(x: 483.488, y: 166.962, width: 32.965, height: 13.181)
        XCTAssertTrue(frame.contains(observedText))
        XCTAssertGreaterThanOrEqual(frame.minY, 161) // preview content ends above the native caption
        XCTAssertEqual(frame.midX, 501.55078125, accuracy: 0.001)
    }

    func testCapturedCollapsedGeometryCoversObservedText() throws {
        let sample = button(y: -0.5, barHeight: 72)
        let collapsed = MissionControlDesktopButton(title: sample.title, position: CGPoint(x: 614.5, y: -0.5),
            size: sample.size, barFrame: sample.barFrame, displayFrame: sample.displayFrame, host: sample.host)
        let frame = try XCTUnwrap(MissionControlGeometry.labelFrame(for: collapsed,
            nativeTextWidth: 38, customTextWidth: 24, availableWidth: 56))
        XCTAssertTrue(frame.contains(CGRect(x: 597.767, y: 46, width: 37.360, height: 15.512)))
        XCTAssertLessThan(frame.maxY, 72)
    }

    func testOffBarAnimationAndNonfiniteGeometryAreRejected() {
        XCTAssertNil(MissionControlGeometry.labelFrame(for: button(y: 119.5, barHeight: 72),
            nativeTextWidth: 34, customTextWidth: 24, availableWidth: 164))
        XCTAssertNil(MissionControlGeometry.labelFrame(for: button(y: .infinity, barHeight: 188),
            nativeTextWidth: 34, customTextWidth: 24, availableWidth: 164))
    }

    func testCrowdedRowCannotLeaveOriginalTextPeekingOut() {
        XCTAssertNil(MissionControlGeometry.labelFrame(for: button(y: 119.5, barHeight: 188),
            nativeTextWidth: 100, customTextWidth: 24, availableWidth: 56))
    }

    func testUnknownLegacyExpandedLayoutIsNotGivenWindowManagerProfile() {
        let sample = button(y: 119.5, barHeight: 188)
        let legacy = MissionControlDesktopButton(title: sample.title, position: sample.position, size: sample.size,
            barFrame: sample.barFrame, displayFrame: sample.displayFrame, host: .dock)
        XCTAssertNil(MissionControlGeometry.labelFrame(for: legacy,
            nativeTextWidth: 34, customTextWidth: 24, availableWidth: 164))
    }

    @MainActor
    func testPartialButtonMappingNeverShowsFirstDesktop() {
        let identity = SpaceIdentity(displayID: "Main", uuid: "first", runtimeID: 4)
        let snapshot = SpaceSnapshot(desktops: [.init(identity: identity, ordinal: 1),
            .init(identity: .init(displayID: "Main", uuid: "second", runtimeID: 9), ordinal: 2)],
            displayIDs: ["Main"], otherSpaceCount: 0)
        let scan = MissionControlScan(state: .desktopListFound, labels: [],
            buttons: [button(y: 119.5, barHeight: 188)], desktopButtonCount: 2, details: "", evidenceRank: 0)
        XCTAssertNil(SpaceLabelResolver.firstDesktopFrame(scan: scan, snapshot: snapshot))
    }
}
