import AppKit
import QuartzCore

@MainActor
final class LabelView: NSView {
    private let label = NSTextField(labelWithString: "开发")
    private let pill = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 5
        pill.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1).cgColor
        addSubview(pill)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    func updateLabel(frame: CGRect) {
        guard pill.frame != frame else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            pill.frame = frame
            pill.layoutSubtreeIfNeeded()
        }
        CATransaction.commit()
    }
}
