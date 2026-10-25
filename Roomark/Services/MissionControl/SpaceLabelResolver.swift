import AppKit

enum SpaceLabelResolver {
    @MainActor
    static func firstDesktopFrame(scan: MissionControlScan, snapshot: SpaceSnapshot) -> CGRect? {
        if let actualText = firstDesktopFrame(labels: scan.labels, snapshot: snapshot) { return actualText }
        guard snapshot.displayIDs.count == 1, snapshot.desktops.first?.identity.hasPersistentIdentity == true,
              scan.buttons.count == snapshot.desktops.count,
              scan.desktopButtonCount == snapshot.desktops.count else { return nil }
        let ordinals = scan.buttons.compactMap { ordinal(in: $0.title) }
        guard Set(ordinals) == Set(snapshot.desktops.map(\.ordinal)),
              ordinals.count == Set(ordinals).count,
              let first = scan.buttons.first(where: { ordinal(in: $0.title) == 1 }),
              scan.buttons.allSatisfy({ $0.displayFrame == first.displayFrame && $0.barFrame == first.barFrame }) else { return nil }
        let x = centerX(first)
        let gaps = scan.buttons.filter { $0.title != first.title }.map { abs(centerX($0) - x) }
        let availableWidth = min(first.size.width, (gaps.min() ?? first.size.width) - 4)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium)]
        return MissionControlGeometry.labelFrame(for: first,
            nativeTextWidth: (first.title as NSString).size(withAttributes: attributes).width,
            customTextWidth: ("开发" as NSString).size(withAttributes: attributes).width,
            availableWidth: availableWidth)
    }

    private static func centerX(_ button: MissionControlDesktopButton) -> CGFloat {
        button.host == .windowManager ? button.position.x : button.position.x + button.size.width / 2
    }

    static func ordinal(in text: String) -> Int? {
        // Explicit supported locales; never parse an arbitrary number from app names.
        let pattern = #"^(?:Desktop|Space|桌面|デスクトップ)\s*([0-9]+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[range])
    }

    static func firstDesktopFrame(labels: [MissionControlLabel], snapshot: SpaceSnapshot) -> CGRect? {
        // The probe supports one active display group only. Multi-display mapping
        // requires separately verified AX display identities, not array order.
        guard snapshot.displayIDs.count == 1,
              snapshot.desktops.first?.identity.hasPersistentIdentity == true else { return nil }
        let mapped = labels.compactMap { label -> (Int, CGRect)? in
            guard let ordinal = ordinal(in: label.text) else { return nil }
            return (ordinal, label.frame)
        }
        guard mapped.count == snapshot.desktops.count,
              Set(mapped.map(\.0)) == Set(snapshot.desktops.map(\.ordinal)),
              let first = mapped.first(where: { $0.0 == 1 }) else { return nil }
        return first.1
    }
}
