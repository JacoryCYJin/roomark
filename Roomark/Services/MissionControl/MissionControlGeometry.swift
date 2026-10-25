import Foundation

struct MissionControlDesktopButton: Equatable {
    enum Host { case windowManager, dock }
    let title: String
    let position: CGPoint
    let size: CGSize
    let barFrame: CGRect
    let displayFrame: CGRect
    let host: Host
}

/// Converts host-specific button geometry into a label band, not a text AX frame.
/// The WindowManager profile is based on this Mac's captured expanded/collapsed
/// row. It is an undocumented layout, and requires visual validation per OS.
enum MissionControlGeometry {
    static let labelHeight: CGFloat = 23
    static let windowManagerLabelCenterInset: CGFloat = 10.5

    static func labelFrame(for button: MissionControlDesktopButton,
                           nativeTextWidth: CGFloat, customTextWidth: CGFloat,
                           availableWidth: CGFloat) -> CGRect? {
        let raw = CGRect(origin: button.position, size: button.size)
        guard isValid(raw), isValid(button.barFrame), isValid(button.displayFrame),
              nativeTextWidth.isFinite, customTextWidth.isFinite, availableWidth.isFinite,
              nativeTextWidth > 0, customTextWidth > 0, availableWidth > 0 else { return nil }

        let center: CGPoint
        switch button.host {
        case .windowManager:
            // AXPosition is a center anchor here. Treating it as the top-left
            // produces a half-thumbnail horizontal and vertical displacement.
            let thumbnail = CGRect(x: raw.minX - raw.width / 2, y: raw.minY - raw.height / 2,
                                   width: raw.width, height: raw.height)
            center = CGPoint(x: button.position.x,
                             y: thumbnail.maxY - windowManagerLabelCenterInset)
        case .dock:
            // Legacy compact buttons already enclose the label. The expanded
            // legacy layout is unverified; do not apply the macOS 27 profile.
            guard raw.height <= 40 else { return nil }
            center = CGPoint(x: raw.midX, y: raw.midY)
        }
        let width = min(ceil(max(nativeTextWidth, customTextWidth)) + 20, availableWidth)
        guard width >= nativeTextWidth + 6, width >= customTextWidth + 6 else { return nil }
        let label = CGRect(x: center.x - width / 2, y: center.y - labelHeight / 2,
                           width: width, height: labelHeight)
        // In-flight/off-screen anchors must not draw in the desktop content.
        guard button.barFrame.contains(label), button.displayFrame.contains(label) else { return nil }
        return label
    }

    static func isValid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.width > 0 && rect.height > 0
    }
}
