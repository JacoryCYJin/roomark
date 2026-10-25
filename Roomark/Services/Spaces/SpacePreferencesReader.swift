import Foundation

/// Reads undocumented preferences, not a public live Spaces API.
@MainActor
struct SpacePreferencesReader: SpaceProvider {
    func readSnapshot() throws -> SpaceSnapshot {
        let domain = "com.apple.spaces" as CFString
        CFPreferencesAppSynchronize(domain)
        guard let config = CFPreferencesCopyAppValue("SpacesDisplayConfiguration" as CFString, domain)
            as? [String: Any] else { throw SpaceReadError.missingConfiguration }
        return try Self.parse(config)
    }

    nonisolated static func parse(_ configuration: [String: Any]) throws -> SpaceSnapshot {
        guard let management = configuration["Management Data"] as? [String: Any],
              let monitors = management["Monitors"] as? [[String: Any]] else {
            throw SpaceReadError.missingConfiguration
        }
        var desktops: [DesktopSpace] = []
        var displayIDs: [String] = []
        var seen = Set<String>()
        var otherCount = 0
        for monitor in monitors {
            guard let spaces = monitor["Spaces"] as? [[String: Any]], !spaces.isEmpty,
                  let displayID = monitor["Display Identifier"] as? String else { continue }
            guard !displayIDs.contains(displayID) else { throw SpaceReadError.invalidIdentity }
            displayIDs.append(displayID)
            var ordinal = 0
            for space in spaces {
                guard let type = space["type"] as? NSNumber else { throw SpaceReadError.invalidIdentity }
                guard type.intValue == 0 else { otherCount += 1; continue }
                guard let number = (space["id64"] ?? space["ManagedSpaceID"]) as? NSNumber,
                      number.uint64Value > 0 else { throw SpaceReadError.invalidIdentity }
                let raw = space["uuid"] as? String
                let uuid = raw.flatMap { UUID(uuidString: $0)?.uuidString }
                let identity = SpaceIdentity(displayID: displayID, uuid: uuid, runtimeID: number.uint64Value)
                guard seen.insert(identity.id).inserted else { throw SpaceReadError.invalidIdentity }
                ordinal += 1
                desktops.append(DesktopSpace(identity: identity, ordinal: ordinal))
            }
        }
        return SpaceSnapshot(desktops: desktops, displayIDs: displayIDs, otherSpaceCount: otherCount)
    }
}
