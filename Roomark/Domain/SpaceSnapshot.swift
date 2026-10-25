import Foundation

struct DesktopSpace: Identifiable, Equatable, Sendable {
    let identity: SpaceIdentity
    let ordinal: Int
    var id: String { identity.id }
}

struct SpaceSnapshot: Equatable, Sendable {
    let desktops: [DesktopSpace]
    let displayIDs: [String]
    let otherSpaceCount: Int

    static let empty = SpaceSnapshot(desktops: [], displayIDs: [], otherSpaceCount: 0)
}
