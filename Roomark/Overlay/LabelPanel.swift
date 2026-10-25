import AppKit

@MainActor
final class LabelPanel: NSPanel {
    init(canvasFrame: CGRect) {
        // Never move a visible NSWindow during Mission Control. WindowManager
        // can animate that move independently of AppKit's animate:false flag.
        super.init(contentRect: canvasFrame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        contentView = LabelView(frame: CGRect(origin: .zero, size: canvasFrame.size))
    }

    func updateLabel(frame: CGRect) {
        (contentView as? LabelView)?.updateLabel(frame: frame)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
