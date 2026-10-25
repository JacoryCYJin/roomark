import AppKit
import XCTest
@testable import Roomark

final class OverlayCoordinatorTests: XCTestCase {
    @MainActor
    func testMovingLabelKeepsWindowFixedAndHideRetiresIt() throws {
        let primary = try XCTUnwrap(NSScreen.screens.first(where: { $0.frame.origin == .zero }))
        let coordinator = OverlayCoordinator()
        defer { coordinator.hide() }
        XCTAssertTrue(coordinator.show(axFrame: CGRect(x: 100, y: 42, width: 52, height: 23)))
        let canvas = try XCTUnwrap(NSApp.windows.compactMap { $0 as? LabelPanel }.first(where: \.isVisible))
        let number = canvas.windowNumber
        XCTAssertEqual(canvas.frame, primary.frame)

        XCTAssertTrue(coordinator.show(axFrame: CGRect(x: 250, y: 162, width: 52, height: 23)))
        XCTAssertEqual(canvas.windowNumber, number)
        XCTAssertEqual(canvas.frame, primary.frame, "Following a label must not move a visible system window")
        XCTAssertTrue(canvas.ignoresMouseEvents)
        coordinator.hide()
        XCTAssertFalse(canvas.isVisible)

        XCTAssertTrue(coordinator.show(axFrame: CGRect(x: 100, y: 42, width: 52, height: 23)))
        let replacement = try XCTUnwrap(NSApp.windows.compactMap { $0 as? LabelPanel }.first(where: \.isVisible))
        XCTAssertFalse(replacement === canvas, "A closed canvas must not be retained between sessions")
    }
}
