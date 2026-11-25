import AppKit

/// Single-instance hover tooltip used by the editor toolbar
final class ToolTipWindow: NSPanel {
    private static var current: ToolTipWindow?
    private static var pendingWorkItem: DispatchWorkItem?

    /// `anchor` is the screen-space rect of the hovered control. The tip
    /// pops above it, horizontally centered.
    static func show(text: String, anchor: NSRect, delay: TimeInterval = 0.35) {
        cancelPending()
        let work = DispatchWorkItem {
            present(text: text, anchor: anchor)
        }
        pendingWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    static func hide() {
        cancelPending()
        current?.orderOut(nil)
        current = nil
    }

    private static func cancelPending() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }

    private static func present(text: String, anchor: NSRect) {
        current?.orderOut(nil)

        let tip = ToolTipWindow(text: text)
        current = tip

        let gap: CGFloat = 6
        var origin = NSPoint(x: anchor.midX - tip.frame.width / 2, y: anchor.maxY + gap)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) }) {
            let visible = screen.visibleFrame.insetBy(dx: 4, dy: 4)
            origin.x = max(visible.minX, min(origin.x, visible.maxX - tip.frame.width))
            if origin.y + tip.frame.height > visible.maxY {
                origin.y = max(visible.minY, anchor.minY - gap - tip.frame.height)
            }
        }
        tip.setFrameOrigin(origin)

        tip.alphaValue = 0
        tip.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.12
            tip.animator().alphaValue = 1.0
        }
    }

    private init(text: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ]
        let textSize = text.size(withAttributes: attrs)
        let size = NSSize(
            width: ceil(textSize.width) + 16,
            height: 22
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver + 4
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let surface = FloatingGlassView(
            frame: NSRect(origin: .zero, size: size),
            cornerRadius: size.height / 2,
            fallbackMaterial: .toolTip
        )
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.sizeToFit()
        label.setFrameOrigin(NSPoint(x: (size.width - label.frame.width) / 2, y: (size.height - label.frame.height) / 2))
        surface.content.addSubview(label)
        contentView = surface
    }
}
