import AppKit
import AVFoundation
import AVKit
import Carbon
import ImageIO

private enum HistoryPanelLayout {
    static let headerTopInset: CGFloat = 12
    static let headerHeight: CGFloat = 36
    static let headerButtonSize: CGFloat = 32
    static let verticalGap: CGFloat = 12
    static let filterFadeWidth: CGFloat = 20
}

enum HistoryPanelDismissalPolicy {
    static func shouldDismissAutomatically(isLocked: Bool) -> Bool {
        !isLocked
    }
}

final class HistoryPanelController {
    private let onEditEntry: (HistoryEntry) -> Void
    private var dialogPanel: NSPanel?
    private var dialogOutsideMonitors: [Any] = []
    private var isDialogLocked = false
    private var notchController: HistoryNotchWindowController?

    init(onEditEntry: @escaping (HistoryEntry) -> Void) {
        self.onEditEntry = onEditEntry
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayModesChanged),
            name: .historyPanelDisplayModesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyCacheEnabledChanged),
            name: .historyCacheEnabledDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        syncNotchAvailability()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        closeDialog()
        notchController?.close()
    }

    func toggleFromUserRequest(holdOpenUntilMouseEnters: Bool = false) {
        guard Defaults.isHistoryCacheAvailable else { return }
        if Defaults.historyPanelDialogEnabled {
            toggleDialog()
            return
        }
        if Defaults.historyPanelNotchEnabled {
            ensureNotchController().toggleFromUserRequest(holdOpenUntilMouseEnters: holdOpenUntilMouseEnters)
        }
    }

    @objc private func displayModesChanged() {
        syncNotchAvailability()
        if !Defaults.historyPanelDialogEnabled {
            closeDialog()
        }
    }

    @objc private func historyCacheEnabledChanged() {
        if !Defaults.isHistoryCacheAvailable {
            closeDialog()
        }
        syncNotchAvailability()
    }

    @objc private func screenParametersChanged() {
        syncNotchAvailability()
    }

    private func syncNotchAvailability() {
        guard Defaults.isHistoryCacheAvailable, Defaults.historyPanelNotchEnabled else {
            notchController?.close()
            notchController = nil
            return
        }
        _ = ensureNotchController()
    }

    private func ensureNotchController() -> HistoryNotchWindowController {
        if let notchController {
            return notchController
        }
        let controller = HistoryNotchWindowController(onEditEntry: onEditEntry)
        notchController = controller
        return controller
    }

    private func toggleDialog() {
        if dialogPanel?.isVisible == true {
            closeDialog()
        } else {
            showDialog()
        }
    }

    private func showDialog() {
        closeDialog()

        let screen = NSScreen.screenForMouseLocation() ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width = min(max(420, visible.width * 0.70), visible.width - 28)
        let height = HistoryPanelPresentation.dialog.panelHeight
        let frame = NSRect(
            x: visible.midX - width / 2,
            y: visible.maxY - height - 12,
            width: width,
            height: height
        )

        let panel = HistoryFloatingPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true

        let chrome = AdaptiveChromeSurfaceView(style: .panel, cornerRadius: 24)
        chrome.frame = NSRect(origin: .zero, size: frame.size)
        chrome.autoresizingMask = [.width, .height]

        let content = HistoryPanelContentView(
            presentation: .dialog,
            onRequestDismiss: { [weak self] in self?.requestCloseDialog() },
            onLockStateChanged: { [weak self] isLocked in
                self?.isDialogLocked = isLocked
            },
            onEditEntry: onEditEntry
        )
        content.frame = chrome.bounds
        content.autoresizingMask = [.width, .height]
        chrome.addSubview(content)
        content.setActive(true)

        panel.contentView = chrome
        panel.orderFrontRegardless()
        panel.makeKey()
        dialogPanel = panel
        startDialogOutsideMonitoring(for: panel)
    }

    private func closeDialog() {
        stopDialogOutsideMonitoring()
        dialogPanel?.orderOut(nil)
        dialogPanel = nil
        isDialogLocked = false
    }

    private func requestCloseDialog() {
        guard HistoryPanelDismissalPolicy.shouldDismissAutomatically(isLocked: isDialogLocked) else { return }
        closeDialog()
    }

    private func startDialogOutsideMonitoring(for panel: NSPanel) {
        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] event in
            guard let self, let panel else { return event }
            if !self.event(event, isInside: panel) {
                self.requestCloseDialog()
            }
            return event
        }
        if let local {
            dialogOutsideMonitors.append(local)
        }

        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] event in
            DispatchQueue.main.async {
                guard let self, let panel else { return }
                if !self.event(event, isInside: panel) {
                    self.requestCloseDialog()
                }
            }
        }
        if let global {
            dialogOutsideMonitors.append(global)
        }
    }

    private func stopDialogOutsideMonitoring() {
        for monitor in dialogOutsideMonitors {
            NSEvent.removeMonitor(monitor)
        }
        dialogOutsideMonitors.removeAll()
    }

    private func event(_ event: NSEvent, isInside panel: NSPanel) -> Bool {
        let point: NSPoint
        if let eventWindow = event.window {
            point = eventWindow.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        } else {
            point = NSEvent.mouseLocation
        }
        return panel.frame.contains(point)
    }
}

private final class HistoryFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class HistoryNotchWindowController: NSWindowController {
    private let rootView: HistoryNotchRootView
    private var hoverSampler: DispatchSourceTimer?
    private var clickMonitors: [Any] = []
    private var expandWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var isCollapsing = false
    private var suppressCollapseUntil: Date?
    private var holdsOpenUntilMouseEntersHoverRegion = false
    private var commandOpenedMouseHasEnteredHoverRegion = false
    private var isLocked = false

    private let expandDelay: TimeInterval = 0.03
    private let collapseDelay: TimeInterval = 0.35
    private let collapseAnimationDuration: TimeInterval = 0.36
    private let sampleInterval: TimeInterval = 0.035
    private let postExpandGrace: TimeInterval = 0.5

    init(onEditEntry: @escaping (HistoryEntry) -> Void) {
        rootView = HistoryNotchRootView(onEditEntry: onEditEntry)
        let screen = Self.anchorScreen()
        rootView.updateGeometry(for: screen)
        let frame = Self.frame(for: screen, expandedSize: rootView.expandedSize)
        let panel = HistoryFloatingPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = true

        rootView.frame = NSRect(origin: .zero, size: frame.size)
        rootView.autoresizingMask = [.width, .height]
        panel.contentView = rootView

        super.init(window: panel)
        rootView.onRequestDismiss = { [weak self] in
            self?.requestCollapse()
        }
        rootView.onLockStateChanged = { [weak self] isLocked in
            self?.lockStateDidChange(isLocked)
        }
        panel.orderFrontRegardless()
        startMouseMonitoring()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        close()
    }

    override func close() {
        NotificationCenter.default.removeObserver(self)
        stopMouseMonitoring()
        super.close()
    }

    func toggleFromUserRequest(holdOpenUntilMouseEnters: Bool = false) {
        if rootView.isExpanded {
            rootView.setLocked(false)
            collapse()
        } else {
            expand(holdOpenUntilMouseEnters: holdOpenUntilMouseEnters)
        }
    }

    private func expand(holdOpenUntilMouseEnters: Bool = false) {
        guard !rootView.isExpanded else { return }
        isCollapsing = false
        cancelCollapse()
        holdsOpenUntilMouseEntersHoverRegion = holdOpenUntilMouseEnters
        commandOpenedMouseHasEnteredHoverRegion = false
        window?.ignoresMouseEvents = false
        window?.orderFrontRegardless()
        window?.makeKey()
        rootView.setExpanded(true, animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    private func collapse() {
        guard rootView.isExpanded else { return }
        cancelExpand()
        holdsOpenUntilMouseEntersHoverRegion = false
        commandOpenedMouseHasEnteredHoverRegion = false
        let animated = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        rootView.setExpanded(false, animated: animated)
        guard animated else {
            isCollapsing = false
            window?.ignoresMouseEvents = true
            return
        }
        isCollapsing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseAnimationDuration) { [weak self] in
            guard let self, self.isCollapsing else { return }
            self.isCollapsing = false
            self.window?.ignoresMouseEvents = true
        }
    }

    private func requestCollapse() {
        guard HistoryPanelDismissalPolicy.shouldDismissAutomatically(isLocked: isLocked) else { return }
        collapse()
    }

    private func lockStateDidChange(_ isLocked: Bool) {
        self.isLocked = isLocked
        if isLocked {
            cancelCollapse()
        } else {
            handleMouseMove()
        }
    }

    private func startMouseMonitoring() {
        startHoverSampler()
        if let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
            self?.handleNotchClick()
            return event
        }) {
            clickMonitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            self?.handleNotchClick()
        }) {
            clickMonitors.append(global)
        }
    }

    private func handleNotchClick() {
        guard Defaults.historyNotchTriggerMode == .click,
              !rootView.isExpanded,
              collapsedHitRect().contains(NSEvent.mouseLocation) else { return }
        // Finish dispatching the opening click before making the panel interactive
        // so it cannot also activate an item in the newly expanded panel
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window?.isVisible == true,
                  Defaults.historyNotchTriggerMode == .click,
                  !self.rootView.isExpanded else { return }
            self.cancelExpand()
            self.expand()
            self.suppressCollapseUntil = Date().addingTimeInterval(self.postExpandGrace)
        }
    }

    private func stopMouseMonitoring() {
        clickMonitors.forEach(NSEvent.removeMonitor)
        clickMonitors.removeAll()
        stopHoverSampler()
        cancelExpand()
        cancelCollapse()
    }

    private func startHoverSampler() {
        guard hoverSampler == nil else { return }
        let sampler = DispatchSource.makeTimerSource(queue: .main)
        sampler.schedule(deadline: .now(), repeating: sampleInterval, leeway: .milliseconds(8))
        sampler.setEventHandler { [weak self] in
            self?.handleMouseMove()
        }
        hoverSampler = sampler
        sampler.resume()
    }

    private func stopHoverSampler() {
        hoverSampler?.setEventHandler {}
        hoverSampler?.cancel()
        hoverSampler = nil
    }

    private func handleMouseMove() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if rootView.isExpanded {
            if isLocked {
                cancelCollapse()
                rootView.syncHoverStateWithCurrentMouse()
                return
            }
            let rect = expandedHoverRect(in: window)
            if rect.contains(mouse) {
                commandOpenedMouseHasEnteredHoverRegion = true
                cancelCollapse()
                rootView.syncHoverStateWithCurrentMouse()
            } else {
                if holdsOpenUntilMouseEntersHoverRegion, !commandOpenedMouseHasEnteredHoverRegion {
                    cancelCollapse()
                    return
                }
                scheduleCollapse()
            }
        } else {
            guard Defaults.historyNotchTriggerMode == .hover else {
                cancelExpand()
                return
            }
            let rect = collapsedHitRect()
            if rect.contains(mouse) {
                cancelCollapse()
                if isCollapsing {
                    expand()
                } else {
                    scheduleExpand()
                }
            } else {
                cancelExpand()
            }
        }
    }

    private func expandedHoverRect(in window: NSWindow) -> NSRect {
        let visibleHeight = rootView.visibleHeight > 0 ? rootView.visibleHeight : window.frame.height
        let visibleRect = NSRect(
            x: window.frame.minX,
            y: window.frame.maxY - visibleHeight,
            width: window.frame.width,
            height: visibleHeight
        )
        return visibleRect.insetBy(dx: -30, dy: -15)
    }

    private func scheduleExpand() {
        guard expandWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.expandWorkItem = nil
            guard Defaults.historyNotchTriggerMode == .hover else { return }
            self.expand()
            self.suppressCollapseUntil = Date().addingTimeInterval(self.postExpandGrace)
        }
        expandWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + expandDelay, execute: workItem)
    }

    private func scheduleCollapse() {
        if let until = suppressCollapseUntil, Date() < until { return }
        guard collapseWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.collapseWorkItem = nil
            self?.requestCollapse()
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDelay, execute: workItem)
    }

    private func collapsedHitRect() -> NSRect {
        let screen = Self.anchorScreen() ?? window?.screen
        let screenFrame = screen?.frame ?? .zero
        let notchAreaHeight = screen?.safeAreaInsets.top ?? 0
        let height = (notchAreaHeight > 0 ? notchAreaHeight : 24) + 6
        let size = rootView.collapsedSize
        let rect = NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - height,
            width: size.width,
            height: height
        )
        return rect.insetBy(dx: -14, dy: -8)
    }

    private func cancelExpand() {
        expandWorkItem?.cancel()
        expandWorkItem = nil
    }

    private func cancelCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    @objc private func screenDidChange() {
        let screen = Self.anchorScreen()
        rootView.updateGeometry(for: screen)
        window?.setFrame(Self.frame(for: screen, expandedSize: rootView.expandedSize), display: true)
    }

    private static func frame(for screen: NSScreen?, expandedSize: NSSize) -> NSRect {
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSRect(
            x: screenFrame.midX - expandedSize.width / 2,
            y: screenFrame.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )
    }

    private static func anchorScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.screenForMouseLocation()
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

struct HistoryNotchGeometry {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var screenWidth: CGFloat
    var notchLeadingX: CGFloat

    let expandedHorizontalMargin: CGFloat = 24
    let expandedBottomInset: CGFloat = 0

    static func geometry(for screen: NSScreen?) -> HistoryNotchGeometry {
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let safeTop = screen?.safeAreaInsets.top ?? 0
        var notchWidth: CGFloat = 200
        var notchLeadingX = (screenFrame.width - notchWidth) / 2

        if let screen, safeTop > 0 {
            let leftWidth = screen.auxiliaryTopLeftArea?.width ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            if leftWidth > 0, rightWidth > 0 {
                notchWidth = max(120, screenFrame.width - leftWidth - rightWidth)
                notchLeadingX = leftWidth
            }
        }

        return HistoryNotchGeometry(
            notchWidth: notchWidth,
            notchHeight: safeTop > 0 ? safeTop : 24,
            screenWidth: screenFrame.width,
            notchLeadingX: notchLeadingX
        )
    }

    var collapsedSize: NSSize {
        NSSize(width: notchWidth, height: notchHeight)
    }

    var contentHeight: CGFloat {
        HistoryPanelPresentation.notch.panelHeight
    }

    var expandedWidth: CGFloat {
        min(max(screenWidth * 0.74, 860), max(320, screenWidth - expandedHorizontalMargin))
    }

    var expandedSize: NSSize {
        NSSize(width: expandedWidth, height: contentHeight + expandedBottomInset)
    }

    func filterViewportWidth(headerInset: CGFloat) -> CGFloat {
        let expandedLeadingX = (screenWidth - expandedWidth) / 2
        let notchLeadingInExpandedPanel = notchLeadingX - expandedLeadingX
        return max(1, floor(notchLeadingInExpandedPanel - headerInset))
    }
}

enum HistoryPanelFilterRevealAnchor: Equatable {
    case leading
    case trailing
    case nearest
}

enum HistoryPanelFilterRevealPolicy {
    static func anchor(selectedIndex: Int, filterCount: Int) -> HistoryPanelFilterRevealAnchor {
        guard filterCount >= 4, selectedIndex >= 0, selectedIndex < filterCount else {
            return .nearest
        }
        if selectedIndex == 1 {
            return .leading
        }
        if selectedIndex == filterCount - 2 {
            return .trailing
        }
        return .nearest
    }
}

private final class HistoryNotchRootView: NSView {
    private var geometry = HistoryNotchGeometry.geometry(for: NSScreen.main)

    var collapsedSize: NSSize { geometry.collapsedSize }
    var expandedSize: NSSize { geometry.expandedSize }
    var visibleHeight: CGFloat { currentSize.height }

    private let shellView = HistoryNotchShellView()
    private let contentView: HistoryPanelContentView
    private let collapsedLabel = NSTextField(labelWithString: "")
    private let countQueue = DispatchQueue(label: "capcap.historyNotchCount", qos: .utility)

    private(set) var isExpanded = false
    private var currentSize = HistoryNotchGeometry.geometry(for: NSScreen.main).collapsedSize
    private var countGeneration = 0

    var onRequestDismiss: (() -> Void)? {
        didSet {
            contentView.onRequestDismiss = onRequestDismiss
        }
    }

    var onLockStateChanged: ((Bool) -> Void)? {
        didSet {
            contentView.onLockStateChanged = onLockStateChanged
        }
    }

    init(onEditEntry: @escaping (HistoryEntry) -> Void) {
        contentView = HistoryPanelContentView(presentation: .notch, onEditEntry: onEditEntry)
        super.init(frame: .zero)
        commonInit()
    }

    override init(frame frameRect: NSRect) {
        contentView = HistoryPanelContentView(presentation: .notch, onEditEntry: { _ in })
        super.init(frame: frameRect)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        // This surface follows the black hardware notch and its continuous silhouette.
        shellView.appearance = NSAppearance(named: .darkAqua)
        shellView.frame = bounds
        shellView.autoresizingMask = [.width, .height]
        addSubview(shellView)

        contentView.alphaValue = 0
        contentView.isHidden = true
        shellView.addSubview(contentView)
        contentView.updateNotchGeometry(geometry)

        collapsedLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        collapsedLabel.textColor = NSColor.white.withAlphaComponent(0.90)
        collapsedLabel.alignment = .center
        collapsedLabel.isSelectable = false
        shellView.addSubview(collapsedLabel)

        refreshCollapsedLabel()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCollapsedLabel),
            name: .historyDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshCollapsedLabel),
            name: .languageDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var isFlipped: Bool { false }

    override func layout() {
        super.layout()
        layoutShell(animated: false)
    }

    func updateGeometry(for screen: NSScreen?) {
        geometry = HistoryNotchGeometry.geometry(for: screen)
        contentView.updateNotchGeometry(geometry)
        currentSize = isExpanded ? expandedSize : collapsedSize
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard isExpanded != expanded else { return }
        isExpanded = expanded
        currentSize = expanded ? expandedSize : collapsedSize

        if expanded {
            contentView.setActive(true)
            contentView.isHidden = false
        } else {
            contentView.setActive(false)
            contentView.resetTransientState(animated: animated)
        }

        let changes = {
            self.contentView.alphaValue = expanded ? 1 : 0
            self.collapsedLabel.alphaValue = expanded ? 0 : 1
        }

        layoutShell(animated: animated)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = expanded ? 0.35 : 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                changes()
            } completionHandler: {
                guard self.isExpanded == expanded else { return }
                self.contentView.isHidden = !expanded
                if expanded {
                    self.syncHoverStateWithCurrentMouse()
                }
            }
        } else {
            changes()
            contentView.isHidden = !expanded
        }

        if expanded {
            layoutSubtreeIfNeeded()
            syncHoverStateWithCurrentMouse()
            DispatchQueue.main.async { [weak self] in
                self?.syncHoverStateWithCurrentMouse()
            }
        }
    }

    func syncHoverStateWithCurrentMouse() {
        guard isExpanded else { return }
        contentView.syncHoverStateWithCurrentMouse()
    }

    func setLocked(_ isLocked: Bool) {
        contentView.setLocked(isLocked)
    }

    private func layoutShell(animated: Bool) {
        shellView.frame = bounds

        let currentRect = shapeRect(for: currentSize)
        let expandedRect = shapeRect(for: expandedSize)
        let collapsedRect = shapeRect(for: collapsedSize)

        shellView.setShape(rect: currentRect, expanded: isExpanded, animated: animated)
        contentView.frame = NSRect(
            x: expandedRect.minX,
            y: expandedRect.maxY - geometry.contentHeight,
            width: expandedRect.width,
            height: geometry.contentHeight
        )
        collapsedLabel.frame = NSRect(
            x: collapsedRect.minX + 16,
            y: collapsedRect.midY - 9,
            width: collapsedRect.width - 32,
            height: 18
        )
    }

    private func shapeRect(for size: NSSize) -> NSRect {
        NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    @objc private func refreshCollapsedLabel() {
        countGeneration += 1
        let generation = countGeneration
        let title = L10n.historyMenu
        collapsedLabel.stringValue = title
        countQueue.async { [weak self] in
            let count = HistoryManager.shared.entryCount()
            DispatchQueue.main.async {
                guard let self, self.countGeneration == generation else { return }
                self.collapsedLabel.stringValue = "\(title) \(count)"
            }
        }
    }
}

private final class HistoryNotchShellView: NSView {
    private let fillLayer = CAShapeLayer()
    private let maskLayer = CAShapeLayer()
    private var shapeRect: NSRect = .zero
    private var isExpanded = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        fillLayer.fillColor = NSColor.black.cgColor
        layer?.addSublayer(fillLayer)
        maskLayer.fillColor = NSColor.black.cgColor
        layer?.mask = maskLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateMask(animated: false)
    }

    func setShape(rect: NSRect, expanded: Bool, animated: Bool) {
        let previousPath = maskLayer.presentation()?.path ?? maskLayer.path
        shapeRect = rect
        isExpanded = expanded
        updateMask(animated: animated, from: previousPath)
    }

    private func updateMask(animated: Bool, from previousPath: CGPath? = nil) {
        guard shapeRect.width > 0, shapeRect.height > 0 else { return }

        let path = Self.islandPath(
            in: shapeRect,
            flareRadius: isExpanded ? 14 : 4,
            bottomCornerRadius: isExpanded ? 20 : 10
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fillLayer.frame = bounds
        fillLayer.path = path
        maskLayer.frame = bounds
        maskLayer.path = path
        CATransaction.commit()

        guard animated, let previousPath else { return }

        let animation = Self.springAnimation(
            keyPath: "path",
            from: previousPath,
            to: path,
            expanded: isExpanded
        )
        fillLayer.add(animation, forKey: "historyNotchFill")
        maskLayer.add(animation, forKey: "historyNotchShape")
    }

    private static func islandPath(
        in rect: NSRect,
        flareRadius: CGFloat,
        bottomCornerRadius: CGFloat
    ) -> CGPath {
        let flare = max(0, min(flareRadius, rect.width * 0.25, rect.height))
        let bodyLeft = rect.minX + flare
        let bodyRight = rect.maxX - flare
        let bottom = max(0, min(bottomCornerRadius, (bodyRight - bodyLeft) * 0.5, rect.height))
        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: bodyRight, y: rect.maxY - flare),
            control1: CGPoint(x: rect.maxX - flare * 0.5, y: rect.maxY),
            control2: CGPoint(x: bodyRight, y: rect.maxY - flare * 0.5)
        )
        path.addLine(to: CGPoint(x: bodyRight, y: rect.minY + bottom))
        path.addQuadCurve(
            to: CGPoint(x: bodyRight - bottom, y: rect.minY),
            control: CGPoint(x: bodyRight, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: bodyLeft + bottom, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: bodyLeft, y: rect.minY + bottom),
            control: CGPoint(x: bodyLeft, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: bodyLeft, y: rect.maxY - flare))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control1: CGPoint(x: bodyLeft, y: rect.maxY - flare * 0.5),
            control2: CGPoint(x: rect.minX + flare * 0.5, y: rect.maxY)
        )
        path.closeSubpath()

        return path
    }

    private static func springAnimation(
        keyPath: String,
        from: CGPath,
        to: CGPath,
        expanded: Bool
    ) -> CASpringAnimation {
        let response: CGFloat = expanded ? 0.35 : 0.3
        let dampingFraction: CGFloat = expanded ? 0.86 : 0.9
        let omega = 2 * CGFloat.pi / response
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.mass = 1
        animation.stiffness = Double(omega * omega)
        animation.damping = Double(2 * dampingFraction * omega)
        animation.initialVelocity = 0
        animation.duration = min(max(animation.settlingDuration, Double(response)), 0.7)
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }
}

private enum HistoryPanelPresentation {
    case dialog
    case notch

    var tileWidth: CGFloat {
        switch self {
        case .dialog: return 180
        case .notch: return 150
        }
    }

    var tileHeight: CGFloat {
        switch self {
        case .dialog: return 146
        case .notch: return 134
        }
    }

    var previewHeight: CGFloat {
        switch self {
        case .dialog: return 98
        case .notch: return 88
        }
    }

    var previewPixelSize: Int {
        Int(max(tileWidth, previewHeight) * (NSScreen.main?.backingScaleFactor ?? 2))
    }

    var outerInset: CGFloat {
        switch self {
        case .dialog: return 18
        case .notch: return 16
        }
    }

    var stripSideInset: CGFloat {
        switch self {
        case .dialog: return 0
        case .notch: return 12
        }
    }

    var contentBottomInset: CGFloat {
        outerInset
    }

    var headerInset: CGFloat {
        switch self {
        case .dialog: return outerInset
        case .notch: return 30
        }
    }

    var panelHeight: CGFloat {
        HistoryPanelLayout.headerTopInset
            + HistoryPanelLayout.headerHeight
            + HistoryPanelLayout.verticalGap
            + tileHeight
            + contentBottomInset
    }
}

enum HistoryFavoritePolicy {
    static let minimumFavoriteCountForFilter = 1

    static func shouldShowFilter(for entries: [HistoryEntry]) -> Bool {
        entries.lazy
            .filter { HistoryManager.isFavorite(url: $0.fileURL) }
            .prefix(minimumFavoriteCountForFilter)
            .count >= minimumFavoriteCountForFilter
    }

    static func toggleTargets(clicked: HistoryEntry, selected: [HistoryEntry]) -> [HistoryEntry] {
        selected.count > 1 ? selected : [clicked]
    }

    static func nextFavoriteState(for entries: [HistoryEntry]) -> Bool {
        entries.contains { !HistoryManager.isFavorite(url: $0.fileURL) }
    }
}

enum HistoryPanelFilter: CaseIterable, Equatable {
    case all
    case favorites
    case screenshots
    case gif
    case mp4

    var title: String {
        switch self {
        case .all: return L10n.historyPanelFilterAll
        case .favorites: return L10n.historyPanelFilterFavorites
        case .screenshots: return L10n.historyPanelFilterScreenshots
        case .gif: return L10n.historyPanelFilterGIF
        case .mp4: return L10n.historyPanelFilterMP4
        }
    }
}

final class HistoryPanelScrollView: NSScrollView {
    // NSCollectionView enables the horizontal scroller when its flow layout is
    // attached. Hiding that scroller still reserves 17 points in legacy mode,
    // making the clip view shorter than the cards. Keep it disabled at the
    // property boundary so both scroller styles preserve the full viewport.
    override var hasHorizontalScroller: Bool {
        get { super.hasHorizontalScroller }
        set { super.hasHorizontalScroller = false }
    }
}

private final class HistoryPanelFilterDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class HistoryPanelFilterControl: NSSegmentedControl {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isEnabled }
}

private final class HistoryPanelFilterScrollView: NSScrollView {
    private static let controlInset: CGFloat = 4

    let control: NSSegmentedControl = HistoryPanelFilterControl()
    private let documentContainer = HistoryPanelFilterDocumentView()
    private let fadeMaskLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        drawsBackground = false
        borderType = .noBorder
        hasHorizontalScroller = false
        hasVerticalScroller = false
        horizontalScroller = nil
        verticalScroller = nil
        autohidesScrollers = false
        horizontalScrollElasticity = .allowed
        verticalScrollElasticity = .none
        usesPredominantAxisScrolling = false
        contentView.postsBoundsChangedNotifications = true
        documentView = documentContainer

        control.controlSize = .regular
        control.segmentStyle = .rounded
        control.segmentDistribution = .fit
        control.trackingMode = .selectOne
        if #available(macOS 26.0, *) {
            control.borderShape = .capsule
        }
        documentContainer.addSubview(control)

        wantsLayer = true
        fadeMaskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        fadeMaskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.mask = fadeMaskLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: control.intrinsicContentSize.width + 2 * Self.controlInset,
            height: HistoryPanelLayout.headerHeight
        )
    }

    override func layout() {
        super.layout()
        layoutDocument()
    }

    override func reflectScrolledClipView(_ cView: NSClipView) {
        super.reflectScrolledClipView(cView)
        updateFadeMask()
    }

    func setFilters(_ filters: [HistoryPanelFilter]) {
        control.segmentCount = filters.count
        let font = control.font ?? .systemFont(ofSize: NSFont.systemFontSize(for: control.controlSize))
        for (index, filter) in filters.enumerated() {
            let title = filter.title
            let titleWidth = ceil(title.size(withAttributes: [.font: font]).width)
            control.setLabel(title, forSegment: index)
            control.setWidth(max(44, titleWidth + 22), forSegment: index)
        }
        control.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func revealSelection() {
        let index = control.selectedSegment
        let count = control.segmentCount
        guard (0..<count).contains(index) else { return }
        layoutSubtreeIfNeeded()
        let visibleBounds = contentView.bounds
        guard visibleBounds.width > 0, documentContainer.bounds.width > visibleBounds.width else { return }
        switch HistoryPanelFilterRevealPolicy.anchor(selectedIndex: index, filterCount: count) {
        case .leading:
            scroll(toX: 0)
        case .trailing:
            scroll(toX: .greatestFiniteMagnitude)
        case .nearest:
            revealSegment(at: index, in: visibleBounds)
        }
    }

    private func revealSegment(at index: Int, in visibleBounds: NSRect) {
        let widths = (0..<control.segmentCount).map { control.width(forSegment: $0) }
        let totalWidth = widths.reduce(0, +)
        guard totalWidth > 0 else { return }
        let scale = control.frame.width / totalWidth
        let minX = control.frame.minX + widths.prefix(index).reduce(0, +) * scale
        let width = widths[index] * scale
        let maxX = minX + width
        let inset = min(HistoryPanelLayout.filterFadeWidth, max(0, (visibleBounds.width - width) / 2))
        if minX < visibleBounds.minX + inset {
            scroll(toX: minX - inset)
        } else if maxX > visibleBounds.maxX - inset {
            scroll(toX: maxX - visibleBounds.width + inset)
        }
    }

    private func layoutDocument() {
        let controlSize = control.intrinsicContentSize
        let viewportSize = contentView.bounds.size
        let documentWidth = max(viewportSize.width, controlSize.width + 2 * Self.controlInset)
        documentContainer.frame = NSRect(
            x: 0,
            y: 0,
            width: documentWidth,
            height: viewportSize.height
        )
        control.frame = NSRect(
            x: Self.controlInset,
            y: max(0, (viewportSize.height - controlSize.height) / 2),
            width: controlSize.width,
            height: controlSize.height
        )

        scroll(toX: contentView.bounds.origin.x)
        updateFadeMask()
    }

    private func scroll(toX proposedX: CGFloat) {
        let maximumX = max(0, documentContainer.bounds.width - contentView.bounds.width)
        let clampedX = min(max(0, proposedX), maximumX)
        guard abs(contentView.bounds.origin.x - clampedX) > 0.5 else {
            updateFadeMask()
            return
        }
        contentView.scroll(to: NSPoint(x: clampedX, y: 0))
        super.reflectScrolledClipView(contentView)
        updateFadeMask()
    }

    private func updateFadeMask() {
        let width = bounds.width
        guard width > 0 else { return }

        let maximumX = max(0, documentContainer.bounds.width - contentView.bounds.width)
        let originX = contentView.bounds.origin.x
        let hasContentBefore = originX > 0.5
        let hasContentAfter = originX < maximumX - 0.5
        let opaque = NSColor.black.cgColor
        let transparent = NSColor.clear.cgColor
        let fadeFraction = min(0.45, HistoryPanelLayout.filterFadeWidth / width)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        switch (hasContentBefore, hasContentAfter) {
        case (true, true):
            fadeMaskLayer.colors = [transparent, opaque, opaque, transparent]
            fadeMaskLayer.locations = [0, NSNumber(value: fadeFraction), NSNumber(value: 1 - fadeFraction), 1]
        case (true, false):
            fadeMaskLayer.colors = [transparent, opaque, opaque]
            fadeMaskLayer.locations = [0, NSNumber(value: fadeFraction), 1]
        case (false, true):
            fadeMaskLayer.colors = [opaque, opaque, transparent]
            fadeMaskLayer.locations = [0, NSNumber(value: 1 - fadeFraction), 1]
        case (false, false):
            fadeMaskLayer.colors = [opaque, opaque]
            fadeMaskLayer.locations = [0, 1]
        }

        fadeMaskLayer.frame = bounds
        fadeMaskLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        CATransaction.commit()
    }
}

private final class HistoryPanelContentView: NSView, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private static let pageSize = 30
    private static let initialPreviewCount = 18
    private static let previewPrefetchCount = 9

    private enum PreviewPrefetchDirection {
        case forward
        case backward
    }

    private let presentation: HistoryPanelPresentation
    private let onEditEntry: (HistoryEntry) -> Void
    var onRequestDismiss: (() -> Void)?
    var onLockStateChanged: ((Bool) -> Void)?

    private var selectedFilter: HistoryPanelFilter = .all
    private let filterScrollView = HistoryPanelFilterScrollView()
    private let entriesQueue = DispatchQueue(label: "capcap.historyPanelEntries", qos: .userInitiated)
    private let scrollView = HistoryPanelScrollView()
    private let collectionView = NSCollectionView()
    private let collectionLayout = NSCollectionViewFlowLayout()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let deleteButton = HistoryPanelDeleteButton()
    private let infoButton = HistoryPanelActionButton(
        symbolName: "keyboard",
        accessibilityLabel: L10n.historyPanelShortcutGuide,
        isToggle: true
    )
    private let finderButton = HistoryPanelActionButton(symbolName: "folder", accessibilityLabel: L10n.historyShowInFinder)
    private let lockButton = HistoryPanelActionButton(
        symbolName: "lock",
        accessibilityLabel: L10n.historyPanelLock,
        isToggle: true
    )
    private let settingsButton = HistoryPanelActionButton(symbolName: "gearshape", accessibilityLabel: L10n.settings)
    private let shortcutGuideView: HistoryPanelShortcutGuideView
    private var deleteButtonWidthConstraint: NSLayoutConstraint?
    private var confirmationDismissMonitor: Any?
    private var selectionKeyMonitor: Any?
    private var previewController: HistoryPreviewWindowController?
    private weak var activeHoverTile: HistoryPanelTileView?
    private var keyboardEntryID: String?
    private var keyboardMouseOrigin: NSPoint?
    private var allEntries: [HistoryEntry] = []
    private var visibleEntries: [HistoryEntry] = []
    private var availableFilters: [HistoryPanelFilter] = [.all]
    private var renderedEntryCount = 0
    private var isAppendingPage = false
    private var selectedEntryIDs: [String] = []
    private var lastSelectionAnchorID: String?
    private var reloadGeneration = 0
    private var isActive = false
    private var isReloading = false
    private var hasLoadedEntries = false
    private var needsEntriesReload = true
    private var isConfirmingDelete = false
    private var previewWarmGeneration = 0
    private var previewPrefetchRequests: [String: HistoryImagePreviewRequest] = [:]
    private var previewPrefetchEntryIDs: Set<String> = []
    private var lastScrollOriginX: CGFloat = 0
    private var hoverSyncWorkItem: DispatchWorkItem?
    private var isScrollingContent = false
    private var isShowingShortcutGuide = false
    private var isLocked = false
    private var filterViewportWidthConstraint: NSLayoutConstraint?

    init(
        presentation: HistoryPanelPresentation,
        onRequestDismiss: (() -> Void)? = nil,
        onLockStateChanged: ((Bool) -> Void)? = nil,
        onEditEntry: @escaping (HistoryEntry) -> Void = { _ in }
    ) {
        self.presentation = presentation
        self.onRequestDismiss = onRequestDismiss
        self.onLockStateChanged = onLockStateChanged
        self.onEditEntry = onEditEntry
        shortcutGuideView = HistoryPanelShortcutGuideView(presentation: presentation)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupUI()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(historyDidUpdate),
            name: .historyDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshLocalization),
            name: .languageDidChange,
            object: nil
        )
        warmInitialPreviewWindow()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopConfirmationDismissMonitoring()
        stopSelectionKeyMonitoring()
        hoverSyncWorkItem?.cancel()
        previewPrefetchRequests.values.forEach { $0.cancel() }
        previewController?.close()
        HotkeyManager.shared.unregisterHistoryPreview()
    }

    override func layout() {
        super.layout()
        updateCollectionLayout()
    }

    func updateNotchGeometry(_ geometry: HistoryNotchGeometry) {
        guard presentation == .notch else { return }
        filterViewportWidthConstraint?.constant = geometry.filterViewportWidth(
            headerInset: presentation.headerInset
        )
        needsLayout = true
    }

    private func setupUI() {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)

        filterScrollView.control.target = self
        filterScrollView.control.action = #selector(filterClicked(_:))
        filterScrollView.translatesAutoresizingMaskIntoConstraints = false
        filterScrollView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        filterScrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        header.addSubview(filterScrollView)

        finderButton.target = self
        finderButton.action = #selector(showHistoryInFinderClicked)

        infoButton.target = self
        infoButton.action = #selector(toggleShortcutGuideClicked)

        lockButton.target = self
        lockButton.action = #selector(toggleLockClicked)

        settingsButton.target = self
        settingsButton.action = #selector(openSettingsClicked)

        deleteButton.target = self
        deleteButton.action = #selector(deleteHistoryClicked)

        let utilities = NSStackView(views: [finderButton, lockButton, infoButton, settingsButton])
        utilities.orientation = .horizontal
        utilities.alignment = .centerY
        utilities.spacing = 2
        utilities.setCustomSpacing(8, after: lockButton)
        utilities.translatesAutoresizingMaskIntoConstraints = false

        let utilitySurface = FloatingGlassView(
            cornerRadius: HistoryPanelLayout.headerHeight / 2,
            interactive: true,
            blendingMode: .withinWindow
        )
        utilitySurface.translatesAutoresizingMaskIntoConstraints = false
        utilitySurface.content.addSubview(utilities)

        let actions = NSStackView(views: [deleteButton, utilitySurface])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 10
        actions.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(actions)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.horizontalScroller = nil
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.contentView.postsBoundsChangedNotifications = true

        collectionLayout.scrollDirection = .horizontal
        collectionLayout.minimumLineSpacing = 14
        collectionLayout.minimumInteritemSpacing = 14
        collectionLayout.itemSize = NSSize(width: presentation.tileWidth, height: presentation.tileHeight)
        collectionLayout.sectionInset = NSEdgeInsets(
            top: 0,
            left: presentation.stripSideInset,
            bottom: 0,
            right: presentation.stripSideInset
        )
        collectionView.collectionViewLayout = collectionLayout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = false
        collectionView.backgroundColors = [.clear]
        collectionView.frame = NSRect(x: 0, y: 0, width: 1, height: presentation.tileHeight)
        collectionView.register(
            HistoryPanelCollectionItem.self,
            forItemWithIdentifier: HistoryPanelCollectionItem.identifier
        )
        scrollView.documentView = collectionView
        addSubview(scrollView)

        shortcutGuideView.translatesAutoresizingMaskIntoConstraints = false
        shortcutGuideView.isHidden = true
        addSubview(shortcutGuideView)

        emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyLabel)

        let inset = presentation.outerInset
        let headerInset = presentation.headerInset
        let deleteWidth = deleteButton.widthAnchor.constraint(equalToConstant: HistoryPanelLayout.headerButtonSize)
        deleteButtonWidthConstraint = deleteWidth
        let filterViewportWidth = filterScrollView.widthAnchor.constraint(lessThanOrEqualToConstant: 1)
        filterViewportWidth.isActive = presentation == .notch
        filterViewportWidthConstraint = filterViewportWidth
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: HistoryPanelLayout.headerTopInset),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: headerInset),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -headerInset),
            header.heightAnchor.constraint(equalToConstant: HistoryPanelLayout.headerHeight),

            filterScrollView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            filterScrollView.topAnchor.constraint(equalTo: header.topAnchor),
            filterScrollView.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            filterScrollView.trailingAnchor.constraint(
                lessThanOrEqualTo: actions.leadingAnchor,
                constant: -12
            ),

            deleteWidth,
            deleteButton.heightAnchor.constraint(equalToConstant: HistoryPanelLayout.headerButtonSize),

            actions.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            actions.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            utilitySurface.heightAnchor.constraint(equalToConstant: HistoryPanelLayout.headerHeight),
            utilities.leadingAnchor.constraint(equalTo: utilitySurface.leadingAnchor, constant: 4),
            utilities.trailingAnchor.constraint(equalTo: utilitySurface.trailingAnchor, constant: -4),
            utilities.centerYAnchor.constraint(equalTo: utilitySurface.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: HistoryPanelLayout.verticalGap),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -presentation.contentBottomInset),

            shortcutGuideView.topAnchor.constraint(equalTo: header.bottomAnchor),
            shortcutGuideView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            shortcutGuideView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            shortcutGuideView.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: scrollView.widthAnchor, constant: -40),
        ])

        updateLocalizedCopy()
        startConfirmationDismissMonitoring()
        startSelectionKeyMonitoring()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func refreshLocalization() {
        updateLocalizedCopy()
    }

    private func updateLocalizedCopy() {
        filterScrollView.control.setAccessibilityLabel(L10n.historyPanelMenu)
        filterScrollView.setFilters(availableFilters)
        updateFilterSelection()
        visibleCollectionTiles.forEach { $0.refreshFavoriteState() }
        updateDeleteButtonPresentation()
        infoButton.updateAccessibilityLabel(
            isShowingShortcutGuide ? L10n.historyPanelShortcutGuideHide : L10n.historyPanelShortcutGuide
        )
        shortcutGuideView.reload()
        finderButton.updateAccessibilityLabel(L10n.historyShowInFinder)
        updateLockButtonPresentation()
        settingsButton.updateAccessibilityLabel(L10n.settings)
        emptyLabel.stringValue = L10n.historyPanelEmpty
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        if active {
            if needsEntriesReload || !hasLoadedEntries {
                reloadEntries()
            } else {
                updatePreviewLoading(initial: true)
            }
        } else {
            clearKeyboardNavigation()
            if isReloading {
                needsEntriesReload = true
                isReloading = false
                reloadGeneration += 1
            }
            hoverSyncWorkItem?.cancel()
            hoverSyncWorkItem = nil
            isScrollingContent = false
            clearActiveHoverTile()
        }
    }

    func setLocked(_ isLocked: Bool) {
        guard self.isLocked != isLocked else { return }
        self.isLocked = isLocked
        updateLockButtonPresentation()
        onLockStateChanged?(isLocked)
    }

    @objc private func historyDidUpdate() {
        needsEntriesReload = true
        if isActive {
            reloadEntries()
        } else {
            warmInitialPreviewWindow()
        }
    }

    @objc private func filterClicked(_ sender: NSSegmentedControl) {
        guard availableFilters.indices.contains(sender.selectedSegment) else { return }
        selectFilter(availableFilters[sender.selectedSegment])
    }

    private func selectFilter(_ filter: HistoryPanelFilter) {
        clearKeyboardNavigation()
        setShortcutGuideVisible(false)
        selectedFilter = filter
        setDeleteConfirmation(false, animated: true)
        if hasLoadedEntries {
            applySelectedFilter(resetScrollPosition: true)
        } else {
            updateFilterSelection()
            reloadEntries()
        }
    }

    private func cycleFilter(forward: Bool) {
        let count = availableFilters.count
        guard count > 1, let index = availableFilters.firstIndex(of: selectedFilter) else { return }
        let offset = forward ? 1 : count - 1
        selectFilter(availableFilters[(index + offset) % count])
    }

    private func moveEntry(forward: Bool) {
        guard !visibleEntries.isEmpty else { return }
        let currentID = isKeyboardNavigationActive
            ? keyboardEntryID
            : activeHoverTile.map { entryID($0.entry) }
        let currentIndex = currentID.flatMap { id in
            visibleEntries.firstIndex { entryID($0) == id }
        }
        let nextIndex: Int
        if let currentIndex {
            nextIndex = min(max(currentIndex + (forward ? 1 : -1), 0), visibleEntries.count - 1)
        } else {
            nextIndex = visibleIndexRange()?.lowerBound ?? 0
        }

        setDeleteConfirmation(false, animated: true)
        hoverSyncWorkItem?.cancel()
        hoverSyncWorkItem = nil
        isScrollingContent = false
        keyboardEntryID = entryID(visibleEntries[nextIndex])
        keyboardMouseOrigin = NSEvent.mouseLocation
        if nextIndex >= renderedEntryCount {
            appendNextPage()
        }
        revealEntry(at: nextIndex)
        syncHoverStateWithCurrentMouse()
    }

    private func revealEntry(at index: Int) {
        layoutSubtreeIfNeeded()
        collectionView.layoutSubtreeIfNeeded()
        guard let attributes = collectionLayout.layoutAttributesForItem(
            at: IndexPath(item: index, section: 0)
        ) else { return }

        // Scroll the clip view directly: the collection's automatic scrolling
        // does not reliably reveal items with our disabled horizontal scroller.
        let visibleRect = scrollView.documentVisibleRect
        let padding = collectionLayout.minimumLineSpacing
        let itemFrame = attributes.frame
        var targetX = visibleRect.minX
        if itemFrame.minX < visibleRect.minX + padding {
            targetX = itemFrame.minX - padding
        } else if itemFrame.maxX > visibleRect.maxX - padding {
            targetX = itemFrame.maxX - visibleRect.width + padding
        }
        let maximumX = max(0, collectionView.bounds.width - visibleRect.width)
        let clampedX = min(max(0, targetX), maximumX)
        scrollView.contentView.scroll(to: NSPoint(
            x: clampedX,
            y: scrollView.contentView.bounds.origin.y
        ))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        collectionView.layoutSubtreeIfNeeded()
    }

    private func clearKeyboardNavigation() {
        keyboardEntryID = nil
        keyboardMouseOrigin = nil
    }

    private var isKeyboardNavigationActive: Bool {
        guard keyboardEntryID != nil, let origin = keyboardMouseOrigin else { return false }
        let current = NSEvent.mouseLocation
        guard hypot(current.x - origin.x, current.y - origin.y) < 0.5 else {
            clearKeyboardNavigation()
            return false
        }
        return true
    }

    private func updateFilterSelection() {
        guard let index = availableFilters.firstIndex(of: selectedFilter) else { return }
        filterScrollView.control.selectedSegment = index
        filterScrollView.revealSelection()
    }

    @objc private func deleteHistoryClicked() {
        guard deleteButton.isEnabled else { return }
        if isConfirmingDelete {
            let deletingSelection = hasSelection
            let entriesToDelete = selectedEntries()
            setDeleteConfirmation(false, animated: false)
            if deletingSelection {
                guard !entriesToDelete.isEmpty else {
                    clearSelection()
                    return
                }
                HistoryManager.shared.remove(entriesToDelete) { removedCount, skippedCount in
                    if skippedCount > 0 {
                        ToastWindow.show(message: L10n.historyDeletedSkippingFavorites(
                            removed: removedCount, skipped: skippedCount))
                    } else if removedCount > 0 {
                        ToastWindow.show(message: L10n.historyPanelDeletedSelected(removedCount))
                    }
                }
                clearSelection()
            } else {
                HistoryManager.shared.clearAll { removedCount, skippedCount in
                    if skippedCount > 0 {
                        ToastWindow.show(message: L10n.historyDeletedSkippingFavorites(
                            removed: removedCount, skipped: skippedCount))
                    } else {
                        ToastWindow.show(message: L10n.historyCleared)
                    }
                }
            }
            onRequestDismiss?()
        } else {
            setDeleteConfirmation(true, animated: true)
        }
    }

    @objc private func toggleShortcutGuideClicked() {
        setDeleteConfirmation(false, animated: true)
        setShortcutGuideVisible(!isShowingShortcutGuide)
    }

    @objc private func toggleLockClicked() {
        setDeleteConfirmation(false, animated: true)
        setLocked(!isLocked)
    }

    private func updateLockButtonPresentation() {
        lockButton.state = isLocked ? .on : .off
        lockButton.updateAccessibilityLabel(isLocked ? L10n.historyPanelUnlock : L10n.historyPanelLock)
        lockButton.updateSymbol(isLocked ? "lock.fill" : "lock")
    }

    private func setShortcutGuideVisible(_ visible: Bool) {
        guard isShowingShortcutGuide != visible else { return }
        isShowingShortcutGuide = visible
        if visible {
            clearKeyboardNavigation()
            clearActiveHoverTile()
            previewController?.close()
        }
        infoButton.state = visible ? .on : .off
        infoButton.updateAccessibilityLabel(
            visible ? L10n.historyPanelShortcutGuideHide : L10n.historyPanelShortcutGuide
        )
        updateContentVisibility()
    }

    @objc private func showHistoryInFinderClicked() {
        setDeleteConfirmation(false, animated: true)
        NSWorkspace.shared.open(HistoryManager.shared.cacheDirectoryURL())
        onRequestDismiss?()
    }

    @objc private func openSettingsClicked() {
        setDeleteConfirmation(false, animated: true)
        SettingsWindowController.shared.showAsSettings()
        onRequestDismiss?()
    }

    @objc private func reloadEntries() {
        guard isActive else {
            needsEntriesReload = true
            return
        }
        reloadGeneration += 1
        let generation = reloadGeneration
        needsEntriesReload = false
        isReloading = true
        entriesQueue.async { [weak self] in
            let allEntries = HistoryManager.shared.panelEntries()
            let availableFilters = Self.availableFilters(for: allEntries)
            DispatchQueue.main.async {
                guard let self, self.reloadGeneration == generation, self.isActive else { return }
                self.isReloading = false
                self.hasLoadedEntries = true
                self.allEntries = allEntries
                if self.availableFilters != availableFilters {
                    self.availableFilters = availableFilters
                    self.filterScrollView.setFilters(availableFilters)
                }
                self.applySelectedFilter(resetScrollPosition: false)
            }
        }
    }

    private func applySelectedFilter(resetScrollPosition: Bool) {
        let effectiveFilter = availableFilters.contains(selectedFilter) ? selectedFilter : .all
        selectedFilter = effectiveFilter
        updateFilterSelection()
        let entries = Self.filteredEntries(from: allEntries, filter: effectiveFilter)
        applyEntries(entries, hasAnyEntries: !allEntries.isEmpty)
        resetScrollPositionIfNeeded(resetScrollPosition)
    }

    private func resetScrollPositionIfNeeded(_ shouldReset: Bool) {
        guard shouldReset else { return }
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func applyEntries(_ entries: [HistoryEntry], hasAnyEntries: Bool) {
        previewWarmGeneration += 1
        clearKeyboardNavigation()
        clearActiveHoverTile()
        visibleEntries = entries
        pruneSelection(to: entries)
        renderedEntryCount = min(Self.pageSize, entries.count)
        isAppendingPage = false
        lastScrollOriginX = scrollView.contentView.bounds.origin.x
        collectionView.reloadData()
        collectionLayout.invalidateLayout()
        refreshTileSelectionStates()
        deleteButton.isEnabled = hasAnyEntries
        if !hasAnyEntries {
            setDeleteConfirmation(false, animated: true)
        }
        emptyLabel.stringValue = L10n.historyPanelEmpty
        updateContentVisibility()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadNextPageIfNeeded()
            self.syncHoverStateWithCurrentMouse()
            self.updatePreviewLoading(initial: true)
        }
    }

    private var hasSelection: Bool {
        !selectedEntryIDs.isEmpty
    }

    private func pruneSelection(to entries: [HistoryEntry]) {
        let previousSelection = selectedEntryIDs
        let visibleIDs = Set(entries.map(entryID))
        selectedEntryIDs = selectedEntryIDs.filter { visibleIDs.contains($0) }
        if let anchor = lastSelectionAnchorID, !visibleIDs.contains(anchor) {
            lastSelectionAnchorID = selectedEntryIDs.last
        }
        if selectedEntryIDs != previousSelection {
            setDeleteConfirmation(false, animated: true)
        }
    }

    private func handleSelectionToggle(for tile: HistoryPanelTileView, event: NSEvent) {
        window?.makeKey()
        setDeleteConfirmation(false, animated: true)
        if event.modifierFlags.contains(.shift), let anchor = lastSelectionAnchorID {
            selectRange(from: anchor, to: entryID(tile.entry))
        } else {
            toggleSelection(for: tile.entry)
            lastSelectionAnchorID = entryID(tile.entry)
        }
        refreshTileSelectionStates()
    }

    private func handlePrimaryClick(for tile: HistoryPanelTileView, event: NSEvent) {
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift) {
            handleSelectionToggle(for: tile, event: event)
            return
        }

        let tileID = entryID(tile.entry)
        if hasSelection, selectedEntryIDs.contains(tileID) {
            if case .image = tile.entry.kind,
               HistoryPanelEntryActions.copyImages(selectedImageEntries()) {
                onRequestDismiss?()
            } else if HistoryPanelEntryActions.copy(tile.entry) {
                onRequestDismiss?()
            }
            return
        }

        if HistoryPanelEntryActions.copy(tile.entry) {
            onRequestDismiss?()
        }
    }

    private func dragEntries(for tile: HistoryPanelTileView) -> [HistoryEntry] {
        let tileID = entryID(tile.entry)
        guard selectedEntryIDs.contains(tileID) else {
            return [tile.entry]
        }
        let selected = selectedEntries()
        return selected.isEmpty ? [tile.entry] : selected
    }

    private func handleFavoriteToggle(for tile: HistoryPanelTileView) {
        window?.makeKey()
        setDeleteConfirmation(false, animated: true)

        let targets = HistoryFavoritePolicy.toggleTargets(
            clicked: tile.entry,
            selected: selectedEntries()
        )
        let shouldFavorite = HistoryFavoritePolicy.nextFavoriteState(for: targets)
        var didChangeAnyEntry = false
        var didFail = false

        for entry in targets {
            let isFavorite = HistoryManager.isFavorite(url: entry.fileURL)
            guard isFavorite != shouldFavorite else { continue }
            if HistoryManager.setFavorite(shouldFavorite, on: entry.fileURL) {
                didChangeAnyEntry = true
            } else {
                didFail = true
            }
        }

        if didFail {
            ToastWindow.show(message: L10n.historyPanelFavoriteFailed)
        } else if didChangeAnyEntry {
            ToastWindow.show(message: shouldFavorite
                ? L10n.historyPanelItemFavorited
                : L10n.historyPanelItemUnfavorited)
        }

        availableFilters = Self.availableFilters(for: allEntries)
        applySelectedFilter(resetScrollPosition: false)
    }

    private func selectedImageEntries() -> [HistoryEntry] {
        selectedEntries().filter { entry in
            guard case .image = entry.kind else { return false }
            return true
        }
    }

    private func selectedEntries() -> [HistoryEntry] {
        let entriesByID = Dictionary(uniqueKeysWithValues: visibleEntries.map { (entryID($0), $0) })
        return selectedEntryIDs.compactMap { entriesByID[$0] }
    }

    private func toggleSelection(for entry: HistoryEntry) {
        let id = entryID(entry)
        if let index = selectedEntryIDs.firstIndex(of: id) {
            selectedEntryIDs.remove(at: index)
        } else {
            selectedEntryIDs.append(id)
        }
        if selectedEntryIDs.isEmpty {
            lastSelectionAnchorID = nil
        }
    }

    private func clearSelection() {
        guard hasSelection else { return }
        selectedEntryIDs.removeAll()
        lastSelectionAnchorID = nil
        refreshTileSelectionStates()
    }

    private func selectRange(from anchorID: String, to targetID: String) {
        guard let anchorIndex = visibleEntries.firstIndex(where: { entryID($0) == anchorID }),
              let targetIndex = visibleEntries.firstIndex(where: { entryID($0) == targetID }) else {
            if let target = visibleEntries.first(where: { entryID($0) == targetID }) {
                toggleSelection(for: target)
            }
            return
        }
        let range = anchorIndex <= targetIndex ? anchorIndex...targetIndex : targetIndex...anchorIndex
        for entry in visibleEntries[range] where isSelectable(entry) {
            let id = entryID(entry)
            if !selectedEntryIDs.contains(id) {
                selectedEntryIDs.append(id)
            }
        }
    }

    private func refreshTileSelectionStates() {
        for tile in visibleCollectionTiles {
            let id = entryID(tile.entry)
            let order = selectedEntryIDs.firstIndex(of: id).map { $0 + 1 }
            tile.setSelectionState(order: order, selectionModeActive: hasSelection)
        }
        updateDeleteButtonPresentation()
    }

    private func entryID(_ entry: HistoryEntry) -> String {
        entry.fileURL.standardizedFileURL.path
    }

    private func isSelectable(_: HistoryEntry) -> Bool {
        return true
    }

    private func updateDeleteButtonPresentation() {
        let title = hasSelection
            ? L10n.historyPanelDeleteSelected(selectedEntryIDs.count)
            : L10n.historyPanelDeleteAll
        deleteButton.confirmationTitle = title
        if isConfirmingDelete {
            deleteButtonWidthConstraint?.constant = deleteButton.expandedWidth
            layoutSubtreeIfNeeded()
        }
    }

    private func setDeleteConfirmation(_ confirming: Bool, animated: Bool) {
        guard isConfirmingDelete != confirming else { return }
        isConfirmingDelete = confirming
        deleteButton.setConfirming(confirming)
        let width = confirming ? deleteButton.expandedWidth : HistoryPanelLayout.headerButtonSize
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            deleteButtonWidthConstraint?.constant = width
            layoutSubtreeIfNeeded()
            return
        }

        layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            deleteButtonWidthConstraint?.constant = width
            animator().layoutSubtreeIfNeeded()
        }
    }

    func resetTransientState(animated: Bool) {
        clearKeyboardNavigation()
        setDeleteConfirmation(false, animated: animated)
        setShortcutGuideVisible(false)
        clearSelection()
        clearActiveHoverTile()
    }

    func syncHoverStateWithCurrentMouse() {
        guard isActive, let window, !isHidden, !isShowingShortcutGuide else {
            clearActiveHoverTile()
            return
        }

        // The first expansion loads entries while the collection was hidden.
        // Materialize its visible items before resolving the pointer target.
        layoutSubtreeIfNeeded()
        collectionView.layoutSubtreeIfNeeded()

        if isKeyboardNavigationActive {
            if let tile = visibleCollectionTiles.first(where: { entryID($0.entry) == keyboardEntryID }) {
                updateActiveHoverTile(tile, isHovered: true, fromKeyboard: true)
            }
            return
        }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let contentPoint = convert(windowPoint, from: nil)
        let scrollPoint = scrollView.convert(windowPoint, from: nil)
        guard bounds.contains(contentPoint), scrollView.bounds.contains(scrollPoint) else {
            clearActiveHoverTile()
            return
        }

        for tile in visibleCollectionTiles.reversed() {
            let tilePoint = tile.convert(windowPoint, from: nil)
            if tile.bounds.contains(tilePoint) {
                updateActiveHoverTile(tile, isHovered: true)
                return
            }
        }

        clearActiveHoverTile()
    }

    private func updateActiveHoverTile(
        _ tile: HistoryPanelTileView,
        isHovered: Bool,
        fromKeyboard: Bool = false
    ) {
        // Scrolling under a stationary pointer emits tracking events. Keep the
        // keyboard target until the user actually moves the pointer.
        guard fromKeyboard || !isKeyboardNavigationActive else { return }
        if isHovered {
            guard !isScrollingContent else {
                tile.setHovered(false)
                return
            }
            let hoverChanged = activeHoverTile !== tile
            if hoverChanged {
                activeHoverTile?.setHovered(false)
                activeHoverTile = tile
            }
            tile.setHovered(true)
            if hoverChanged {
                updateHistoryPreviewHotkey()
            }
        } else if activeHoverTile === tile {
            tile.setHovered(false)
            activeHoverTile = nil
            updateHistoryPreviewHotkey()
        } else {
            tile.setHovered(false)
        }
    }

    private func clearActiveHoverTile() {
        guard let hoveredTile = activeHoverTile else { return }
        hoveredTile.setHovered(false)
        activeHoverTile = nil
        updateHistoryPreviewHotkey()
    }

    private func updateHistoryPreviewHotkey() {
        guard isActive,
              !isShowingShortcutGuide,
              previewController == nil,
              activeHoverTile != nil else {
            HotkeyManager.shared.unregisterHistoryPreview()
            return
        }
        HotkeyManager.shared.registerHistoryPreview { [weak self] in
            guard let self,
                  self.isActive,
                  let hoveredEntry = self.activeHoverTile?.entry else { return }
            self.presentPreview(startingAt: hoveredEntry)
        }
    }

    private func startConfirmationDismissMonitoring() {
        guard confirmationDismissMonitor == nil else { return }
        confirmationDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.collapseDeleteConfirmationIfNeeded(for: event)
            return event
        }
    }

    private func stopConfirmationDismissMonitoring() {
        if let confirmationDismissMonitor {
            NSEvent.removeMonitor(confirmationDismissMonitor)
            self.confirmationDismissMonitor = nil
        }
    }

    private func startSelectionKeyMonitoring() {
        guard selectionKeyMonitor == nil else { return }
        selectionKeyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] event in
            guard let self else { return event }
            guard event.window === self.window else { return event }
            guard event.type == .keyDown else {
                if self.keyboardEntryID != nil {
                    self.clearKeyboardNavigation()
                    self.syncHoverStateWithCurrentMouse()
                }
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let shortcutModifiers = modifiers.intersection([.command, .control, .option, .shift])
            let firstResponder = event.window?.firstResponder
            if self.isActive,
               event.keyCode == UInt16(kVK_ANSI_Slash),
               shortcutModifiers == .command || shortcutModifiers == [.command, .shift] {
                self.toggleShortcutGuideClicked()
                return nil
            }
            if self.isShowingShortcutGuide {
                if event.keyCode == UInt16(kVK_Escape) {
                    self.setShortcutGuideVisible(false)
                    return nil
                }
                return event
            }
            let isHorizontalArrow = event.keyCode == UInt16(kVK_LeftArrow)
                || event.keyCode == UInt16(kVK_RightArrow)
            if self.isActive, isHorizontalArrow {
                let forward = event.keyCode == UInt16(kVK_RightArrow)
                if shortcutModifiers == .shift {
                    self.cycleFilter(forward: forward)
                    return nil
                }
                if shortcutModifiers.isEmpty {
                    guard firstResponder !== self.filterScrollView.control else { return event }
                    self.moveEntry(forward: forward)
                    return nil
                }
            }

            if event.keyCode == UInt16(kVK_Space), modifiers.isEmpty,
               !(firstResponder is NSControl),
               let hoveredEntry = self.activeHoverTile?.entry {
                self.presentPreview(startingAt: hoveredEntry)
                return nil
            }
            let hasUnsupportedSelectAllModifier = !modifiers.intersection([.control, .option, .shift]).isEmpty
            if event.keyCode == UInt16(kVK_ANSI_A),
               modifiers.contains(.command),
               !hasUnsupportedSelectAllModifier {
                self.setDeleteConfirmation(false, animated: true)
                self.selectedEntryIDs = self.visibleEntries
                    .filter(self.isSelectable)
                    .map(self.entryID)
                self.lastSelectionAnchorID = self.selectedEntryIDs.first
                self.refreshTileSelectionStates()
                return nil
            }

            if event.keyCode == UInt16(kVK_Escape) {
                if self.isConfirmingDelete {
                    self.setDeleteConfirmation(false, animated: true)
                } else if self.hasSelection {
                    self.clearSelection()
                } else {
                    return event
                }
                return nil
            }
            return event
        }
    }

    private func presentPreview(startingAt entry: HistoryEntry) {
        let previewEntries = visibleEntries.filter { $0.kind == entry.kind }
        guard !previewEntries.isEmpty else { return }
        HotkeyManager.shared.unregisterHistoryPreview()
        previewController?.close()
        guard previewController?.window?.isVisible != true else { return }
        let controller = HistoryPreviewWindowController(
            entries: previewEntries,
            initialEntry: entry,
            onEdit: { [weak self] selectedEntry in
                self?.previewController = nil
                self?.onRequestDismiss?()
                self?.onEditEntry(selectedEntry)
            }
        )
        controller.onClose = { [weak self, weak controller] in
            guard self?.previewController === controller else { return }
            self?.previewController = nil
            self?.syncHoverStateWithCurrentMouse()
        }
        previewController = controller
        controller.show(relativeTo: window?.screen)
    }

    private func stopSelectionKeyMonitoring() {
        if let selectionKeyMonitor {
            NSEvent.removeMonitor(selectionKeyMonitor)
            self.selectionKeyMonitor = nil
        }
    }

    private func updateContentVisibility() {
        scrollView.isHidden = isShowingShortcutGuide
        shortcutGuideView.isHidden = !isShowingShortcutGuide
        emptyLabel.isHidden = isShowingShortcutGuide || !visibleEntries.isEmpty
    }

    private func collapseDeleteConfirmationIfNeeded(for event: NSEvent) {
        guard isConfirmingDelete else { return }
        guard let eventWindow = event.window, let hostWindow = window, eventWindow === hostWindow else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }

        let deleteRect = deleteButton.convert(deleteButton.bounds, to: self)
        if !deleteRect.contains(point) {
            setDeleteConfirmation(false, animated: true)
        }
    }

    @objc private func scrollBoundsDidChange() {
        let currentOriginX = scrollView.contentView.bounds.origin.x
        let didScrollHorizontally = currentOriginX != lastScrollOriginX
        let direction: PreviewPrefetchDirection = currentOriginX >= lastScrollOriginX ? .forward : .backward
        lastScrollOriginX = currentOriginX
        // Initial layout and resizing also emit bounds changes. Only actual
        // scrolling should suspend hover and the Space preview shortcut.
        if didScrollHorizontally {
            suspendHoverUpdatesDuringScrolling()
        }
        loadNextPageIfNeeded()
        visibleCollectionTiles.forEach { $0.loadPreviewIfNeeded() }
        updatePreviewLoading(direction: direction)
    }

    private func suspendHoverUpdatesDuringScrolling() {
        guard isActive, !isKeyboardNavigationActive else { return }
        if !isScrollingContent {
            isScrollingContent = true
            clearActiveHoverTile()
        }

        hoverSyncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isActive else { return }
            self.isScrollingContent = false
            self.hoverSyncWorkItem = nil
            self.syncHoverStateWithCurrentMouse()
        }
        hoverSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private static func filteredEntries(from entries: [HistoryEntry], filter: HistoryPanelFilter) -> [HistoryEntry] {
        entries.filter { entryMatches($0, filter: filter) }
    }

    private static func availableFilters(for entries: [HistoryEntry]) -> [HistoryPanelFilter] {
        HistoryPanelFilter.allCases.filter { filter in
            switch filter {
            case .all:
                return true
            case .favorites:
                return HistoryFavoritePolicy.shouldShowFilter(for: entries)
            case .screenshots, .gif, .mp4:
                return entries.contains { entryMatches($0, filter: filter) }
            }
        }
    }

    private static func entryMatches(_ entry: HistoryEntry, filter: HistoryPanelFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .favorites:
            return HistoryManager.isFavorite(url: entry.fileURL)
        case .screenshots:
            guard case .image = entry.kind else { return false }
            return entry.fileURL.pathExtension.lowercased() != "gif"
        case .gif:
            guard case .image = entry.kind else { return false }
            return entry.fileURL.pathExtension.lowercased() == "gif"
        case .mp4:
            guard case .video = entry.kind else { return false }
            return true
        }
    }

    private var visibleCollectionTiles: [HistoryPanelTileView] {
        collectionView.visibleItems().compactMap { item in
            (item as? HistoryPanelCollectionItem)?.tileView
        }
    }

    private func warmInitialPreviewWindow() {
        previewWarmGeneration += 1
        let generation = previewWarmGeneration
        let filter = selectedFilter
        entriesQueue.async { [weak self] in
            let entries = Self.filteredEntries(from: HistoryManager.shared.panelEntries(), filter: filter)
            let initialEntries = Array(entries.prefix(Self.initialPreviewCount))
            DispatchQueue.main.async {
                guard let self, self.previewWarmGeneration == generation else { return }
                self.prefetchPreviews(for: initialEntries)
            }
        }
    }

    private func updatePreviewLoading(
        initial: Bool = false,
        direction: PreviewPrefetchDirection = .forward
    ) {
        guard isActive, !visibleEntries.isEmpty else { return }
        if initial {
            visibleCollectionTiles.forEach { $0.loadPreviewIfNeeded() }
        }

        let entriesToPrefetch: [HistoryEntry]
        if initial {
            let startIndex = visibleIndexRange()?.lowerBound ?? 0
            let endIndex = min(startIndex + Self.initialPreviewCount, visibleEntries.count)
            entriesToPrefetch = startIndex < endIndex
                ? Array(visibleEntries[startIndex..<endIndex])
                : []
        } else if let visibleRange = visibleIndexRange() {
            switch direction {
            case .forward:
                let startIndex = visibleRange.upperBound + 1
                let endIndex = min(startIndex + Self.previewPrefetchCount, visibleEntries.count)
                entriesToPrefetch = startIndex < endIndex
                    ? Array(visibleEntries[startIndex..<endIndex])
                    : []
            case .backward:
                let endIndex = visibleRange.lowerBound
                let startIndex = max(0, endIndex - Self.previewPrefetchCount)
                entriesToPrefetch = startIndex < endIndex
                    ? Array(visibleEntries[startIndex..<endIndex])
                    : []
            }
        } else {
            entriesToPrefetch = Array(visibleEntries.prefix(Self.initialPreviewCount))
        }
        prefetchPreviews(for: entriesToPrefetch)
    }

    private func visibleIndexRange() -> ClosedRange<Int>? {
        guard renderedEntryCount > 0 else { return nil }
        let visibleRect = scrollView.documentVisibleRect
        let itemStride = presentation.tileWidth + collectionLayout.minimumLineSpacing
        guard itemStride > 0 else { return nil }

        let leading = collectionLayout.sectionInset.left
        let firstIndex = max(0, Int(floor((visibleRect.minX - leading) / itemStride)))
        let lastIndex = min(
            renderedEntryCount - 1,
            max(firstIndex, Int(floor((visibleRect.maxX - leading - 1) / itemStride)))
        )
        guard firstIndex <= lastIndex else { return nil }
        return firstIndex...lastIndex
    }

    private func prefetchPreviews(for entries: [HistoryEntry]) {
        let entryIDs = Set(entries.map { $0.fileURL.standardizedFileURL.path })

        let staleEntryIDs = previewPrefetchRequests.keys.filter { !entryIDs.contains($0) }
        for entryID in staleEntryIDs {
            previewPrefetchRequests.removeValue(forKey: entryID)?.cancel()
        }
        previewPrefetchEntryIDs = entryIDs

        let pixelSize = presentation.previewPixelSize
        for entry in entries {
            let entryID = entry.fileURL.standardizedFileURL.path
            guard previewPrefetchRequests[entryID] == nil else { continue }

            switch entry.kind {
            case .image:
                guard HistoryImagePreviewLoader.shared.cachedPreview(
                    url: entry.fileURL,
                    pixelSize: pixelSize
                ) == nil else { continue }
                let request = HistoryImagePreviewLoader.shared.load(
                    url: entry.fileURL,
                    pixelSize: pixelSize,
                    priority: .prefetch,
                    completion: { [weak self] _ in
                        self?.previewPrefetchRequests.removeValue(forKey: entryID)
                    }
                )
                previewPrefetchRequests[entryID] = request
            case .video:
                guard HistoryImagePreviewLoader.shared.cachedVideoFrame(
                    url: entry.fileURL,
                    pixelSize: pixelSize
                ) == nil else { continue }
                let request = HistoryImagePreviewLoader.shared.loadVideoFrame(
                    url: entry.fileURL,
                    pixelSize: pixelSize,
                    priority: .prefetch,
                    completion: { [weak self] _ in
                        self?.previewPrefetchRequests.removeValue(forKey: entryID)
                    }
                )
                previewPrefetchRequests[entryID] = request
            }
        }
    }

    private func updateCollectionLayout() {
        let itemSize = NSSize(width: presentation.tileWidth, height: presentation.tileHeight)
        if collectionLayout.itemSize != itemSize {
            collectionLayout.itemSize = itemSize
            collectionLayout.invalidateLayout()
        }
    }

    private func loadNextPageIfNeeded() {
        guard isActive, !isAppendingPage, renderedEntryCount < visibleEntries.count else { return }
        let visibleRect = scrollView.documentVisibleRect
        let contentWidth = collectionLayout.collectionViewContentSize.width
        let threshold = max(scrollView.bounds.width * 0.75, presentation.tileWidth * 3)
        guard contentWidth - visibleRect.maxX <= threshold else { return }

        appendNextPage()
    }

    private func appendNextPage() {
        let oldCount = renderedEntryCount
        let newCount = min(oldCount + Self.pageSize, visibleEntries.count)
        guard newCount > oldCount else { return }
        isAppendingPage = true
        renderedEntryCount = newCount
        let indexPaths = Set((oldCount..<newCount).map { IndexPath(item: $0, section: 0) })
        collectionView.insertItems(at: indexPaths)
        collectionLayout.invalidateLayout()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.collectionView.layoutSubtreeIfNeeded()
            self.isAppendingPage = false
            if self.isKeyboardNavigationActive {
                if let index = self.visibleEntries.firstIndex(where: {
                    self.entryID($0) == self.keyboardEntryID
                }) {
                    self.revealEntry(at: index)
                }
                self.syncHoverStateWithCurrentMouse()
            }
        }
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        renderedEntryCount
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: HistoryPanelCollectionItem.identifier,
            for: indexPath
        ) as! HistoryPanelCollectionItem
        guard indexPath.item < renderedEntryCount, indexPath.item < visibleEntries.count else {
            item.clear()
            return item
        }

        let entry = visibleEntries[indexPath.item]
        item.configure(
            entry: entry,
            presentation: presentation,
            onRequestDismiss: { [weak self] in
                self?.onRequestDismiss?()
            },
            onHoverChanged: { [weak self] tile, isHovered in
                self?.updateActiveHoverTile(tile, isHovered: isHovered)
            },
            onSelectionToggle: { [weak self] tile, event in
                self?.handleSelectionToggle(for: tile, event: event)
            },
            onPrimaryClick: { [weak self] tile, event in
                self?.handlePrimaryClick(for: tile, event: event)
            },
            onFavoriteToggle: { [weak self] tile in
                self?.handleFavoriteToggle(for: tile)
            },
            dragEntriesProvider: { [weak self] tile in
                self?.dragEntries(for: tile) ?? [tile.entry]
            }
        )
        let order = selectedEntryIDs.firstIndex(of: entryID(entry)).map { $0 + 1 }
        item.tileView?.setSelectionState(order: order, selectionModeActive: hasSelection)
        item.tileView?.loadPreviewIfNeeded()
        return item
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didEndDisplaying item: NSCollectionViewItem,
        forRepresentedObjectAt indexPath: IndexPath
    ) {
        guard let tile = (item as? HistoryPanelCollectionItem)?.tileView else { return }
        tile.cancelPendingPreviewLoad()
        if activeHoverTile === tile {
            clearActiveHoverTile()
        }
    }
}

private final class HistoryPanelCenteredTextView: NSView {
    private struct CachedTextLayout {
        let attributedString: NSAttributedString
        let textBounds: NSRect
        let textRect: NSRect
    }

    private final class CachedTextLayoutBox: NSObject {
        let layout: CachedTextLayout

        init(_ layout: CachedTextLayout) {
            self.layout = layout
        }
    }

    private static let textLayoutCache: NSCache<NSString, CachedTextLayoutBox> = {
        let cache = NSCache<NSString, CachedTextLayoutBox>()
        cache.countLimit = 512
        cache.totalCostLimit = 4 * 1024 * 1024
        return cache
    }()

    var ignoresHitTesting = false
    private var cachedTextLayout: CachedTextLayout?

    var stringValue: String = "" {
        didSet { invalidateTextLayout() }
    }

    var font: NSFont = NSFont.systemFont(ofSize: 13, weight: .semibold) {
        didSet { invalidateTextLayout() }
    }

    var textColor: NSColor = .white {
        didSet { invalidateTextLayout() }
    }

    var alignment: NSTextAlignment = .center {
        didSet { invalidateTextLayout() }
    }

    var horizontalInset: CGFloat = 8 {
        didSet { invalidateTextLayout() }
    }

    var verticalInset: CGFloat = 0 {
        didSet { invalidateTextLayout() }
    }

    var lineBreakMode: NSLineBreakMode = .byTruncatingTail {
        didSet { invalidateTextLayout() }
    }

    var minimumFontSize: CGFloat = 0 {
        didSet { invalidateTextLayout() }
    }

    override var toolTip: String? {
        didSet { super.toolTip = toolTip }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        ignoresHitTesting ? nil : super.hitTest(point)
    }

    override func setFrameSize(_ newSize: NSSize) {
        if frame.size != newSize {
            cachedTextLayout = nil
        }
        super.setFrameSize(newSize)
    }

    override func setBoundsSize(_ newSize: NSSize) {
        if bounds.size != newSize {
            cachedTextLayout = nil
        }
        super.setBoundsSize(newSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let textLayout = textLayout() else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: textLayout.textBounds).addClip()
        textLayout.attributedString.draw(
            with: textLayout.textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private func invalidateTextLayout() {
        cachedTextLayout = nil
        needsDisplay = true
    }

    private func textLayout() -> CachedTextLayout? {
        if let cachedTextLayout {
            return cachedTextLayout
        }
        guard !stringValue.isEmpty else { return nil }

        let textBounds = bounds.insetBy(dx: horizontalInset, dy: verticalInset)
        guard textBounds.width > 0, textBounds.height > 0 else { return nil }
        let cacheKey = textLayoutCacheKey(textBounds: textBounds)
        if let cachedLayout = Self.textLayoutCache.object(forKey: cacheKey)?.layout {
            cachedTextLayout = cachedLayout
            return cachedLayout
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreakMode

        let fittedFont = fontFitting(in: textBounds.size, paragraphStyle: paragraph)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: fittedFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        let attributedString = NSAttributedString(string: stringValue, attributes: attributes)
        let measured = measuredRect(for: attributedString, fitting: textBounds.size)
        let textHeight = min(ceil(measured.height), textBounds.height)
        let textRect = NSRect(
            x: textBounds.minX,
            y: textBounds.midY - textHeight / 2,
            width: textBounds.width,
            height: textHeight
        )
        let textLayout = CachedTextLayout(
            attributedString: attributedString,
            textBounds: textBounds,
            textRect: textRect
        )
        cachedTextLayout = textLayout
        let estimatedCost = min(stringValue.utf8.count * 2 + 256, 128 * 1024)
        Self.textLayoutCache.setObject(
            CachedTextLayoutBox(textLayout),
            forKey: cacheKey,
            cost: estimatedCost
        )
        return textLayout
    }

    private func textLayoutCacheKey(textBounds: NSRect) -> NSString {
        let fontSize = String(describing: font.pointSize)
        let colorHash = String(textColor.hash)
        let alignmentValue = String(alignment.rawValue)
        let lineBreakValue = String(lineBreakMode.rawValue)
        let horizontalInsetValue = String(describing: horizontalInset)
        let verticalInsetValue = String(describing: verticalInset)
        let minimumFontSizeValue = String(describing: minimumFontSize)
        let components: [String] = [
            font.fontName,
            fontSize,
            colorHash,
            alignmentValue,
            lineBreakValue,
            horizontalInsetValue,
            verticalInsetValue,
            minimumFontSizeValue,
            NSStringFromRect(textBounds),
            stringValue
        ]
        return components.joined(separator: "\u{1F}") as NSString
    }

    private func fontFitting(in size: NSSize, paragraphStyle: NSParagraphStyle) -> NSFont {
        guard minimumFontSize > 0, lineBreakMode != .byWordWrapping, lineBreakMode != .byCharWrapping else {
            return font
        }

        func fits(_ pointSize: CGFloat) -> Bool {
            let candidate = font.withPointSize(pointSize)
            let attributed = NSAttributedString(
                string: stringValue,
                attributes: [.font: candidate, .paragraphStyle: paragraphStyle]
            )
            let measured = measuredRect(for: attributed, fitting: size)
            return ceil(measured.width) <= size.width && ceil(measured.height) <= size.height
        }

        guard !fits(font.pointSize) else { return font }

        var lowerBound = min(minimumFontSize, font.pointSize)
        var upperBound = font.pointSize
        while upperBound - lowerBound > 0.5 {
            let midpoint = (lowerBound + upperBound) / 2
            if fits(midpoint) {
                lowerBound = midpoint
            } else {
                upperBound = midpoint
            }
        }
        return font.withPointSize(lowerBound)
    }

    private func measuredRect(for attributed: NSAttributedString, fitting size: NSSize) -> NSRect {
        let measuringSize: NSSize
        switch lineBreakMode {
        case .byWordWrapping, .byCharWrapping:
            measuringSize = NSSize(width: size.width, height: .greatestFiniteMagnitude)
        default:
            measuringSize = NSSize(width: .greatestFiniteMagnitude, height: size.height)
        }
        return attributed.boundingRect(
            with: measuringSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
    }
}

private extension NSFont {
    func withPointSize(_ pointSize: CGFloat) -> NSFont {
        NSFont(descriptor: fontDescriptor, size: pointSize) ?? self
    }
}

private final class HistoryPanelShortcutGuideDocumentView: NSView {
    override var isFlipped: Bool { true }
}

private final class HistoryPanelShortcutGuideView: NSView {
    fileprivate struct Item {
        let shortcut: String
        let description: String
    }

    private let scrollView = NSScrollView()
    private let documentView = HistoryPanelShortcutGuideDocumentView()
    private let horizontalCardMargin: CGFloat
    private let verticalCardMargin: CGFloat
    private var groups: [HistoryPanelShortcutGroupView] = []

    init(presentation: HistoryPanelPresentation) {
        horizontalCardMargin = presentation.stripSideInset
        verticalCardMargin = presentation.stripSideInset > 0
            ? presentation.stripSideInset
            : presentation.outerInset
        super.init(frame: .zero)

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScroller = nil
        scrollView.verticalScroller = nil
        scrollView.borderType = .noBorder
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = documentView
        addSubview(scrollView)

        reload()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds

        let cardGap: CGFloat = 12
        let columnCount = 3
        let rowCount = 2
        let minimumCellWidth: CGFloat = 300
        let minimumContentWidth = horizontalCardMargin * 2
            + CGFloat(columnCount) * minimumCellWidth
            + CGFloat(columnCount - 1) * cardGap
        let contentWidth = max(bounds.width, minimumContentWidth)
        let cellWidth =
            (contentWidth - horizontalCardMargin * 2 - CGFloat(columnCount - 1) * cardGap)
            / CGFloat(columnCount)
        let cellHeight = max(
            1,
            (bounds.height - verticalCardMargin * 2 - CGFloat(rowCount - 1) * cardGap)
                / CGFloat(rowCount)
        )
        documentView.frame = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: bounds.height
        )

        for (index, group) in groups.enumerated() {
            let column = index % columnCount
            let row = index / columnCount
            group.frame = NSRect(
                x: horizontalCardMargin + CGFloat(column) * (cellWidth + cardGap),
                y: verticalCardMargin + CGFloat(row) * (cellHeight + cardGap),
                width: cellWidth,
                height: cellHeight
            )
        }
    }

    func reload() {
        groups.forEach { $0.removeFromSuperview() }
        groups = Self.itemGroups.map {
            HistoryPanelShortcutGroupView(items: $0)
        }
        groups.forEach(documentView.addSubview)
        scrollView.contentView.scroll(to: .zero)
        needsLayout = true
    }

    private static var itemGroups: [[Item]] {
        let click = L10n.historyPanelShortcutKeyClick
        let drag = L10n.historyPanelShortcutKeyDrag
        let space = L10n.historyPanelShortcutKeySpace
        return [
            [
                Item(shortcut: "←  →", description: L10n.historyPanelShortcutSwitchItem),
                Item(shortcut: "⇧ ←  /  ⇧ →", description: L10n.historyPanelShortcutSwitchFilter),
                Item(shortcut: "Esc", description: L10n.historyPanelShortcutCancel),
            ],
            [
                Item(shortcut: "⌘ \(click)", description: L10n.historyPanelShortcutToggleSelection),
                Item(shortcut: "⇧ \(click)", description: L10n.historyPanelShortcutRangeSelection),
                Item(shortcut: "⌘ A", description: L10n.historyPanelShortcutSelectAll),
            ],
            [
                Item(shortcut: click, description: L10n.historyPanelShortcutCopyItem),
                Item(shortcut: drag, description: L10n.historyPanelShortcutDragItem),
                Item(shortcut: space, description: L10n.historyPanelShortcutOpenPreview),
            ],
            [
                Item(shortcut: "←  →", description: L10n.historyPanelShortcutBrowsePreview),
                Item(shortcut: "\(space) / Esc", description: L10n.historyPanelShortcutClosePreview),
                Item(shortcut: "C", description: L10n.historyPanelShortcutCopyPreview),
            ],
            [
                Item(shortcut: "E", description: L10n.historyPanelShortcutEditImage),
                Item(shortcut: "P", description: L10n.historyPanelShortcutPinImage),
                Item(shortcut: "⌘ ?", description: L10n.historyPanelShortcutToggleGuide),
            ],
        ]
    }
}

private final class HistoryPanelShortcutGroupView: NSView {
    private let rows: [HistoryPanelShortcutRowView]

    override var isFlipped: Bool { true }

    init(items: [HistoryPanelShortcutGuideView.Item]) {
        rows = items.map {
            HistoryPanelShortcutRowView(shortcut: $0.shortcut, description: $0.description)
        }
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
        updateBackground()
        rows.forEach(addSubview)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func updateBackground() {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(.quaternarySystemFill, for: effectiveAppearance)
    }

    override func layout() {
        super.layout()
        let contentPadding: CGFloat = 5
        let rowHeight = max(1, (bounds.height - contentPadding * 2) / CGFloat(max(3, rows.count)))
        let topOffset = rows.count == 2 ? rowHeight / 2 : 0
        for (index, row) in rows.enumerated() {
            row.frame = NSRect(
                x: contentPadding,
                y: contentPadding + topOffset + CGFloat(index) * rowHeight,
                width: max(0, bounds.width - contentPadding * 2),
                height: rowHeight
            )
        }
    }
}

private final class HistoryPanelShortcutRowView: NSView {
    private let shortcutLabel = HistoryPanelCenteredTextView()
    private let shortcutCapsule = AdaptiveChromeSurfaceView(style: .card, cornerRadius: 5)
    private let descriptionLabel = HistoryPanelCenteredTextView()

    init(shortcut: String, description: String) {
        super.init(frame: .zero)

        addSubview(shortcutCapsule)

        shortcutLabel.stringValue = shortcut
        shortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .semibold)
        shortcutLabel.textColor = .labelColor
        shortcutLabel.alignment = .center
        shortcutLabel.horizontalInset = 0
        shortcutLabel.verticalInset = 0
        shortcutLabel.lineBreakMode = .byClipping
        shortcutLabel.ignoresHitTesting = true
        shortcutCapsule.addSubview(shortcutLabel)

        descriptionLabel.stringValue = description
        descriptionLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
        descriptionLabel.textColor = .labelColor
        descriptionLabel.alignment = .left
        descriptionLabel.horizontalInset = 0
        descriptionLabel.verticalInset = 0
        descriptionLabel.lineBreakMode = .byClipping
        descriptionLabel.ignoresHitTesting = true
        addSubview(descriptionLabel)

        setAccessibilityLabel("\(shortcut) \(description)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let gap: CGFloat = 7
        let measuredWidth = ceil(
            (shortcutLabel.stringValue as NSString).size(withAttributes: [.font: shortcutLabel.font as Any]).width
        )
        let capsuleWidth = min(88, max(38, measuredWidth + 12))
        let capsuleHeight = min(18, max(1, bounds.height - 2))
        shortcutCapsule.frame = NSRect(
            x: 0,
            y: bounds.midY - capsuleHeight / 2,
            width: capsuleWidth,
            height: capsuleHeight
        )
        shortcutLabel.frame = shortcutCapsule.bounds
        descriptionLabel.frame = NSRect(
            x: shortcutCapsule.frame.maxX + gap,
            y: 0,
            width: max(0, bounds.width - shortcutCapsule.frame.maxX - gap),
            height: bounds.height
        )
    }
}

private final class HistorySelectionBadgeView: NSView {
    private static let size = HistoryItemCornerControlMetrics.size
    private let label = NSTextField(labelWithString: "")

    var order: Int? {
        didSet { applyAppearance() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = Self.size / 2
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1.25

        label.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        label.alignment = .center
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -0.5)
        ])

        applyAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func applyAppearance() {
        if let order {
            label.stringValue = "\(order)"
            label.textColor = .white
            layer?.backgroundColor = accentGreen.withAlphaComponent(0.96).cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(0.78).cgColor
        } else {
            label.stringValue = ""
            layer?.backgroundColor = NSColor.black.withAlphaComponent(0.34).cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(0.76).cgColor
        }
    }
}

private final class HistoryPanelDeleteButton: NSButton {
    private var isConfirming = false

    var confirmationTitle = "" {
        didSet {
            toolTip = confirmationTitle
            setAccessibilityLabel(confirmationTitle)
            if isConfirming { title = confirmationTitle }
        }
    }

    var expandedWidth: CGFloat {
        max(96, ceil(intrinsicContentSize.width))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        controlSize = .regular
        if #available(macOS 26.0, *) {
            bezelStyle = .glass
            borderShape = .capsule
            tintProminence = .secondary
        } else {
            bezelStyle = .push
        }
        image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
        imageScaling = .scaleProportionallyDown
        setButtonType(.momentaryPushIn)
        setConfirming(false)
        isEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setConfirming(_ confirming: Bool) {
        isConfirming = confirming
        title = confirming ? confirmationTitle : ""
        imagePosition = confirming ? .imageLeading : .imageOnly
        hasDestructiveAction = confirming
        bezelColor = confirming ? .systemRed : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private final class HistoryPanelActionButton: NSButton {
    init(symbolName: String, accessibilityLabel: String, isToggle: Bool = false) {
        super.init(frame: .zero)
        title = ""
        controlSize = .regular
        bezelStyle = isToggle ? .accessoryBar : .accessoryBarAction
        setButtonType(isToggle ? .pushOnPushOff : .momentaryPushIn)
        showsBorderOnlyWhileMouseInside = !isToggle
        if #available(macOS 26.0, *) {
            borderShape = .capsule
        }
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        updateAccessibilityLabel(accessibilityLabel)
        updateSymbol(symbolName)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: HistoryPanelLayout.headerButtonSize),
            heightAnchor.constraint(equalToConstant: HistoryPanelLayout.headerButtonSize),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateAccessibilityLabel(_ label: String) {
        toolTip = label
        setAccessibilityLabel(label)
    }

    func updateSymbol(_ symbolName: String) {
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private final class HistoryPanelCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("HistoryPanelCollectionItem")

    private(set) var tileView: HistoryPanelTileView?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func configure(
        entry: HistoryEntry,
        presentation: HistoryPanelPresentation,
        onRequestDismiss: (() -> Void)?,
        onHoverChanged: @escaping (HistoryPanelTileView, Bool) -> Void,
        onSelectionToggle: @escaping (HistoryPanelTileView, NSEvent) -> Void,
        onPrimaryClick: @escaping (HistoryPanelTileView, NSEvent) -> Void,
        onFavoriteToggle: @escaping (HistoryPanelTileView) -> Void,
        dragEntriesProvider: @escaping (HistoryPanelTileView) -> [HistoryEntry]
    ) {
        if let tileView {
            tileView.reconfigure(with: entry)
            tileView.isHidden = false
            return
        }
        let tile = HistoryPanelTileView(
            entry: entry,
            presentation: presentation,
            onRequestDismiss: onRequestDismiss,
            onHoverChanged: onHoverChanged,
            onSelectionToggle: onSelectionToggle,
            onPrimaryClick: onPrimaryClick,
            onFavoriteToggle: onFavoriteToggle,
            dragEntriesProvider: dragEntriesProvider
        )
        tile.frame = view.bounds
        tile.autoresizingMask = [.width, .height]
        view.addSubview(tile)
        tileView = tile
    }

    func clear() {
        tileView?.cancelPendingPreviewLoad()
        tileView?.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tileView?.prepareForCollectionReuse()
    }
}

private final class HistoryPanelTileView: NSView, NSDraggingSource {
    private enum PreviewLoadState {
        case idle
        case loading
        case loaded
    }

    private(set) var entry: HistoryEntry
    private let presentation: HistoryPanelPresentation
    private let onRequestDismiss: (() -> Void)?
    private let onHoverChanged: ((HistoryPanelTileView, Bool) -> Void)?
    private let onSelectionToggle: ((HistoryPanelTileView, NSEvent) -> Void)?
    private let onPrimaryClick: ((HistoryPanelTileView, NSEvent) -> Void)?
    private let onFavoriteToggle: ((HistoryPanelTileView) -> Void)?
    private let dragEntriesProvider: ((HistoryPanelTileView) -> [HistoryEntry])?
    private let imageView = NSImageView()
    private let overlayLabel = HistoryPanelCenteredTextView()
    private let favoriteButton = HistoryFavoriteButton()
    private let badgeView = HistoryMediaBadgeView()
    private let selectionBadgeView = HistorySelectionBadgeView()
    private let metaLabel = HistoryPanelCenteredTextView()
    private var trackingArea: NSTrackingArea?
    private var previewRequest: HistoryImagePreviewRequest?
    private var mouseDownPoint: NSPoint?
    private var mouseDownHitSelectionBadge = false
    private var isHovered = false
    private var isSelectionModeActive = false
    private var selectionOrder: Int?
    private var didStartDrag = false
    private var didDismissForCurrentDrag = false
    private var previewLoadState: PreviewLoadState = .idle
    private var previewLoadGeneration = 0

    init(
        entry: HistoryEntry,
        presentation: HistoryPanelPresentation,
        onRequestDismiss: (() -> Void)? = nil,
        onHoverChanged: ((HistoryPanelTileView, Bool) -> Void)? = nil,
        onSelectionToggle: ((HistoryPanelTileView, NSEvent) -> Void)? = nil,
        onPrimaryClick: ((HistoryPanelTileView, NSEvent) -> Void)? = nil,
        onFavoriteToggle: ((HistoryPanelTileView) -> Void)? = nil,
        dragEntriesProvider: ((HistoryPanelTileView) -> [HistoryEntry])? = nil
    ) {
        self.entry = entry
        self.presentation = presentation
        self.onRequestDismiss = onRequestDismiss
        self.onHoverChanged = onHoverChanged
        self.onSelectionToggle = onSelectionToggle
        self.onPrimaryClick = onPrimaryClick
        self.onFavoriteToggle = onFavoriteToggle
        self.dragEntriesProvider = dragEntriesProvider
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous

        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 7
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        addSubview(imageView)


        let overlayHint = L10n.historyPanelCopyDragHint.replacingOccurrences(of: " · ", with: "\n")
        overlayLabel.stringValue = overlayHint
        overlayLabel.isHidden = overlayHint.isEmpty
        overlayLabel.font = NSFont.systemFont(ofSize: presentation == .dialog ? 13 : 12, weight: .bold)
        overlayLabel.textColor = .white
        overlayLabel.alignment = .center
        overlayLabel.horizontalInset = 10
        overlayLabel.verticalInset = 8
        overlayLabel.lineBreakMode = .byWordWrapping
        overlayLabel.ignoresHitTesting = true
        overlayLabel.alphaValue = 0
        overlayLabel.layer?.cornerRadius = 7
        overlayLabel.layer?.cornerCurve = .continuous
        overlayLabel.layer?.masksToBounds = true
        overlayLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.56).cgColor
        addSubview(overlayLabel)


        favoriteButton.target = self
        favoriteButton.action = #selector(favoriteButtonClicked)
        addSubview(favoriteButton)


        if let badgeKind = HistoryMediaBadgeKind(entry: entry) {
            badgeView.configure(kind: badgeKind)
            badgeView.isHidden = false
        } else {
            badgeView.isHidden = true
        }
        addSubview(badgeView)

        selectionBadgeView.isHidden = true
        addSubview(selectionBadgeView)

        let metadataFontSize: CGFloat = presentation == .dialog ? 12 : 9.5
        metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: metadataFontSize, weight: .semibold)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.alignment = .center
        metaLabel.horizontalInset = 0
        metaLabel.ignoresHitTesting = true
        addSubview(metaLabel)

        reconfigure(with: entry)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        previewRequest?.cancel()
    }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func favoriteButtonClicked() {
        onFavoriteToggle?(self)
    }

    func refreshFavoriteState() {
        let isFavorite = HistoryManager.isFavorite(url: entry.fileURL)
        favoriteButton.isFavorite = isFavorite
        favoriteButton.updateAccessibilityLabel(
            isFavorite ? L10n.historyPanelUnfavorite : L10n.historyPanelFavorite
        )
        favoriteButton.isHidden = !HistoryFavoriteButton.shouldBeVisible(
            isFavorite: isFavorite,
            isHovered: isHovered
        )
        needsLayout = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, frame.contains(point) else { return nil }
        let localPoint = convert(point, from: superview)
        if !favoriteButton.isHidden, favoriteButton.frame.contains(localPoint) {
            return favoriteButton
        }
        return super.hitTest(point)
    }

    override func layout() {
        super.layout()
        let padding: CGFloat = 12
        imageView.frame = NSRect(
            x: padding,
            y: padding,
            width: bounds.width - padding * 2,
            height: presentation.previewHeight
        )
        overlayLabel.frame = imageView.frame
        let selectionSize = selectionBadgeView.intrinsicContentSize
        selectionBadgeView.frame = NSRect(
            x: imageView.frame.maxX - selectionSize.width
                + HistoryItemCornerControlMetrics.horizontalPreviewOverlap,
            y: imageView.frame.minY - 5,
            width: selectionSize.width,
            height: selectionSize.height
        )
        if !badgeView.isHidden {
            let badgeSize = badgeView.intrinsicContentSize
            badgeView.frame = NSRect(
                x: imageView.frame.minX - HistoryItemCornerControlMetrics.horizontalPreviewOverlap,
                y: imageView.frame.maxY - badgeSize.height
                    + HistoryItemCornerControlMetrics.favoritePreviewOverlap,
                width: badgeSize.width,
                height: badgeSize.height
            )
        }
        let favoriteSize = favoriteButton.intrinsicContentSize
        favoriteButton.frame = NSRect(
            x: selectionBadgeView.frame.midX - favoriteSize.width / 2,
            y: imageView.frame.maxY - favoriteSize.height + HistoryItemCornerControlMetrics.favoritePreviewOverlap,
            width: favoriteSize.width,
            height: favoriteSize.height
        )
        metaLabel.frame = NSRect(
            x: padding,
            y: imageView.frame.maxY + 9,
            width: bounds.width - padding * 2,
            height: 18
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        if let onHoverChanged {
            onHoverChanged(self, true)
        } else {
            setHovered(true)
        }
    }

    override func mouseExited(with event: NSEvent) {
        if let onHoverChanged {
            onHoverChanged(self, false)
        } else {
            setHovered(false)
        }
    }

    func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        updateTileAppearance()
        overlayLabel.alphaValue = hovered && !overlayLabel.isHidden ? 1 : 0
        refreshFavoriteState()
        updateSelectionBadgeVisibility()
    }

    func setSelectionState(order: Int?, selectionModeActive: Bool) {
        selectionOrder = order
        isSelectionModeActive = selectionModeActive
        selectionBadgeView.order = order
        updateTileAppearance()
        updateSelectionBadgeVisibility()
        needsLayout = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTileAppearance()
    }

    private func updateTileAppearance() {
        let selected = selectionOrder != nil
        let fill: NSColor = isHovered ? .tertiarySystemFill : .quaternarySystemFill
        let border: NSColor = selected ? .controlAccentColor : .separatorColor
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(fill, for: effectiveAppearance)
        layer?.borderColor = AdaptiveChrome.resolvedCGColor(border, for: effectiveAppearance)
        layer?.borderWidth = selected ? 2 : 1
        let previewBackground: NSColor = imageView.contentTintColor == nil ? .clear : .quinarySystemFill
        imageView.layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(previewBackground, for: effectiveAppearance)
    }

    private func updateSelectionBadgeVisibility() {
        selectionBadgeView.isHidden = !isHovered && !isSelectionModeActive && selectionOrder == nil
        needsLayout = true
    }

    func reconfigure(with entry: HistoryEntry) {
        cancelPendingPreviewLoad()
        previewLoadGeneration += 1
        self.entry = entry
        previewLoadState = .idle

        imageView.image = nil
        imageView.alphaValue = 1
        imageView.contentTintColor = nil
        toolTip = nil
        metaLabel.lineBreakMode = .byTruncatingTail

        let overlayHint = L10n.historyPanelCopyDragHint.replacingOccurrences(of: " · ", with: "\n")
        overlayLabel.stringValue = overlayHint
        overlayLabel.isHidden = overlayHint.isEmpty
        overlayLabel.alphaValue = 0


        if let badgeKind = HistoryMediaBadgeKind(entry: entry) {
            badgeView.configure(kind: badgeKind)
            badgeView.isHidden = false
        } else {
            badgeView.isHidden = true
        }

        isHovered = false
        isSelectionModeActive = false
        selectionOrder = nil
        selectionBadgeView.order = nil
        selectionBadgeView.isHidden = true
        updateTileAppearance()
        refreshFavoriteState()

        mouseDownPoint = nil
        mouseDownHitSelectionBadge = false
        didStartDrag = false
        didDismissForCurrentDrag = false

        switch entry.kind {
        case .image:
            configureImagePlaceholder()
            let label = entry.fileURL.pathExtension.lowercased() == "gif"
                ? L10n.historyPanelFilterGIF
                : L10n.historyPanelFilterScreenshots
            metaLabel.stringValue = Self.metadata(label: label, date: entry.createdAt)
        case .video:
            configureVideoPlaceholder()
            previewLoadState = .idle
        }
        needsLayout = true
    }

    func prepareForCollectionReuse() {
        cancelPendingPreviewLoad()
        setHovered(false)
    }

    func loadPreviewIfNeeded() {
        guard previewLoadState == .idle else { return }
        if applyCachedPreviewIfAvailable() {
            return
        }
        previewLoadState = .loading
        previewLoadGeneration += 1
        loadEntryPreview(generation: previewLoadGeneration)
    }

    func cancelPendingPreviewLoad() {
        guard previewLoadState == .loading else { return }
        previewLoadGeneration += 1
        previewRequest?.cancel()
        previewRequest = nil
        previewLoadState = .idle
    }

    private func applyCachedPreviewIfAvailable() -> Bool {
        let pixelSize = presentation.previewPixelSize
        switch entry.kind {
        case .image:
            guard let preview = HistoryImagePreviewLoader.shared.cachedPreview(
                url: entry.fileURL,
                pixelSize: pixelSize
            ) else { return false }
            configureImagePreview(preview)
            return true
        case .video:
            guard let preview = HistoryImagePreviewLoader.shared.cachedVideoFrame(
                url: entry.fileURL,
                pixelSize: pixelSize
            ) else { return false }
            configureVideoPreview(preview)
            return true
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        mouseDownHitSelectionBadge = selectionBadgeHitTest(mouseDownPoint ?? .zero)
        didStartDrag = false
        didDismissForCurrentDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didStartDrag, let mouseDownPoint else { return }
        guard !mouseDownHitSelectionBadge else { return }
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - mouseDownPoint.x
        let dy = point.y - mouseDownPoint.y
        guard hypot(dx, dy) > 4 else { return }
        didStartDrag = true
        let draggableEntries = dragEntriesProvider?(self) ?? [entry]
        guard !draggableEntries.isEmpty else { return }

        let draggingImage = imageView.image
            ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            ?? NSImage(size: imageView.bounds.size)
        let dragImage = draggableEntries.count > 1
            ? Self.multiDragImage(base: draggingImage, count: draggableEntries.count)
            : draggingImage
        let dragFrame = draggingFrame(for: dragImage)
        let items = draggableEntries.enumerated().map { index, entry in
            let item = NSDraggingItem(pasteboardWriter: entry.fileURL as NSURL)
            let offset = CGFloat(min(index, 2)) * 4
            item.setDraggingFrame(dragFrame.offsetBy(dx: offset, dy: offset), contents: dragImage)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }

    private func draggingFrame(for image: NSImage) -> NSRect {
        let imageSize = image.size
        let bounds = imageView.bounds
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return imageView.frame
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fittedSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let fittedRect = NSRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
        return imageView.convert(fittedRect, to: self)
    }

    private static func multiDragImage(base: NSImage, count: Int) -> NSImage {
        let baseSize = base.size.width > 0 && base.size.height > 0
            ? base.size
            : NSSize(width: 120, height: 80)
        let shadowOffset: CGFloat = 6
        let size = NSSize(width: baseSize.width + shadowOffset * 2, height: baseSize.height + shadowOffset * 2)
        let image = NSImage(size: size)
        image.lockFocus()

        for index in 0..<3 {
            let offset = CGFloat(2 - index) * 3
            let rect = NSRect(
                x: shadowOffset - offset,
                y: shadowOffset - offset,
                width: baseSize.width,
                height: baseSize.height
            )
            NSColor.black.withAlphaComponent(index == 2 ? 0.18 : 0.30).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        }

        let contentRect = NSRect(
            x: shadowOffset,
            y: shadowOffset,
            width: baseSize.width,
            height: baseSize.height
        )
        base.draw(in: contentRect, from: .zero, operation: .sourceOver, fraction: 1)

        let badgeSize: CGFloat = 28
        let badgeRect = NSRect(
            x: size.width - badgeSize - 2,
            y: size.height - badgeSize - 2,
            width: badgeSize,
            height: badgeSize
        )
        accentGreen.withAlphaComponent(0.96).setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
        NSColor.white.withAlphaComponent(0.86).setStroke()
        NSBezierPath(ovalIn: badgeRect.insetBy(dx: 0.75, dy: 0.75)).stroke()

        let text = "\(count)" as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: badgeRect.midX - textSize.width / 2,
                y: badgeRect.midY - textSize.height / 2
            ),
            withAttributes: attributes
        )

        image.unlockFocus()
        return image
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            didStartDrag = false
            mouseDownHitSelectionBadge = false
            mouseDownPoint = nil
        }
        guard !didStartDrag else { return }
        let point = convert(event.locationInWindow, from: nil)
        if mouseDownHitSelectionBadge, selectionBadgeHitTest(point) {
            onSelectionToggle?(self, event)
            return
        }
        if let onPrimaryClick {
            onPrimaryClick(self, event)
        } else if HistoryPanelEntryActions.copy(entry) {
            onRequestDismiss?()
        }
    }

    private func selectionBadgeHitTest(_ point: NSPoint) -> Bool {
        guard !selectionBadgeView.isHidden else { return false }
        return selectionBadgeView.frame.insetBy(dx: -7, dy: -7).contains(point)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        guard !didDismissForCurrentDrag else { return }
        guard let window, !window.frame.contains(screenPoint) else { return }
        didDismissForCurrentDrag = true
        DispatchQueue.main.async { [weak self] in
            self?.onRequestDismiss?()
        }
    }

    private func loadEntryPreview(generation: Int) {
        switch entry.kind {
        case .image:
            loadPreview(generation: generation)
        case .video:
            loadVideoPreview(generation: generation)
        }
    }

    private func loadPreview(generation: Int) {
        let pixelSize = presentation.previewPixelSize
        let url = entry.fileURL
        previewRequest?.cancel()
        previewRequest = HistoryImagePreviewLoader.shared.load(url: url, pixelSize: pixelSize) { [weak self] preview in
            guard let self,
                  self.previewLoadGeneration == generation,
                  self.previewLoadState == .loading,
                  self.entry.fileURL == url else { return }
            self.configureImagePreview(preview)
        }
    }

    private func loadVideoPreview(generation: Int) {
        configureVideoPlaceholder()
        let pixelSize = presentation.previewPixelSize
        let url = entry.fileURL
        previewRequest?.cancel()
        previewRequest = HistoryImagePreviewLoader.shared.loadVideoFrame(url: url, pixelSize: pixelSize) { [weak self] preview in
            guard let self,
                  self.previewLoadGeneration == generation,
                  self.previewLoadState == .loading,
                  self.entry.fileURL == url else { return }
            self.configureVideoPreview(preview)
        }
    }

    private func configureImagePlaceholder() {
        let config = NSImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        imageView.image = image
        imageView.contentTintColor = .tertiaryLabelColor
        updateTileAppearance()
    }

    private func configureImagePreview(_ preview: HistoryImagePreview) {
        previewRequest = nil
        previewLoadState = .loaded
        if let cgImage = preview.cgImage {
            imageView.image = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
            imageView.contentTintColor = nil
            imageView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        metaLabel.stringValue = HistoryImagePreview.metadata(
            pixelWidth: preview.pixelWidth,
            pixelHeight: preview.pixelHeight,
            date: entry.createdAt
        )
    }

    private func configureVideoPreview(_ preview: HistoryImagePreview) {
        previewRequest = nil
        previewLoadState = .loaded
        if let cgImage = preview.cgImage {
            imageView.image = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
            imageView.contentTintColor = nil
            imageView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        if preview.pixelWidth > 0, preview.pixelHeight > 0 {
            metaLabel.stringValue = HistoryImagePreview.metadata(
                pixelWidth: preview.pixelWidth,
                pixelHeight: preview.pixelHeight,
                date: entry.createdAt
            )
        }
    }

    private func configureVideoPlaceholder() {
        let config = NSImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        let image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: L10n.historyPanelFilterMP4)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        imageView.image = image
        imageView.contentTintColor = .secondaryLabelColor
        updateTileAppearance()
        metaLabel.stringValue = Self.metadata(label: L10n.historyPanelFilterMP4, date: entry.createdAt)
    }

    private static func metadata(label: String, date: Date) -> String {
        "\(label)  ·  \(dateFormatter.string(from: date))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MdHm")
        return formatter
    }()
}

private final class HistoryPreviewPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let commandModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(commandModifiers)
        if modifiers == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown?(event) == true {
            return
        }
        super.sendEvent(event)
    }
}

private final class HistoryPreviewContentView: NSView {
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
        let background = AdaptiveChrome.resolvedColor(
            AdaptiveChrome.panelBackground,
            for: effectiveAppearance
        )
        layer?.backgroundColor = background.cgColor
        window?.backgroundColor = background
    }
}

private final class HistoryPreviewActionButton: NSButton {
    var hoverTip = ""

    init(image: NSImage, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.image = image
        self.target = target
        self.action = action
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class HistoryPreviewTooltipPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class HistoryPreviewTooltipController {
    private weak var parentWindow: NSWindow?
    private let panel: HistoryPreviewTooltipPanel
    private let label = NSTextField(labelWithString: "")

    init() {
        panel = HistoryPreviewTooltipPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let content = FloatingGlassView(cornerRadius: 12, fallbackMaterial: .toolTip)
        panel.contentView = content

        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.usesSingleLineMode = true
        label.lineBreakMode = .byClipping
        content.content.addSubview(label)
    }

    func show(_ text: String, relativeTo anchorView: NSView) {
        guard !text.isEmpty,
              let parentWindow = anchorView.window,
              let screen = parentWindow.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            hide()
            return
        }

        if self.parentWindow !== parentWindow {
            if let previousParent = self.parentWindow {
                previousParent.removeChildWindow(panel)
            }
            self.parentWindow = parentWindow
            parentWindow.addChildWindow(panel, ordered: .above)
        }
        label.stringValue = text
        let textSize = label.intrinsicContentSize
        let glyphSize = text.size(withAttributes: [
            .font: label.font ?? NSFont.systemFont(ofSize: 12, weight: .medium)
        ])
        // Leave room for text-field insets and the trailing glyph's edge,
        // including fallback glyphs in mixed Chinese/Latin shortcut labels.
        let labelSize = NSSize(
            width: ceil(max(textSize.width, glyphSize.width)) + 4,
            height: ceil(max(textSize.height, glyphSize.height))
        )
        let panelSize = NSSize(
            width: labelSize.width + 20,
            height: labelSize.height + 10
        )

        let anchorRect = parentWindow.convertToScreen(anchorView.convert(anchorView.bounds, to: nil))
        let visibleFrame = screen.visibleFrame
        var origin = NSPoint(
            x: anchorRect.midX - panelSize.width / 2,
            y: anchorRect.minY - panelSize.height - 6
        )
        origin.x = min(
            max(origin.x, visibleFrame.minX + 8),
            visibleFrame.maxX - panelSize.width - 8
        )
        if origin.y < visibleFrame.minY + 8 {
            origin.y = anchorRect.maxY + 6
        }

        panel.level = NSWindow.Level(rawValue: parentWindow.level.rawValue + 1)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        label.frame = NSRect(origin: NSPoint(x: 10, y: 5), size: labelSize)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
        if let parentWindow {
            parentWindow.removeChildWindow(panel)
        }
        parentWindow = nil
    }

    func close() {
        hide()
    }
}

private final class HistoryPreviewWindowController: NSWindowController, NSWindowDelegate {
    private let entries: [HistoryEntry]
    private let onEdit: (HistoryEntry) -> Void
    private let contentKind: HistoryEntryKind
    private let imageView = NSImageView()
    private let videoView = AVPlayerView()
    private let textView = NSTextView()
    private let titlebarFilenameContainer = NSView()
    private let titlebarFilenameLabel = NSTextField(labelWithString: "")
    private let titlebarPositionLabel = NSTextField(labelWithString: "")
    private let titlebarActionStack = NSStackView()
    private let tooltipController = HistoryPreviewTooltipController()
    private var ocrButton: HistoryPreviewActionButton?
    private var ocrPreviewView: OCRPreviewView?
    private var ocrTask: Task<Void, Never>?
    private weak var hoveredActionButton: HistoryPreviewActionButton?
    private var actionButtons: [HistoryPreviewActionButton] = []
    private var actionHoverTimer: Timer?
    private var previewKeyMonitor: Any?
    private var videoPlayer: AVPlayer?
    private var currentIndex: Int
    private var loadGeneration = 0
    private var windowSizingTask: Task<Void, Never>?
    private var placementScreen: NSScreen?
    var onClose: (() -> Void)?

    init(entries: [HistoryEntry], initialEntry: HistoryEntry, onEdit: @escaping (HistoryEntry) -> Void) {
        self.entries = entries
        self.onEdit = onEdit
        contentKind = initialEntry.kind
        currentIndex = entries.firstIndex(where: {
            $0.fileURL.standardizedFileURL == initialEntry.fileURL.standardizedFileURL
        }) ?? 0

        let panel = HistoryPreviewPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = AdaptiveChrome.panelBackground

        super.init(window: panel)
        panel.delegate = self
        panel.onKeyDown = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }
        setupContent(in: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(relativeTo screen: NSScreen?) {
        guard let window else { return }
        placementScreen = screen ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
        updateWindowFrame(for: currentEntry, on: placementScreen, animated: false)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        switch contentKind {
        case .image:
            window.makeFirstResponder(imageView)
        case .video:
            window.makeFirstResponder(videoView)
        }
        startPreviewKeyMonitoring()
        startActionHoverTracking()
        loadCurrentContent()
    }

    override func close() {
        resetTextRecognition()
        windowSizingTask?.cancel()
        windowSizingTask = nil
        stopVideoPlayback()
        stopPreviewKeyMonitoring()
        stopActionHoverTracking()
        tooltipController.close()
        (window as? HistoryPreviewPanel)?.onKeyDown = nil
        super.close()
    }

    func windowWillClose(_ notification: Notification) {
        resetTextRecognition()
        windowSizingTask?.cancel()
        windowSizingTask = nil
        stopVideoPlayback()
        stopPreviewKeyMonitoring()
        stopActionHoverTracking()
        tooltipController.close()
        (window as? HistoryPreviewPanel)?.onKeyDown = nil
        onClose?()
    }

    private func setupContent(in panel: NSPanel) {
        let content = HistoryPreviewContentView(frame: panel.contentView?.bounds ?? .zero)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.isEditable = false
        imageView.frame = content.bounds
        imageView.autoresizingMask = [.width, .height]
        content.addSubview(imageView)

        videoView.controlsStyle = .floating
        videoView.videoGravity = .resizeAspect
        videoView.frame = content.bounds
        videoView.autoresizingMask = [.width, .height]
        videoView.isHidden = true
        content.addSubview(videoView)

        titlebarFilenameLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titlebarFilenameLabel.textColor = NSColor.labelColor
        titlebarFilenameLabel.lineBreakMode = .byTruncatingTail
        titlebarFilenameLabel.maximumNumberOfLines = 1
        titlebarFilenameLabel.frame = titlebarFilenameContainer.bounds
        titlebarFilenameLabel.autoresizingMask = [.width, .height]
        titlebarFilenameContainer.addSubview(titlebarFilenameLabel)

        let filenameAccessory = NSTitlebarAccessoryViewController()
        filenameAccessory.layoutAttribute = .left
        filenameAccessory.view = titlebarFilenameContainer
        panel.addTitlebarAccessoryViewController(filenameAccessory)

        let stack = titlebarActionStack
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 2, bottom: 0, right: 8)

        titlebarPositionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        titlebarPositionLabel.textColor = NSColor.secondaryLabelColor
        titlebarPositionLabel.alignment = .center
        titlebarPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        titlebarPositionLabel.widthAnchor.constraint(equalToConstant: 38).isActive = true
        stack.addArrangedSubview(titlebarPositionLabel)

        let actions: [(String, String, String, Selector)]
        switch contentKind {
        case .image:
            actions = [
                ("pencil", L10n.historyPanelShortcutEditImage, "E", #selector(editCurrent)),
                (ToolbarItemID.ocr.symbolName, L10n.tipOCR, "O", #selector(recognizeCurrent)),
                ("doc.on.doc", L10n.tipConfirm, "C", #selector(copyCurrent)),
                ("pin", L10n.tipPin, "P", #selector(pinCurrent)),
            ]
        case .video:
            actions = [
                ("doc.on.doc", L10n.tipConfirm, "C", #selector(copyCurrent)),
            ]
        }
        for action in actions {
            let tooltip = Self.shortcutTooltip(action.1, key: action.2)
            let symbol = action.3 == #selector(recognizeCurrent)
                ? ToolbarItemID.ocr.iconImage(pointSize: 13) ?? NSImage()
                : NSImage(systemSymbolName: action.0, accessibilityDescription: action.1)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
                ?? NSImage()
            let button = HistoryPreviewActionButton(image: symbol, target: self, action: action.3)
            button.bezelStyle = .toolbar
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.contentTintColor = .secondaryLabelColor
            button.hoverTip = tooltip
            button.setAccessibilityLabel(action.1)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            stack.addArrangedSubview(button)
            actionButtons.append(button)
            if action.3 == #selector(recognizeCurrent) {
                ocrButton = button
                button.isEnabled = false
            }
        }
        updateTitlebarActionStackSize()

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        accessory.view = stack
        panel.addTitlebarAccessoryViewController(accessory)
        updateTitlebarFilenameLayout()
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let blockingModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard window?.attachedSheet == nil, NSApp.modalWindow == nil else { return false }
        if let ocrPreviewView, blockingModifiers == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a":
                return ocrPreviewView.selectAllOverlayText() || ocrPreviewView.selectAllLiveText()
            case "c":
                return copyRecognizedSelection()
            default:
                break
            }
        }
        guard blockingModifiers.isEmpty else { return false }
        switch Int(event.keyCode) {
        case kVK_LeftArrow:
            move(by: -1)
        case kVK_RightArrow:
            move(by: 1)
        case kVK_Escape, kVK_Space:
            close()
        case kVK_ANSI_E:
            guard contentKind == .image else { return false }
            editCurrent()
        case kVK_ANSI_P:
            guard contentKind == .image else { return false }
            pinCurrent()
        case kVK_ANSI_O:
            guard contentKind == .image else { return false }
            recognizeCurrent()
        case kVK_ANSI_C:
            copyCurrent()
        default:
            return false
        }
        return true
    }

    private func move(by offset: Int) {
        guard entries.count > 1 else { return }
        currentIndex = (currentIndex + offset + entries.count) % entries.count
        updateWindowFrame(for: currentEntry, on: placementScreen, animated: true)
        loadCurrentContent()
    }

    private func loadCurrentContent() {
        resetTextRecognition()
        loadGeneration += 1
        let generation = loadGeneration
        titlebarPositionLabel.stringValue = "\(currentIndex + 1) / \(entries.count)"
        switch currentEntry.kind {
        case .image:
            loadCurrentImage(generation: generation)
        case .video:
            loadCurrentVideo()
        }
        updateTitlebarActionStackSize()
        updateTitlebarFilenameLayout()
    }

    private func loadCurrentImage(generation: Int) {
        let url = currentEntry.fileURL
        stopVideoPlayback()
        videoView.isHidden = true
        imageView.isHidden = false
        imageView.image = nil
        ocrButton?.isEnabled = false
        window?.title = url.lastPathComponent
        titlebarFilenameLabel.stringValue = url.lastPathComponent
        titlebarFilenameLabel.toolTip = url.lastPathComponent
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                guard let self, self.loadGeneration == generation else { return }
                self.imageView.image = image
                self.imageView.animates = url.pathExtension.lowercased() == "gif"
                self.ocrButton?.isEnabled = image != nil
            }
        }
    }

    private func loadCurrentVideo() {
        let url = currentEntry.fileURL
        stopVideoPlayback()
        imageView.image = nil
        imageView.isHidden = true
        videoView.isHidden = false
        window?.title = url.lastPathComponent
        titlebarFilenameLabel.stringValue = url.lastPathComponent
        titlebarFilenameLabel.toolTip = url.lastPathComponent

        let player = AVPlayer(url: url)
        videoPlayer = player
        videoView.player = player
        player.play()
    }

    private func stopVideoPlayback() {
        videoPlayer?.pause()
        videoView.player = nil
        videoPlayer = nil
    }

    private func updateWindowFrame(
        for entry: HistoryEntry,
        on screen: NSScreen?,
        animated: Bool
    ) {
        windowSizingTask?.cancel()
        windowSizingTask = nil
        guard let window,
              let targetScreen = screen ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        if case .video = entry.kind {
            let url = entry.fileURL
            let expectedIndex = currentIndex
            windowSizingTask = Task { @MainActor [weak self] in
                guard let pixelSize = try? await VideoAssetMetadata.pixelSize(for: url),
                      !Task.isCancelled,
                      let self,
                      self.currentIndex == expectedIndex else { return }
                self.applyWindowFrame(pixelSize: pixelSize, on: targetScreen, animated: animated)
            }
            return
        }

        let pixelSize = Self.imagePixelSize(for: entry)
        guard pixelSize.width > 0, pixelSize.height > 0 else { return }

        applyWindowFrame(pixelSize: pixelSize, on: targetScreen, animated: animated)
    }

    private func applyWindowFrame(pixelSize: NSSize, on targetScreen: NSScreen, animated: Bool) {
        guard let window else { return }
        let visibleFrame = targetScreen.visibleFrame
        let titlebarHeight = max(0, window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 100, height: 100)).height - 100)
        let horizontalMargin = max(64, floor(visibleFrame.width * 0.08))
        let verticalMargin: CGFloat = 32
        let safeFrame = visibleFrame.insetBy(dx: horizontalMargin, dy: verticalMargin)
        guard safeFrame.width > 0, safeFrame.height > titlebarHeight else { return }

        let maxContentRect = window.contentRect(
            forFrameRect: NSRect(origin: .zero, size: safeFrame.size)
        )
        let fitScale = min(
            maxContentRect.width / pixelSize.width,
            maxContentRect.height / pixelSize.height
        )
        let scale = min(1, fitScale)
        let imageSize = NSSize(
            width: max(1, floor(pixelSize.width * scale)),
            height: max(1, floor(pixelSize.height * scale))
        )
        let minimumContentSize = NSSize(width: 360, height: 220)
        let contentSize = NSSize(
            width: min(maxContentRect.width, max(minimumContentSize.width, imageSize.width)),
            height: min(maxContentRect.height, max(minimumContentSize.height, imageSize.height))
        )
        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        let origin = NSPoint(
            x: safeFrame.midX - frameSize.width / 2,
            y: safeFrame.midY - frameSize.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: frameSize), display: true, animate: animated)
    }

    private static func imagePixelSize(for entry: HistoryEntry) -> NSSize {
        let url = entry.fileURL
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return NSImage(contentsOf: url)?.size ?? .zero
        }
        return NSSize(width: width.doubleValue, height: height.doubleValue)
    }

    private var currentEntry: HistoryEntry { entries[currentIndex] }

    private static func shortcutTooltip(_ title: String, key: String) -> String {
        "\(title) (\(key))"
    }

    private func startPreviewKeyMonitoring() {
        guard previewKeyMonitor == nil else { return }
        previewKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func stopPreviewKeyMonitoring() {
        if let previewKeyMonitor {
            NSEvent.removeMonitor(previewKeyMonitor)
            self.previewKeyMonitor = nil
        }
    }

    private func startActionHoverTracking() {
        guard actionHoverTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.refreshActionHoverState()
        }
        RunLoop.main.add(timer, forMode: .common)
        actionHoverTimer = timer
        refreshActionHoverState()
    }

    private func stopActionHoverTracking() {
        actionHoverTimer?.invalidate()
        actionHoverTimer = nil
        hoveredActionButton = nil
    }

    private func refreshActionHoverState() {
        guard let window, window.isVisible else {
            if hoveredActionButton != nil {
                hoveredActionButton = nil
                tooltipController.hide()
            }
            return
        }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let hoveredButton = actionButtons.first { button in
            guard !button.isHidden, button.window === window else { return false }
            return button.bounds.contains(button.convert(windowPoint, from: nil))
        }
        guard hoveredActionButton !== hoveredButton else { return }

        hoveredActionButton = hoveredButton
        if let hoveredButton {
            tooltipController.show(hoveredButton.hoverTip, relativeTo: hoveredButton)
        } else {
            tooltipController.hide()
        }
    }

    func windowDidResize(_ notification: Notification) {
        tooltipController.hide()
        hoveredActionButton = nil
        updateTitlebarFilenameLayout()
    }

    func windowDidMove(_ notification: Notification) {
        tooltipController.hide()
        hoveredActionButton = nil
    }

    private func updateTitlebarFilenameLayout() {
        guard let window else { return }
        let trafficLightReserve: CGFloat = 148
        let accessoryGap: CGFloat = 20
        let availableWidth = window.frame.width
            - trafficLightReserve
            - titlebarActionStack.frame.width
            - accessoryGap
        let width = min(280, max(0, floor(availableWidth)))
        titlebarFilenameContainer.isHidden = width < 48
        titlebarFilenameContainer.frame = NSRect(
            origin: .zero,
            size: NSSize(width: width, height: 24)
        )

    }

    private func updateTitlebarActionStackSize() {
        titlebarActionStack.layoutSubtreeIfNeeded()
        let fittingSize = titlebarActionStack.fittingSize
        titlebarActionStack.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: ceil(fittingSize.width),
                height: max(24, ceil(fittingSize.height))
            )
        )
    }

    @objc private func editCurrent() {
        let entry = currentEntry
        close()
        onEdit(entry)
    }

    @objc private func pinCurrent() {
        guard let image = NSImage(contentsOf: currentEntry.fileURL) else { return }
        close()
        PinLauncher.pin(image: image, saveToHistory: false)
    }

    @objc private func recognizeCurrent() {
        guard contentKind == .image, ocrTask == nil else { return }
        if ocrPreviewView != nil {
            resetTextRecognition()
            return
        }
        guard let image = imageView.image else { return }
        let generation = loadGeneration
        imageView.animates = false
        updateOCRButton(isRecognizing: true)
        ocrTask = Task { @MainActor [weak self] in
            let result: OCRResult
            do {
                result = try await OCRService.recognizeResult(image: image)
            } catch {
                guard !Task.isCancelled, let self, self.loadGeneration == generation else { return }
                self.ocrTask = nil
                self.imageView.animates = self.currentEntry.fileURL.pathExtension.lowercased() == "gif"
                self.updateOCRButton(isRecognizing: false)
                ToastWindow.show(message: error.localizedDescription)
                return
            }
            let lines = result.lines
            guard !Task.isCancelled else { return }
            // Match the existing OCR panel: use geometric text selection first,
            // with native Live Text as the fallback when no lines are found.
            let analysis = result.provider == .apple && lines.isEmpty ? await OCRService.analyzeText(image: image) : nil
            guard !Task.isCancelled, let self, self.loadGeneration == generation else { return }
            self.ocrTask = nil
            if lines.isEmpty, !result.text.isEmpty, analysis == nil,
               let window = self.window, let screen = window.screen ?? NSScreen.main {
                self.imageView.animates = self.currentEntry.fileURL.pathExtension.lowercased() == "gif"
                self.updateOCRButton(isRecognizing: false)
                OCRTranslatePanel.presentTextRecognition(image: image, anchorRect: window.frame,
                                                         screen: screen, initialResult: result)
                return
            }
            guard !lines.isEmpty || analysis != nil,
                  let content = self.window?.contentView else {
                self.imageView.animates = self.currentEntry.fileURL.pathExtension.lowercased() == "gif"
                self.updateOCRButton(isRecognizing: false)
                ToastWindow.show(message: L10n.ocrNoText)
                return
            }
            let preview = OCRPreviewView(image: image, showsChrome: false)
            preview.translatesAutoresizingMaskIntoConstraints = true
            preview.frame = content.bounds
            preview.autoresizingMask = [.width, .height]
            preview.showsLineBoxes = true
            preview.lines = lines
            preview.applyLiveTextAnalysis(analysis)
            preview.onSelectText = { [weak self] _, lineIndices, isFinal in
                guard isFinal else { return }
                self?.copyRecognizedSelection(lineCount: lineIndices.count)
            }
            content.addSubview(preview)
            self.ocrPreviewView = preview
            self.imageView.isHidden = true
            self.window?.makeFirstResponder(preview)
            self.updateOCRButton(isRecognizing: false)
        }
    }

    private func resetTextRecognition() {
        ocrTask?.cancel()
        ocrTask = nil
        if let ocrPreviewView {
            ocrPreviewView.removeFromSuperview()
            self.ocrPreviewView = nil
            imageView.isHidden = false
            window?.makeFirstResponder(imageView)
        }
        if contentKind == .image {
            imageView.animates = currentEntry.fileURL.pathExtension.lowercased() == "gif"
        }
        updateOCRButton(isRecognizing: false)
    }

    private func updateOCRButton(isRecognizing: Bool) {
        guard let ocrButton else { return }
        ocrButton.image = isRecognizing
            ? NSImage(systemSymbolName: "hourglass", accessibilityDescription: L10n.ocrRecognizing)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
            : ToolbarItemID.ocr.iconImage(pointSize: 13)
        ocrButton.isEnabled = !isRecognizing && imageView.image != nil
        ocrButton.contentTintColor = ocrPreviewView != nil ? .systemGreen : .secondaryLabelColor
        ocrButton.hoverTip = isRecognizing
            ? L10n.ocrRecognizing
            : Self.shortcutTooltip(L10n.tipOCR, key: "O")
        ocrButton.setAccessibilityLabel(isRecognizing ? L10n.ocrRecognizing : L10n.tipOCR)
        if hoveredActionButton === ocrButton {
            tooltipController.show(ocrButton.hoverTip, relativeTo: ocrButton)
        }
    }

    @discardableResult
    private func copyRecognizedSelection(lineCount: Int? = nil) -> Bool {
        guard let ocrPreviewView,
              ocrPreviewView.copySelectedOverlayTextToClipboard()
                || ocrPreviewView.copySelectedLiveTextToClipboard() else { return false }
        ToastWindow.show(
            message: lineCount == 1 ? L10n.ocrLineCopied : L10n.ocrCopied,
            duration: 0.9
        )
        return true
    }

    @objc private func copyCurrent() {
        if copyRecognizedSelection() { return }
        guard HistoryPanelEntryActions.copy(currentEntry) else { return }
        close()
    }

}

private enum HistoryPanelEntryActions {
    static func copy(_ entry: HistoryEntry) -> Bool {
        switch entry.kind {
        case .image:
            guard let image = NSImage(contentsOf: entry.fileURL) else { return false }
            ClipboardManager.copyToClipboard(image: image)
            if Defaults.showCopyToast {
                ToastWindow.show()
            }
            return recordSuccessfulCopy(of: entry)
        case .video:
            guard ClipboardManager.copyFileURLsToClipboard([entry.fileURL]) else { return false }
            if Defaults.showCopyToast {
                ToastWindow.show(message: L10n.copiedToClipboard)
            }
            return recordSuccessfulCopy(of: entry)
        }
    }

    static func copyImages(_ entries: [HistoryEntry]) -> Bool {
        let imageURLs = entries.compactMap { entry -> NSURL? in
            guard case .image = entry.kind else { return nil }
            return entry.fileURL as NSURL
        }
        guard !imageURLs.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects(imageURLs) else { return false }
        ToastWindow.show(message: L10n.copiedToClipboard)
        if entries.count == 1, let entry = entries.first {
            HistoryManager.shared.promoteCopiedEntryIfNeeded(entry)
        }
        return true
    }

    private static func recordSuccessfulCopy(of entry: HistoryEntry) -> Bool {
        HistoryManager.shared.promoteCopiedEntryIfNeeded(entry)
        return true
    }
}

private extension NSScreen {
    static func screenForMouseLocation() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
    }
}
