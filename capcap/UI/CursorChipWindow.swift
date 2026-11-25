import AppKit

class CursorChipWindow: NSPanel {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let chipView: ChipView

    init(text: String = L10n.dragToScreenshot) {
        let chipSize = ChipView.fittingSize(for: text)
        self.chipView = ChipView(frame: NSRect(origin: .zero, size: chipSize), text: text)
        super.init(
            contentRect: NSRect(origin: .zero, size: chipSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver + 1
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        sharingType = .none

        contentView = FloatingGlassView(
            frame: NSRect(origin: .zero, size: chipSize),
            content: chipView,
            cornerRadius: chipSize.height / 2
        )
    }

    func updateText(_ text: String) {
        guard chipView.text != text else { return }
        let chipSize = ChipView.fittingSize(for: text)
        setContentSize(chipSize)
        chipView.frame = NSRect(origin: .zero, size: chipSize)
        chipView.text = text
        updatePosition()
    }

    func show() {
        updatePosition()
        orderFrontRegardless()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.updatePosition()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.updatePosition()
            return event
        }
    }

    func dismiss() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        orderOut(nil)
    }

    private func updatePosition() {
        let loc = NSEvent.mouseLocation
        var origin = NSPoint(x: loc.x + 15, y: loc.y - 40)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(loc) }) {
            let visible = screen.frame.insetBy(dx: 4, dy: 4)
            if origin.x + frame.width > visible.maxX {
                origin.x = max(visible.minX, loc.x - 15 - frame.width)
            }
            if origin.y < visible.minY {
                origin.y = min(visible.maxY - frame.height, loc.y + 15)
            }
        }
        setFrameOrigin(origin)
    }
}

private final class ChipView: NSView {
    private static let maxWidth: CGFloat = 560
    private static let height: CGFloat = 32
    private static let horizontalPadding: CGFloat = 28
    private static let font = NSFont.systemFont(ofSize: 12, weight: .medium)
    private let label = NSTextField(labelWithString: "")

    var text: String {
        get { label.stringValue }
        set { label.stringValue = newValue }
    }

    init(frame frameRect: NSRect, text: String) {
        super.init(frame: frameRect)
        label.stringValue = text
        label.font = Self.font
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding / 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding / 2),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func fittingSize(for text: String) -> NSSize {
        let textWidth = ceil(text.size(withAttributes: [.font: font]).width)
        return NSSize(width: min(textWidth + horizontalPadding, maxWidth), height: height)
    }
}
