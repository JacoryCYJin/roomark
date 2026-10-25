import AppKit

@MainActor
final class OverlayCoordinator {
    private var panel: LabelPanel?

    func show(axFrame: CGRect) -> Bool {
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) else { hide(); return false }
        let frame = ScreenCoordinateConverter.appKitRect(fromAX: axFrame, primaryScreenHeight: primary.frame.height)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(frame) }), frame.width >= 24 else {
            hide()
            return false
        }
        if let panel, panel.frame != screen.frame { hide() }
        let window = panel ?? LabelPanel(canvasFrame: screen.frame)
        panel = window
        let localFrame = frame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        window.updateLabel(frame: localFrame)
        if !window.isVisible { window.orderFrontRegardless() }
        return window.isVisible
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}
