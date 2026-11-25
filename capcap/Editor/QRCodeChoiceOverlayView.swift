import AppKit

struct QRCodeChoice {
    let payload: String
    let anchorRect: NSRect
}

final class QRCodeChoiceOverlayView: NSView {
    private let choices: [QRCodeChoice]
    private let onChoose: (QRCodeChoice) -> Void
    private var choiceButtons: [QRCodeChoiceButton] = []

    init(frame frameRect: NSRect, choices: [QRCodeChoice], onChoose: @escaping (QRCodeChoice) -> Void) {
        self.choices = choices
        self.onChoose = onChoose
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        setupButtons()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0 else { return nil }
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return nil }
        for subview in subviews.reversed() {
            if let hit = subview.hitTest(localPoint) {
                return hit
            }
        }
        return nil
    }

    override func layout() {
        super.layout()
        layoutButtons()
    }

    private func setupButtons() {
        for choice in choices {
            let button = QRCodeChoiceButton(frame: .zero)
            button.toolTip = L10n.copyQRCodeContent
            button.onClick = { [weak self] in
                self?.onChoose(choice)
            }
            choiceButtons.append(button)
            addSubview(button)
        }
        layoutButtons()
    }

    private func layoutButtons() {
        let size: CGFloat = 64
        let margin = size / 2 + 4
        for (index, choice) in choices.enumerated() where index < choiceButtons.count {
            var center = NSPoint(x: choice.anchorRect.midX, y: choice.anchorRect.midY)
            if bounds.width > size {
                center.x = min(max(center.x, margin), bounds.width - margin)
            }
            if bounds.height > size {
                center.y = min(max(center.y, margin), bounds.height - margin)
            }
            choiceButtons[index].frame = NSRect(
                x: center.x - size / 2,
                y: center.y - size / 2,
                width: size,
                height: size
            )
        }
    }
}

private final class QRCodeChoiceButton: NSButton {
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        if #available(macOS 26.0, *) {
            bezelStyle = .glass
        } else {
            bezelStyle = .rounded
        }
        image = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: L10n.copyQRCodeContent)?
            .withSymbolConfiguration(.init(pointSize: 22, weight: .semibold))
        imagePosition = .imageOnly
        contentTintColor = .controlAccentColor
        setAccessibilityLabel(L10n.copyQRCodeContent)
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(clicked)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func clicked() {
        onClick?()
    }
}
