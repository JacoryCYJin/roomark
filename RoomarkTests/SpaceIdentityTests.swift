import XCTest
@testable import Roomark

final class SpaceIdentityTests: XCTestCase {
    // Fictional valid UUIDs; never publish identifiers copied from a user's Mac.
    private let first = "11111111-1111-4111-8111-111111111111"
    private let second = "22222222-2222-4222-8222-222222222222"

    private func config(_ spaces: [[String: Any]]) -> [String: Any] {
        ["Management Data": ["Monitors": [["Display Identifier": "Main", "Spaces": spaces]]]]
    }

    private func desktop(_ id: Int, _ uuid: String, type: Int = 0) -> [String: Any] {
        ["id64": id, "uuid": uuid, "type": type]
    }

    func testReorderingPreservesUUIDAndChangesOrdinal() throws {
        let a = desktop(4, first), b = desktop(9, second)
        let before = try SpacePreferencesReader.parse(config([a, b]))
        let after = try SpacePreferencesReader.parse(config([b, a]))
        XCTAssertEqual(before.desktops[0].id, after.desktops[1].id)
        XCTAssertEqual(after.desktops[1].ordinal, 2)
    }

    func testExcludesFullscreenAndIgnoresNestedSpaceRecords() throws {
        var full = desktop(524, second, type: 4)
        full["nested"] = [desktop(7, second)]
        let result = try SpacePreferencesReader.parse(config([desktop(4, first), full]))
        XCTAssertEqual(result.desktops.count, 1)
        XCTAssertEqual(result.otherSpaceCount, 1)
    }

    func testDuplicateUUIDFailsClosed() {
        XCTAssertThrowsError(try SpacePreferencesReader.parse(config([desktop(4, first), desktop(9, first)])))
    }

    func testMissingUUIDHasOnlySessionIdentity() throws {
        let result = try SpacePreferencesReader.parse(config([["id64": 4, "type": 0]]))
        XCTAssertFalse(try XCTUnwrap(result.desktops.first).identity.hasPersistentIdentity)
    }

    func testDifferentRuntimeIDRetainsDurableKey() {
        let a = SpaceIdentity(displayID: "Main", uuid: first, runtimeID: 4)
        let b = SpaceIdentity(displayID: "Main", uuid: first, runtimeID: 99)
        XCTAssertEqual(a.id, b.id)
    }
}
