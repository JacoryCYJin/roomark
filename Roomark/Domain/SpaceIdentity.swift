import Foundation

struct SpaceIdentity: Hashable, Sendable, Identifiable {
    let displayID: String
    let uuid: String?
    let runtimeID: UInt64

    // Runtime IDs are diagnostic/session identities, never a durable name key.
    var id: String { uuid ?? "session:\(displayID):\(runtimeID)" }
    var hasPersistentIdentity: Bool { uuid != nil }
}
