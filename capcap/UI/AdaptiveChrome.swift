import AppKit

/// Shared semantic colors for capcap's floating dialogs and editor chrome
///
/// AppKit semantic colors already follow the effective appearance when they
/// are used for text or drawing. Layer colors are different: assigning a
/// `CGColor` resolves the color once, so layer-backed views must resolve again
/// from `viewDidChangeEffectiveAppearance`
enum AdaptiveChrome {
    static let panelBackground = NSColor.windowBackgroundColor
    static let cardBackground = NSColor.quaternarySystemFill
    static let border = NSColor.separatorColor
    static let subtleFill = NSColor.quaternarySystemFill
    static let selectedFill = NSColor.tertiarySystemFill
    static let separator = NSColor.separatorColor

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func resolvedColor(_ color: NSColor, for appearance: NSAppearance) -> NSColor {
        var resolved = color
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.deviceRGB) ?? color
        }
        return resolved
    }

    static func resolvedCGColor(_ color: NSColor, for appearance: NSAppearance) -> CGColor {
        resolvedColor(color, for: appearance).cgColor
    }
}

/// Shared geometry and surface metrics for compact floating operation bars
/// such as the recording HUD and the PIN image toolbar
enum FloatingControlChrome {
    static let height: CGFloat = 32
    static let buttonSide: CGFloat = 24
    static let cornerRadius = height / 2
    static let gap: CGFloat = 8
    static let screenEdgeInset: CGFloat = 4

    static func origin(
        for size: NSSize,
        relativeTo anchorRect: NSRect,
        visibleFrame: NSRect?
    ) -> NSPoint {
        var origin = NSPoint(
            x: anchorRect.maxX - size.width - gap,
            y: anchorRect.maxY + gap
        )

        guard let visibleFrame else { return origin }
        if origin.y + size.height > visibleFrame.maxY {
            origin.y = anchorRect.minY - size.height - gap
        }
        origin.x = max(
            visibleFrame.minX + screenEdgeInset,
            min(origin.x, visibleFrame.maxX - size.width - screenEdgeInset)
        )
        origin.y = max(
            visibleFrame.minY + screenEdgeInset,
            min(origin.y, visibleFrame.maxY - size.height - screenEdgeInset)
        )
        return origin
    }
}

/// A system material for floating controls and transient panels
final class FloatingGlassView: NSView {
    let content: NSView

    init(
        frame: NSRect = .zero,
        content: NSView? = nil,
        cornerRadius: CGFloat,
        interactive: Bool = false,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        fallbackMaterial: NSVisualEffectView.Material = .popover
    ) {
        let content = content ?? NSView()
        self.content = content
        super.init(frame: frame)

        let background: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: bounds)
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            glass.contentView = content
            #if compiler(>=6.4)
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = interactive
            }
            #endif
            background = glass
        } else {
            let material = NSVisualEffectView(frame: bounds)
            material.material = fallbackMaterial
            material.blendingMode = blendingMode
            material.state = .active
            material.wantsLayer = true
            material.layer?.cornerRadius = cornerRadius
            material.layer?.cornerCurve = .continuous
            material.layer?.masksToBounds = true
            material.addSubview(content)
            background = material
        }
        background.autoresizingMask = [.width, .height]
        addSubview(background)
        content.frame = background.bounds
        content.autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// A single material behind a control group embedded in a larger view
class FloatingToolbarView: NSView {
    private let surface: FloatingGlassView
    var controls: NSView { surface.content }

    init(
        frame: NSRect,
        cornerRadius: CGFloat,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    ) {
        surface = FloatingGlassView(
            frame: NSRect(origin: .zero, size: frame.size),
            cornerRadius: cornerRadius,
            interactive: true,
            blendingMode: blendingMode
        )
        super.init(frame: frame)
        surface.autoresizingMask = [.width, .height]
        addSubview(surface)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Layer-backed rounded surface whose colors continue to follow live system
/// appearance changes
final class AdaptiveChromeSurfaceView: NSView {
    enum Style {
        case panel
        case card

        var backgroundColor: NSColor {
            switch self {
            case .panel: return AdaptiveChrome.panelBackground
            case .card: return AdaptiveChrome.cardBackground
            }
        }
    }

    var style: Style {
        didSet { applyAppearance() }
    }
    var cornerRadius: CGFloat {
        didSet { layer?.cornerRadius = cornerRadius }
    }
    var borderWidth: CGFloat {
        didSet { layer?.borderWidth = borderWidth }
    }

    init(style: Style, cornerRadius: CGFloat = 0, borderWidth: CGFloat = 0) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = cornerRadius > 0
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        guard let layer else { return }
        layer.cornerRadius = cornerRadius
        layer.borderWidth = borderWidth
        layer.backgroundColor = AdaptiveChrome.resolvedCGColor(style.backgroundColor, for: effectiveAppearance)
        layer.borderColor = AdaptiveChrome.resolvedCGColor(AdaptiveChrome.border, for: effectiveAppearance)
    }
}

/// A one-pixel semantic separator for layer-composited HUD layouts
final class AdaptiveSeparatorView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    private func applyAppearance() {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(
            AdaptiveChrome.separator,
            for: effectiveAppearance
        )
    }
}
