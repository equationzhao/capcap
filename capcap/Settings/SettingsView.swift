import AppKit
import Carbon
import PermissionFlow

// MARK: - Tab model

enum SettingsTab: CaseIterable {
    case general
    case shortcuts
    case toolbar
    case capture
    case recording
    case history
    case files
    case ocr
    case translation
    case permissions
    case about

    var title: String {
        switch self {
        case .general: return L10n.settingsTabGeneral
        case .shortcuts: return L10n.settingsTabShortcuts
        case .capture: return L10n.settingsGeneralCapture
        case .recording: return L10n.settingsGeneralRecording
        case .history: return L10n.settingsGeneralHistory
        case .files: return L10n.settingsGeneralFiles
        case .toolbar: return L10n.settingsTabToolbar
        case .ocr: return L10n.settingsTabOCR
        case .translation: return L10n.settingsTabTranslation
        case .permissions: return L10n.settingsTabPermissions
        case .about: return L10n.settingsTabAbout
        }
    }

    var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .shortcuts: return "keyboard"
        case .capture: return "crop"
        case .recording: return "record.circle"
        case .history: return "clock"
        case .files: return "doc"
        case .toolbar: return "slider.horizontal.3"
        case .ocr: return "text.viewfinder"
        case .translation: return "translate"
        case .permissions: return "lock.shield.fill"
        case .about: return "info.circle.fill"
        }
    }
}

private enum HistoryPanelSettingsMode {
    case dialog
    case notch
}

final class SettingsView: NSView, NSTableViewDataSource, NSTableViewDelegate {

    var isStartup: Bool = false
    var onMenuBarToggle: ((Bool) -> Void)?
    var onLaunch: (() -> Void)?

    // Switches
    private var menuBarSwitch: NSSwitch!
    private var launchAtLoginSwitch: NSSwitch!
    private var pinAcrossSpacesSwitch: NSSwitch!

    // Picker & slider
    private var langPicker: NSPopUpButton!
    private var historyCacheSwitch: NSSwitch!

    private var historyCacheSlider: NSSlider!
    private var historyCacheValueLabel: NSTextField!
    private var historyPanelModePreview: HistoryPanelModePreviewView!
    private var historyPanelDialogOption: HistoryPanelModeOptionView!
    private var historyPanelNotchOption: HistoryPanelModeOptionView!
    private var historyNotchTriggerLabel: NSTextField?
    private var historyNotchTriggerPopup: NSPopUpButton?
    private var countdownSlider: NSSlider!
    private var countdownValueLabel: NSTextField!
    private var countdownTitleLabel: NSTextField!
    private var countdownHintLabel: NSTextField!

    // Window-capture shadow card
    private var windowShadowSwitch: NSSwitch!
    private var windowShadowSlider: NSSlider!
    private var windowShadowSizeValueLabel: NSTextField!
    private var windowShadowPreview: ShadowPreviewView!
    private var windowShadowTitleLabel: NSTextField!
    private var windowShadowSubtitleLabel: NSTextField?
    private var windowShadowSizeTitleLabel: NSTextField!
    private var windowShadowSizeHintLabel: NSTextField!

    // Screenshot shortcut card
    private var shortcutTitleLabel: NSTextField!
    private var shortcutField: NSTextField!
    private var shortcutSetButton: NSButton!
    private var shortcutRestoreButton: NSButton!
    private var shortcutRecordingMonitor: Any?

    // Full-screen screenshot shortcut card
    private var fullScreenScreenshotShortcutTitleLabel: NSTextField!
    private var fullScreenScreenshotShortcutField: NSTextField!
    private var fullScreenScreenshotShortcutSetButton: NSButton!
    private var fullScreenScreenshotShortcutRestoreButton: NSButton!
    private var fullScreenScreenshotShortcutRecordingMonitor: Any?

    // Quick Pin shortcut card
    private var quickPinShortcutTitleLabel: NSTextField!
    private var quickPinShortcutField: NSTextField!
    private var quickPinShortcutSetButton: NSButton!
    private var quickPinShortcutRestoreButton: NSButton!
    private var quickPinShortcutRecordingMonitor: Any?

    // Pin selected image shortcut card
    private var selectedImagePinShortcutTitleLabel: NSTextField!
    private var selectedImagePinShortcutField: NSTextField!
    private var selectedImagePinShortcutSetButton: NSButton!
    private var selectedImagePinShortcutRestoreButton: NSButton!
    private var selectedImagePinShortcutRecordingMonitor: Any?

    // Pin clipboard image shortcut card
    private var clipboardImagePinShortcutTitleLabel: NSTextField!
    private var clipboardImagePinShortcutField: NSTextField!
    private var clipboardImagePinShortcutSetButton: NSButton!
    private var clipboardImagePinShortcutRestoreButton: NSButton!
    private var clipboardImagePinShortcutRecordingMonitor: Any?

    // Pin clipboard text shortcut card
    private var clipboardTextPinShortcutTitleLabel: NSTextField!
    private var clipboardTextPinShortcutField: NSTextField!
    private var clipboardTextPinShortcutSetButton: NSButton!
    private var clipboardTextPinShortcutRestoreButton: NSButton!
    private var clipboardTextPinShortcutRecordingMonitor: Any?

    // Edit selected image shortcut card
    private var selectedImageEditShortcutTitleLabel: NSTextField!
    private var selectedImageEditShortcutField: NSTextField!
    private var selectedImageEditShortcutSetButton: NSButton!
    private var selectedImageEditShortcutRestoreButton: NSButton!
    private var selectedImageEditShortcutRecordingMonitor: Any?

    // Edit clipboard image shortcut card
    private var clipboardImageEditShortcutTitleLabel: NSTextField!
    private var clipboardImageEditShortcutField: NSTextField!
    private var clipboardImageEditShortcutSetButton: NSButton!
    private var clipboardImageEditShortcutRestoreButton: NSButton!
    private var clipboardImageEditShortcutRecordingMonitor: Any?

    // Text recognition shortcut card
    private var textRecognitionShortcutTitleLabel: NSTextField!
    private var textRecognitionShortcutField: NSTextField!
    private var textRecognitionShortcutSetButton: NSButton!
    private var textRecognitionShortcutRestoreButton: NSButton!
    private var textRecognitionShortcutRecordingMonitor: Any?

    // Copy image text shortcut card
    private var copyImageTextShortcutTitleLabel: NSTextField!
    private var copyImageTextShortcutField: NSTextField!
    private var copyImageTextShortcutSetButton: NSButton!
    private var copyImageTextShortcutRestoreButton: NSButton!
    private var copyImageTextShortcutRecordingMonitor: Any?

    // Screenshot translation shortcut card
    private var screenshotTranslationShortcutTitleLabel: NSTextField!
    private var screenshotTranslationShortcutField: NSTextField!
    private var screenshotTranslationShortcutSetButton: NSButton!
    private var screenshotTranslationShortcutRestoreButton: NSButton!
    private var screenshotTranslationShortcutRecordingMonitor: Any?

    // Recording shortcut card
    private var recordShortcutTitleLabel: NSTextField!
    private var recordShortcutField: NSTextField!
    private var recordShortcutSetButton: NSButton!
    private var recordShortcutRestoreButton: NSButton!
    private var recordShortcutRecordingMonitor: Any?

    // Copy-to-clipboard (editor confirm) shortcut card
    private var clipboardShortcutTitleLabel: NSTextField!
    private var clipboardShortcutField: NSTextField!
    private var clipboardShortcutSetButton: NSButton!
    private var clipboardShortcutRestoreButton: NSButton!
    private var clipboardShortcutRecordingMonitor: Any?

    // Save-to-file shortcut card (default ⌘S)
    private var fileSaveShortcutTitleLabel: NSTextField!
    private var fileSaveShortcutField: NSTextField!
    private var fileSaveShortcutSetButton: NSButton!
    private var fileSaveShortcutRestoreButton: NSButton!
    private var fileSaveShortcutRecordingMonitor: Any?

    // History navigation shortcut cards
    private var previousHistoryImageShortcutTitleLabel: NSTextField!
    private var previousHistoryImageShortcutField: NSTextField!
    private var previousHistoryImageShortcutSetButton: NSButton!
    private var previousHistoryImageShortcutRestoreButton: NSButton!
    private var previousHistoryImageShortcutRecordingMonitor: Any?

    private var nextHistoryImageShortcutTitleLabel: NSTextField!
    private var nextHistoryImageShortcutField: NSTextField!
    private var nextHistoryImageShortcutSetButton: NSButton!
    private var nextHistoryImageShortcutRestoreButton: NSButton!
    private var nextHistoryImageShortcutRecordingMonitor: Any?

    private var historyPanelShortcutTitleLabel: NSTextField!
    private var historyPanelShortcutField: NSTextField!
    private var historyPanelShortcutSetButton: NSButton!
    private var historyPanelShortcutRestoreButton: NSButton!
    private var historyPanelShortcutRecordingMonitor: Any?

    private var shortcutResetButton: NSButton?

    // Permission badges
    private var accessibilityBadge: StatusBadge!
    private var screenRecordingBadge: StatusBadge!
    private var microphoneBadge: StatusBadge?

    // Sidebar bottom action — Launch App in startup mode, Quit App otherwise.
    private let launchButton = NSButton()
    private let navigation = NSTableView()
    private var isUpdatingNavigationSelection = false

    // Labels (kept for language switching)
    private var menuBarTitleLabel: NSTextField!
    private var launchAtLoginTitleLabel: NSTextField!
    private var pinAcrossSpacesTitleLabel: NSTextField!
    private var pinAcrossSpacesSubtitleLabel: NSTextField!
    private var showCopyToastTitleLabel: NSTextField!
    private var showCopyToastSubtitleLabel: NSTextField!
    private var showCopyToastSwitch: NSSwitch!
    private var langTitleLabel: NSTextField!
    private var historyCacheToggleTitleLabel: NSTextField!
    private var historyCacheToggleHintLabel: NSTextField?
    private var historyCacheTitleLabel: NSTextField!
    private var historyPanelDisplayModeTitleLabel: NSTextField!
    private var historyPanelDisplayModeHintLabel: NSTextField!
    private var historyPanelDialogModeTitleLabel: NSTextField!
    private var historyPanelDialogModeHintLabel: NSTextField?
    private var historyPanelNotchModeTitleLabel: NSTextField!
    private var historyPanelNotchModeHintLabel: NSTextField?
    private var permHeaderSubtitleLabel: NSTextField?
    private var accessibilityNameLabel: NSTextField!
    private var accessibilityDescLabel: NSTextField!
    private var screenRecordingNameLabel: NSTextField!
    private var screenRecordingDescLabel: NSTextField!
    private var microphoneNameLabel: NSTextField?
    private var microphoneDescLabel: NSTextField?
    private var aboutTaglineLabel: NSTextField?
    private var aboutLicenseTitleLabel: NSTextField?
    private var aboutSourceTitleLabel: NSTextField?
    private var aboutUpdateTitleLabel: NSTextField?
    private var aboutUpdateStatusLabel: NSTextField?
    private var aboutUpdateButton: NSButton?

    // Error log card (About pane) — expandable macOS crash report viewer.
    private var errorLogTitleLabel: NSTextField?
    private var errorLogStatusLabel: NSTextField?
    private var errorLogChevron: NSImageView?
    private var errorLogContentContainer: NSView?
    private var errorLogHeightConstraint: NSLayoutConstraint?
    private var errorLogTextView: NSTextView?
    private var errorLogCopyButton: NSButton?
    private var errorLogRevealButton: NSButton?
    private var errorLogRefreshButton: NSButton?
    private var errorLogClearButton: NSButton?
    private var errorLogEntry: CrashLogReader.Entry?
    private var errorLogExpanded = false
    private var errorLogLoaded = false

    // Sidebar / detail chrome
    private var selectedTab: SettingsTab = .general
    private var detailTitleLabel: NSTextField!
    private var detailScrollView: NSScrollView!
    private var historyNotchTriggerRow: NSView?

    private var paneContainer: NSView!
    private var paneViews: [SettingsTab: NSView] = [:]
    private var toolbarPane: ToolbarSettingsPane?
    private var filenameRuleCard: FilenameRuleCard?
    private var screenshotQualityTitleLabel: NSTextField!
    private var screenshotQualitySubtitleLabel: NSTextField!
    private var screenshotQualitySaveTitleLabel: NSTextField!
    private var screenshotQualitySaveHintLabel: NSTextField!
    private var screenshotQualitySavePopup: NSPopUpButton!
    private var screenshotQualityClipboardTitleLabel: NSTextField!
    private var screenshotQualityClipboardHintLabel: NSTextField!
    private var screenshotQualityClipboardPopup: NSPopUpButton!
    private var savePathTitleLabel: NSTextField!
    private var savePathSubtitleLabel: NSTextField!
    private var askSaveLocationTitleLabel: NSTextField!
    private var askSaveLocationHintLabel: NSTextField?
    private var askSaveLocationSwitch: NSSwitch!
    private var autoRevealSavedFilesTitleLabel: NSTextField!
    private var autoRevealSavedFilesHintLabel: NSTextField?
    private var autoRevealSavedFilesSwitch: NSSwitch!
    private var recordingSavePathTitleLabel: NSTextField!
    private var recordingSavePathValueLabel: NSTextField!
    private var recordingSavePathChooseButton: NSButton!
    private var recordingSavePathRevealButton: NSButton!
    private var recordingSaveFormatTitleLabel: NSTextField!
    private var recordingSaveFormatPopup: NSPopUpButton!
    private var recordingSystemAudioTitleLabel: NSTextField?
    private var recordingSystemAudioHintLabel: NSTextField?
    private var recordingSystemAudioSwitch: NSSwitch?
    private var recordingMicrophoneTitleLabel: NSTextField?
    private var recordingMicrophoneHintLabel: NSTextField?
    private var recordingMicrophoneSwitch: NSSwitch?
    private var recordingMicrophoneDeviceTitleLabel: NSTextField?
    private var recordingMicrophoneDevicePopup: NSPopUpButton?
    private var screenshotSavePathTitleLabel: NSTextField!
    private var screenshotSavePathValueLabel: NSTextField!
    private var screenshotSavePathChooseButton: NSButton!
    private var screenshotSavePathRevealButton: NSButton!

    private var refreshTimer: Timer?
    private lazy var permissionFlowController = PermissionFlow.makeController(
        configuration: PermissionFlowConfiguration(
            requiredAppURLs: [Bundle.main.bundleURL],
            localeIdentifier: Defaults.language.lprojName
        )
    )

    init(frame: NSRect, isStartup: Bool = false) {
        self.isStartup = isStartup
        super.init(frame: frame)
        setupUI()
        startRefreshTimer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLocalization),
            name: .languageDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshUpdateRow),
            name: .updateStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        refreshTimer?.invalidate()
        cancelShortcutRecording()
        cancelFullScreenScreenshotShortcutRecording()
        cancelQuickPinShortcutRecording()
        cancelSelectedImagePinShortcutRecording()
        cancelClipboardImagePinShortcutRecording()
        cancelClipboardTextPinShortcutRecording()
        cancelSelectedImageEditShortcutRecording()
        cancelClipboardImageEditShortcutRecording()
        cancelTextRecognitionShortcutRecording()
        cancelCopyImageTextShortcutRecording()
        cancelScreenshotTranslationShortcutRecording()
        cancelRecordShortcutRecording()
        cancelClipboardShortcutRecording()
        cancelFileSaveShortcutRecording()
        cancelPreviousHistoryImageShortcutRecording()
        cancelNextHistoryImageShortcutRecording()
        cancelHistoryPanelShortcutRecording()
        NotificationCenter.default.removeObserver(self)
    }

    override var acceptsFirstResponder: Bool { true }

    func makeContentViewController() -> NSSplitViewController {
        let sidebarController = NSViewController()
        sidebarController.view = buildSidebar()
        let detailController = NSViewController()
        detailController.view = self

        let sidebar = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebar.minimumThickness = 208
        sidebar.maximumThickness = 240
        sidebar.canCollapse = false

        let split = NSSplitViewController()
        split.splitView.isVertical = true
        split.addSplitViewItem(sidebar)
        split.addSplitViewItem(NSSplitViewItem(viewController: detailController))
        return split
    }

    private func setupUI() {
        buildDetailPanel()

        // Build all panes
        buildCapturePreferencePanes()
        paneViews[.shortcuts] = buildShortcutsPane()
        paneViews[.toolbar] = buildToolbarPane()
        paneViews[.translation] = buildTranslationPane()
        let ocrStack = paneStack()
        let ocrPane = OCRSettingsPane()
        ocrStack.addArrangedSubview(ocrPane)
        ocrPane.widthAnchor.constraint(equalTo: ocrStack.widthAnchor).isActive = true
        paneViews[.ocr] = wrapPane(ocrStack)
        paneViews[.permissions] = buildPermissionsPane()
        paneViews[.about] = buildAboutPane()

        // Default selection
        let initial: SettingsTab = isStartup ? .permissions : .general
        selectTab(initial)

        refreshPermissionStatus()
        refreshShortcutDisplay()
        refreshFullScreenScreenshotShortcutDisplay()
        refreshQuickPinShortcutDisplay()
        refreshSelectedImagePinShortcutDisplay()
        refreshClipboardImagePinShortcutDisplay()
        refreshClipboardTextPinShortcutDisplay()
        refreshSelectedImageEditShortcutDisplay()
        refreshClipboardImageEditShortcutDisplay()
        refreshTextRecognitionShortcutDisplay()
        refreshCopyImageTextShortcutDisplay()
        refreshScreenshotTranslationShortcutDisplay()
        refreshRecordShortcutDisplay()
        refreshClipboardShortcutDisplay()
        refreshFileSaveShortcutDisplay()
        refreshPreviousHistoryImageShortcutDisplay()
        refreshNextHistoryImageShortcutDisplay()
        refreshHistoryPanelShortcutDisplay()
    }

    // MARK: - Sidebar

    private func buildSidebar() -> NSView {
        let sidebar = NSView()
        let safeArea = sidebar.safeAreaLayoutGuide
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SettingsTab"))
        column.resizingMask = .autoresizingMask
        navigation.addTableColumn(column)
        navigation.style = .sourceList
        navigation.headerView = nil
        navigation.rowHeight = 30
        navigation.allowsEmptySelection = false
        navigation.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        isUpdatingNavigationSelection = true
        navigation.delegate = self
        navigation.dataSource = self
        isUpdatingNavigationSelection = false
        navigation.setAccessibilityLabel(L10n.settingsTitle)
        scroll.documentView = navigation
        sidebar.addSubview(scroll)

        launchButton.bezelStyle = .rounded
        launchButton.controlSize = .large
        launchButton.imagePosition = .imageLeading
        launchButton.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        launchButton.target = self
        launchButton.action = #selector(launchClicked)
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(launchButton)
        refreshBottomAction()

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: launchButton.topAnchor, constant: -12),
            launchButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            launchButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            launchButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16),
        ])
        refreshNavigationSelection(scrollToSelection: true)
        return sidebar
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        SettingsTab.allCases.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SettingsSidebarCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
            ?? makeSidebarCell(identifier: identifier)
        let tab = SettingsTab.allCases[row]
        cell.textField?.stringValue = tab.title
        cell.imageView?.image = NSImage(systemSymbolName: tab.iconName, accessibilityDescription: nil)
        return cell
    }

    private func makeSidebarCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyDown
        icon.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        icon.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)
        cell.addSubview(label)
        cell.imageView = icon
        cell.textField = label
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isUpdatingNavigationSelection,
              SettingsTab.allCases.indices.contains(navigation.selectedRow)
        else { return }
        selectTab(SettingsTab.allCases[navigation.selectedRow], fromSidebar: true)
    }

    private func refreshNavigationSelection(scrollToSelection: Bool) {
        guard navigation.dataSource != nil,
              let row = SettingsTab.allCases.firstIndex(of: selectedTab)
        else { return }
        isUpdatingNavigationSelection = true
        navigation.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        if scrollToSelection {
            navigation.scrollRowToVisible(row)
        }
        isUpdatingNavigationSelection = false
    }

    private func appVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        return "v\(short)"
    }

    private func selectTab(_ tab: SettingsTab, fromSidebar: Bool = false) {
        if selectedTab == .toolbar && tab != .toolbar {
            toolbarPane?.cancelShortcutRecording()
        }
        if !fromSidebar {
            window?.makeFirstResponder(self)
        }
        selectedTab = tab
        refreshNavigationSelection(scrollToSelection: !fromSidebar)
        detailTitleLabel?.stringValue = tab.title

        // Rebuild the mic device list on every visit so hot-plugs appear.
        if tab == .recording {
            refreshMicrophoneDevicePopup()
        }

        // Swap pane content
        guard let pane = paneViews[tab] else { return }
        for sub in paneContainer.subviews { sub.removeFromSuperview() }
        pane.translatesAutoresizingMaskIntoConstraints = false
        paneContainer.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.topAnchor.constraint(equalTo: paneContainer.topAnchor),
            pane.leadingAnchor.constraint(equalTo: paneContainer.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: paneContainer.trailingAnchor),
            pane.bottomAnchor.constraint(equalTo: paneContainer.bottomAnchor),
        ])
        if window != nil {
            layoutSubtreeIfNeeded()
        }
        detailScrollView.contentView.scroll(to: .zero)
        detailScrollView.reflectScrolledClipView(detailScrollView.contentView)
    }

    // MARK: - Detail panel

    private func buildDetailPanel() {
        let safeArea = safeAreaLayoutGuide

        let title = NSTextField(labelWithString: SettingsTab.general.title)
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)
        detailTitleLabel = title

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.verticalScrollElasticity = .allowed
        scroll.automaticallyAdjustsContentInsets = false
        addSubview(scroll)
        detailScrollView = scroll

        let container = FlippedView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = container
        paneContainer = container

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            container.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            container.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
    }

    // MARK: - Pane builders

    private func buildCapturePreferencePanes() {
        let basic = paneStack()
        let capture = paneStack()
        let recording = paneStack()
        let history = paneStack()
        let files = paneStack()

        let togglesCard = SettingsGroupView()
        let togglesInner = verticalInnerStack()
        togglesCard.content.addSubview(togglesInner)
        pin(togglesInner, to: togglesCard.content, insets: NSEdgeInsets(top: 14, left: 14, bottom: 6, right: 14))
        let langRow = NSStackView()
        langRow.orientation = .horizontal
        langRow.alignment = .centerY
        langRow.spacing = 10
        langRow.translatesAutoresizingMaskIntoConstraints = false

        langTitleLabel = primaryLabel(L10n.languageHeader)
        langRow.addArrangedSubview(langTitleLabel)
        langRow.addArrangedSubview(flexSpacer())

        langPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        langPicker.addItems(withTitles: AppLanguage.allCases.map { $0.displayName })
        langPicker.selectItem(at: AppLanguage.allCases.firstIndex(of: Defaults.language) ?? 0)
        langPicker.target = self
        langPicker.action = #selector(languageChanged(_:))
        langPicker.controlSize = .small
        langPicker.font = NSFont.systemFont(ofSize: 12)
        langRow.addArrangedSubview(langPicker)

        togglesInner.addArrangedSubview(langRow)
        langRow.widthAnchor.constraint(equalTo: togglesInner.widthAnchor).isActive = true
        togglesInner.setCustomSpacing(14, after: langRow)
        togglesInner.addArrangedSubview(rowDivider())
        let menuBar = makeToggleRow(
            title: L10n.showMenuBarIcon,
            subtitle: nil,
            isOn: Defaults.showMenuBar,
            action: #selector(menuBarSwitchToggled(_:))
        )
        menuBarTitleLabel = menuBar.title
        menuBarSwitch = menuBar.toggle
        togglesInner.addArrangedSubview(menuBar.row)
        menuBar.row.widthAnchor.constraint(equalTo: togglesInner.widthAnchor).isActive = true
        togglesInner.addArrangedSubview(rowDivider())

        let login = makeToggleRow(
            title: L10n.launchAtLogin,
            subtitle: nil,
            isOn: LaunchAtLogin.isEnabled,
            action: #selector(launchAtLoginToggled(_:))
        )
        launchAtLoginTitleLabel = login.title
        launchAtLoginSwitch = login.toggle
        togglesInner.addArrangedSubview(login.row)
        login.row.widthAnchor.constraint(equalTo: togglesInner.widthAnchor).isActive = true
        togglesInner.addArrangedSubview(rowDivider())

        let copyToast = makeToggleRow(
            title: L10n.showCopyToast,
            subtitle: L10n.showCopyToastHint,
            isOn: Defaults.showCopyToast,
            action: #selector(showCopyToastToggled(_:))
        )
        showCopyToastTitleLabel = copyToast.title
        showCopyToastSubtitleLabel = copyToast.subtitle
        showCopyToastSwitch = copyToast.toggle
        togglesInner.addArrangedSubview(copyToast.row)
        copyToast.row.widthAnchor.constraint(equalTo: togglesInner.widthAnchor).isActive = true

        basic.addArrangedSubview(togglesCard)
        togglesCard.widthAnchor.constraint(equalTo: basic.widthAnchor).isActive = true

        buildCountdownCard(into: capture)
        buildWindowShadowCard(into: capture)
        let pinCard = SettingsGroupView()
        let pinInner = verticalInnerStack()
        pinCard.content.addSubview(pinInner)
        pin(pinInner, to: pinCard.content, insets: NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14))
        let pinAcrossSpaces = makeToggleRow(
            title: L10n.pinAcrossSpaces,
            subtitle: L10n.pinAcrossSpacesHint,
            isOn: Defaults.pinAcrossSpaces,
            action: #selector(pinAcrossSpacesToggled(_:))
        )
        pinAcrossSpacesTitleLabel = pinAcrossSpaces.title
        pinAcrossSpacesSubtitleLabel = pinAcrossSpaces.subtitle
        pinAcrossSpacesSwitch = pinAcrossSpaces.toggle
        pinInner.addArrangedSubview(pinAcrossSpaces.row)
        pinAcrossSpaces.row.widthAnchor.constraint(equalTo: pinInner.widthAnchor).isActive = true

        capture.addArrangedSubview(pinCard)
        pinCard.widthAnchor.constraint(equalTo: capture.widthAnchor).isActive = true

        buildRecordingCard(into: recording)
        buildHistoryCards(into: history)
        buildSavePathCard(into: files)
        buildScreenshotQualityCard(into: files)
        let filenameCard = FilenameRuleCard()
        filenameRuleCard = filenameCard
        files.addArrangedSubview(filenameCard)
        filenameCard.widthAnchor.constraint(equalTo: files.widthAnchor).isActive = true

        paneViews[.general] = wrapPane(basic)
        paneViews[.capture] = wrapPane(capture)
        paneViews[.recording] = wrapPane(recording)
        paneViews[.history] = wrapPane(history)
        paneViews[.files] = wrapPane(files)
    }

    /// Window-capture shadow card: a toggle for the rounded-corner + drop
    /// shadow effect, a size slider, and a live preview of the result.
    private func buildWindowShadowCard(into stack: NSStackView) {
        let card = SettingsGroupView()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.content.addSubview(inner)
        pin(inner, to: card.content, insets: NSEdgeInsets(top: 4, left: 14, bottom: 14, right: 14))

        // Enable toggle
        let toggle = makeToggleRow(
            title: L10n.windowShadowToggleLabel,
            subtitle: L10n.windowShadowToggleHint,
            isOn: Defaults.windowShadowEnabled,
            action: #selector(windowShadowToggled(_:))
        )
        windowShadowTitleLabel = toggle.title
        windowShadowSubtitleLabel = toggle.subtitle
        windowShadowSwitch = toggle.toggle
        inner.addArrangedSubview(toggle.row)
        toggle.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let divider = rowDivider()
        inner.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        // Size header — title + numeric value
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false

        windowShadowSizeTitleLabel = primaryLabel(L10n.shadowSizeLabel)
        header.addArrangedSubview(windowShadowSizeTitleLabel)
        header.addArrangedSubview(flexSpacer())

        windowShadowSizeValueLabel = NSTextField(labelWithString: "\(Int(Defaults.windowShadowSize.rounded()))")
        windowShadowSizeValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        windowShadowSizeValueLabel.textColor = .labelColor
        header.addArrangedSubview(windowShadowSizeValueLabel)

        inner.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        // Size slider
        let slider = NSSlider(
            value: Defaults.windowShadowSize,
            minValue: Defaults.windowShadowSizeMin,
            maxValue: Defaults.windowShadowSizeMax,
            target: self,
            action: #selector(windowShadowSizeChanged(_:))
        )
        slider.controlSize = .small
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        windowShadowSlider = slider
        inner.addArrangedSubview(slider)
        slider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        // Live preview
        let preview = ShadowPreviewView()
        preview.translatesAutoresizingMaskIntoConstraints = false
        preview.shadowSize = CGFloat(Defaults.windowShadowSize)
        windowShadowPreview = preview
        inner.addArrangedSubview(preview)
        preview.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 120).isActive = true

        windowShadowSizeHintLabel = secondaryLabel(L10n.windowShadowSizeHint, wrapping: true)
        inner.addArrangedSubview(windowShadowSizeHintLabel)
        windowShadowSizeHintLabel.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        updateWindowShadowControlsEnabled()

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    /// Dim and disable the size controls when the shadow toggle is off.
    private func updateWindowShadowControlsEnabled() {
        let on = Defaults.windowShadowEnabled
        windowShadowSlider?.isEnabled = on
        windowShadowSizeTitleLabel?.textColor = on ? .labelColor : .tertiaryLabelColor
        windowShadowSizeValueLabel?.textColor = on ? .labelColor : .tertiaryLabelColor
        windowShadowPreview?.isEffectEnabled = on
    }

    private func updateHistoryCacheControlsEnabled() {
        let mediaOn = Defaults.historyCacheEnabled
        historyCacheSlider?.isEnabled = mediaOn
        historyCacheTitleLabel?.textColor = mediaOn ? .labelColor : .tertiaryLabelColor
        historyCacheValueLabel?.textColor = mediaOn ? .labelColor : .tertiaryLabelColor
    }

    private func updateHistoryPanelModeControlsEnabled() {
        let on = Defaults.isHistoryCacheAvailable
        let notchAvailable = Defaults.historyPanelNotchAvailable
        let dialogEnabled = on
        let notchEnabled = on && notchAvailable
        let mode = selectedHistoryPanelMode()
        historyPanelModePreview?.mode = mode
        historyPanelModePreview?.isEffectEnabled = on
        historyPanelDialogOption?.isEnabled = dialogEnabled
        historyPanelNotchOption?.isEnabled = notchEnabled
        historyPanelDialogOption?.isSelected = mode == .dialog
        historyPanelNotchOption?.isSelected = mode == .notch
        let triggerEnabled = notchEnabled && mode == .notch
        historyNotchTriggerPopup?.isEnabled = triggerEnabled
        historyNotchTriggerPopup?.selectItem(at: Defaults.HistoryNotchTriggerMode.allCases.firstIndex(of: Defaults.historyNotchTriggerMode) ?? 0)
        historyNotchTriggerRow?.isHidden = mode != .notch
        historyNotchTriggerLabel?.textColor = triggerEnabled ? .labelColor : .tertiaryLabelColor

        historyPanelDisplayModeTitleLabel?.textColor = on ? .labelColor : .tertiaryLabelColor
        historyPanelDisplayModeHintLabel?.textColor = on ? .secondaryLabelColor : .tertiaryLabelColor
        historyPanelDialogModeTitleLabel?.textColor = dialogEnabled ? .labelColor : .tertiaryLabelColor
        historyPanelDialogModeHintLabel?.textColor = dialogEnabled ? .secondaryLabelColor : .tertiaryLabelColor
        historyPanelNotchModeTitleLabel?.textColor = notchEnabled ? .labelColor : .tertiaryLabelColor
        historyPanelNotchModeHintLabel?.textColor = notchEnabled ? .secondaryLabelColor : .tertiaryLabelColor
    }

    private func selectedHistoryPanelMode() -> HistoryPanelSettingsMode {
        Defaults.historyPanelNotchEnabled ? .notch : .dialog
    }

    private func refreshSavePathControls() {
        recordingSavePathValueLabel?.stringValue = SaveDestination.displayPath(Defaults.recordingSaveDirectory)
        screenshotSavePathValueLabel?.stringValue = SaveDestination.displayPath(Defaults.screenshotSaveDirectory)
        recordingSavePathValueLabel?.toolTip = Defaults.recordingSaveDirectory.path
        screenshotSavePathValueLabel?.toolTip = Defaults.screenshotSaveDirectory.path
        refreshRecordingSaveFormatPopup()
    }

    private func refreshScreenshotQualityControls() {
        refreshScreenshotQualityPopup(screenshotQualitySavePopup, selected: Defaults.screenshotSaveQuality)
        refreshScreenshotQualityPopup(screenshotQualityClipboardPopup, selected: Defaults.screenshotClipboardQuality)
        screenshotQualitySaveHintLabel?.stringValue = Defaults.screenshotSaveQuality.localizedHint
        screenshotQualitySavePopup?.toolTip = Defaults.screenshotSaveQuality.localizedHint
        screenshotQualityClipboardHintLabel?.stringValue = Defaults.screenshotClipboardQuality.localizedHint
        screenshotQualityClipboardPopup?.toolTip = Defaults.screenshotClipboardQuality.localizedHint
    }

    private func refreshScreenshotQualityPopup(
        _ popup: NSPopUpButton?,
        selected: ScreenshotImageQuality
    ) {
        guard let popup else { return }
        popup.removeAllItems()
        for quality in ScreenshotImageQuality.allCases {
            popup.addItem(withTitle: quality.localizedTitle)
            popup.lastItem?.representedObject = quality.rawValue
        }
        if let index = ScreenshotImageQuality.allCases.firstIndex(of: selected) {
            popup.selectItem(at: index)
        }
    }

    private func refreshRecordingSaveFormatPopup() {
        guard let popup = recordingSaveFormatPopup else { return }
        let selected = Defaults.recordingSavePreference
        popup.removeAllItems()
        for preference in RecordingSavePreference.allCases {
            popup.addItem(withTitle: preference.displayName)
            popup.lastItem?.representedObject = preference.rawValue
        }
        if let index = RecordingSavePreference.allCases.firstIndex(of: selected) {
            popup.selectItem(at: index)
        }
    }

    /// Rebuild the mic device popup from the live CoreAudio list; falls back
    /// to "System Default" when the persisted UID is unplugged.
    private func refreshMicrophoneDevicePopup() {
        guard let popup = recordingMicrophoneDevicePopup else { return }
        let selectedUID = Defaults.recordingMicrophoneDeviceUID
        popup.removeAllItems()
        popup.addItem(withTitle: L10n.recordingMicrophoneDeviceDefault)
        popup.lastItem?.representedObject = nil
        for device in AudioInputDevices.available() {
            popup.addItem(withTitle: device.name)
            popup.lastItem?.representedObject = device.uid
        }
        if let selectedUID,
           let index = (0..<popup.numberOfItems).first(where: {
               popup.item(at: $0)?.representedObject as? String == selectedUID
           }) {
            popup.selectItem(at: index)
        } else {
            popup.selectItem(at: 0)
        }
    }

    private func updateMicrophoneControlsEnabled() {
        let enabled = Defaults.recordingMicrophoneEnabled
        recordingMicrophoneDevicePopup?.isEnabled = enabled
        recordingMicrophoneDeviceTitleLabel?.textColor = enabled ? .labelColor : .tertiaryLabelColor
    }

    @objc private func recordingMicrophoneDeviceChanged(_ sender: NSPopUpButton) {
        Defaults.recordingMicrophoneDeviceUID = sender.selectedItem?.representedObject as? String
    }

    private func buildShortcutsPane() -> NSView {
        let stack = paneStack()

        // Screenshot shortcut card
        let shortcut = buildShortcutCard(
            title: L10n.shortcutHeader,
            setAction: #selector(shortcutSetClicked),
            restoreAction: #selector(shortcutRestoreClicked)
        )
        shortcutTitleLabel = shortcut.title
        shortcutField = shortcut.field
        shortcutSetButton = shortcut.setButton
        shortcutRestoreButton = shortcut.restoreButton
        stack.addArrangedSubview(shortcut.card)
        shortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Copy-to-clipboard (editor confirm) shortcut card
        let clipboardShortcut = buildShortcutCard(
            title: L10n.clipboardShortcutHeader,
            setAction: #selector(clipboardShortcutSetClicked),
            restoreAction: #selector(clipboardShortcutRestoreClicked)
        )
        clipboardShortcutTitleLabel = clipboardShortcut.title
        clipboardShortcutField = clipboardShortcut.field
        clipboardShortcutSetButton = clipboardShortcut.setButton
        clipboardShortcutRestoreButton = clipboardShortcut.restoreButton
        stack.addArrangedSubview(clipboardShortcut.card)
        clipboardShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Save-to-file shortcut card (default ⌘S)
        let fileSaveShortcut = buildShortcutCard(
            title: L10n.fileSaveShortcutHeader,
            setAction: #selector(fileSaveShortcutSetClicked),
            restoreAction: #selector(fileSaveShortcutRestoreClicked)
        )
        fileSaveShortcutTitleLabel = fileSaveShortcut.title
        fileSaveShortcutField = fileSaveShortcut.field
        fileSaveShortcutSetButton = fileSaveShortcut.setButton
        fileSaveShortcutRestoreButton = fileSaveShortcut.restoreButton
        stack.addArrangedSubview(fileSaveShortcut.card)
        fileSaveShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let previousHistoryImageShortcut = buildShortcutCard(
            title: L10n.previousHistoryImageShortcutHeader,
            setAction: #selector(previousHistoryImageShortcutSetClicked),
            restoreAction: #selector(previousHistoryImageShortcutRestoreClicked)
        )
        previousHistoryImageShortcutTitleLabel = previousHistoryImageShortcut.title
        previousHistoryImageShortcutField = previousHistoryImageShortcut.field
        previousHistoryImageShortcutSetButton = previousHistoryImageShortcut.setButton
        previousHistoryImageShortcutRestoreButton = previousHistoryImageShortcut.restoreButton
        stack.addArrangedSubview(previousHistoryImageShortcut.card)
        previousHistoryImageShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let nextHistoryImageShortcut = buildShortcutCard(
            title: L10n.nextHistoryImageShortcutHeader,
            setAction: #selector(nextHistoryImageShortcutSetClicked),
            restoreAction: #selector(nextHistoryImageShortcutRestoreClicked)
        )
        nextHistoryImageShortcutTitleLabel = nextHistoryImageShortcut.title
        nextHistoryImageShortcutField = nextHistoryImageShortcut.field
        nextHistoryImageShortcutSetButton = nextHistoryImageShortcut.setButton
        nextHistoryImageShortcutRestoreButton = nextHistoryImageShortcut.restoreButton
        stack.addArrangedSubview(nextHistoryImageShortcut.card)
        nextHistoryImageShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let historyPanelShortcut = buildShortcutCard(
            title: L10n.historyPanelShortcutHeader,
            setAction: #selector(historyPanelShortcutSetClicked),
            restoreAction: #selector(historyPanelShortcutRestoreClicked)
        )
        historyPanelShortcutTitleLabel = historyPanelShortcut.title
        historyPanelShortcutField = historyPanelShortcut.field
        historyPanelShortcutSetButton = historyPanelShortcut.setButton
        historyPanelShortcutRestoreButton = historyPanelShortcut.restoreButton
        stack.addArrangedSubview(historyPanelShortcut.card)
        historyPanelShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Full-screen screenshot shortcut card
        let fullScreenScreenshotShortcut = buildShortcutCard(
            title: L10n.fullScreenScreenshotShortcutHeader,
            setAction: #selector(fullScreenScreenshotShortcutSetClicked),
            restoreAction: #selector(fullScreenScreenshotShortcutRestoreClicked)
        )
        fullScreenScreenshotShortcutTitleLabel = fullScreenScreenshotShortcut.title
        fullScreenScreenshotShortcutField = fullScreenScreenshotShortcut.field
        fullScreenScreenshotShortcutSetButton = fullScreenScreenshotShortcut.setButton
        fullScreenScreenshotShortcutRestoreButton = fullScreenScreenshotShortcut.restoreButton
        stack.addArrangedSubview(fullScreenScreenshotShortcut.card)
        fullScreenScreenshotShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Edit selected image shortcut card
        let selectedImageEditShortcut = buildShortcutCard(
            title: L10n.selectedImageEditShortcutHeader,
            setAction: #selector(selectedImageEditShortcutSetClicked),
            restoreAction: #selector(selectedImageEditShortcutRestoreClicked)
        )
        selectedImageEditShortcutTitleLabel = selectedImageEditShortcut.title
        selectedImageEditShortcutField = selectedImageEditShortcut.field
        selectedImageEditShortcutSetButton = selectedImageEditShortcut.setButton
        selectedImageEditShortcutRestoreButton = selectedImageEditShortcut.restoreButton
        stack.addArrangedSubview(selectedImageEditShortcut.card)
        selectedImageEditShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Edit clipboard image shortcut card
        let clipboardImageEditShortcut = buildShortcutCard(
            title: L10n.clipboardImageEditShortcutHeader,
            setAction: #selector(clipboardImageEditShortcutSetClicked),
            restoreAction: #selector(clipboardImageEditShortcutRestoreClicked)
        )
        clipboardImageEditShortcutTitleLabel = clipboardImageEditShortcut.title
        clipboardImageEditShortcutField = clipboardImageEditShortcut.field
        clipboardImageEditShortcutSetButton = clipboardImageEditShortcut.setButton
        clipboardImageEditShortcutRestoreButton = clipboardImageEditShortcut.restoreButton
        stack.addArrangedSubview(clipboardImageEditShortcut.card)
        clipboardImageEditShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Quick Pin shortcut card
        let quickPinShortcut = buildShortcutCard(
            title: L10n.quickPinShortcutHeader,
            setAction: #selector(quickPinShortcutSetClicked),
            restoreAction: #selector(quickPinShortcutRestoreClicked)
        )
        quickPinShortcutTitleLabel = quickPinShortcut.title
        quickPinShortcutField = quickPinShortcut.field
        quickPinShortcutSetButton = quickPinShortcut.setButton
        quickPinShortcutRestoreButton = quickPinShortcut.restoreButton
        quickPinShortcutRestoreButton.toolTip = L10n.quickPinShortcutClear
        stack.addArrangedSubview(quickPinShortcut.card)
        quickPinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin selected image shortcut card
        let selectedImagePinShortcut = buildShortcutCard(
            title: L10n.selectedImagePinShortcutHeader,
            setAction: #selector(selectedImagePinShortcutSetClicked),
            restoreAction: #selector(selectedImagePinShortcutRestoreClicked)
        )
        selectedImagePinShortcutTitleLabel = selectedImagePinShortcut.title
        selectedImagePinShortcutField = selectedImagePinShortcut.field
        selectedImagePinShortcutSetButton = selectedImagePinShortcut.setButton
        selectedImagePinShortcutRestoreButton = selectedImagePinShortcut.restoreButton
        selectedImagePinShortcutRestoreButton.toolTip = L10n.selectedImagePinShortcutClear
        stack.addArrangedSubview(selectedImagePinShortcut.card)
        selectedImagePinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin clipboard image shortcut card
        let clipboardImagePinShortcut = buildShortcutCard(
            title: L10n.clipboardImagePinShortcutHeader,
            setAction: #selector(clipboardImagePinShortcutSetClicked),
            restoreAction: #selector(clipboardImagePinShortcutRestoreClicked)
        )
        clipboardImagePinShortcutTitleLabel = clipboardImagePinShortcut.title
        clipboardImagePinShortcutField = clipboardImagePinShortcut.field
        clipboardImagePinShortcutSetButton = clipboardImagePinShortcut.setButton
        clipboardImagePinShortcutRestoreButton = clipboardImagePinShortcut.restoreButton
        clipboardImagePinShortcutRestoreButton.toolTip = L10n.clipboardImagePinShortcutClear
        stack.addArrangedSubview(clipboardImagePinShortcut.card)
        clipboardImagePinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Text recognition shortcut card
        let textRecognitionShortcut = buildShortcutCard(
            title: L10n.textRecognitionShortcutHeader,
            setAction: #selector(textRecognitionShortcutSetClicked),
            restoreAction: #selector(textRecognitionShortcutRestoreClicked)
        )
        textRecognitionShortcutTitleLabel = textRecognitionShortcut.title
        textRecognitionShortcutField = textRecognitionShortcut.field
        textRecognitionShortcutSetButton = textRecognitionShortcut.setButton
        textRecognitionShortcutRestoreButton = textRecognitionShortcut.restoreButton
        stack.addArrangedSubview(textRecognitionShortcut.card)
        textRecognitionShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Copy image text shortcut card
        let copyImageTextShortcut = buildShortcutCard(
            title: L10n.copyImageTextShortcutHeader,
            setAction: #selector(copyImageTextShortcutSetClicked),
            restoreAction: #selector(copyImageTextShortcutRestoreClicked)
        )
        copyImageTextShortcutTitleLabel = copyImageTextShortcut.title
        copyImageTextShortcutField = copyImageTextShortcut.field
        copyImageTextShortcutSetButton = copyImageTextShortcut.setButton
        copyImageTextShortcutRestoreButton = copyImageTextShortcut.restoreButton
        stack.addArrangedSubview(copyImageTextShortcut.card)
        copyImageTextShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Screenshot translation shortcut card
        let screenshotTranslationShortcut = buildShortcutCard(
            title: L10n.screenshotTranslationShortcutHeader,
            setAction: #selector(screenshotTranslationShortcutSetClicked),
            restoreAction: #selector(screenshotTranslationShortcutRestoreClicked)
        )
        screenshotTranslationShortcutTitleLabel = screenshotTranslationShortcut.title
        screenshotTranslationShortcutField = screenshotTranslationShortcut.field
        screenshotTranslationShortcutSetButton = screenshotTranslationShortcut.setButton
        screenshotTranslationShortcutRestoreButton = screenshotTranslationShortcut.restoreButton
        stack.addArrangedSubview(screenshotTranslationShortcut.card)
        screenshotTranslationShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Recording shortcut card
        let recordShortcut = buildShortcutCard(
            title: L10n.recordShortcutHeader,
            setAction: #selector(recordShortcutSetClicked),
            restoreAction: #selector(recordShortcutRestoreClicked)
        )
        recordShortcutTitleLabel = recordShortcut.title
        recordShortcutField = recordShortcut.field
        recordShortcutSetButton = recordShortcut.setButton
        recordShortcutRestoreButton = recordShortcut.restoreButton
        stack.addArrangedSubview(recordShortcut.card)
        recordShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Pin clipboard text shortcut card
        let clipboardTextPinShortcut = buildShortcutCard(
            title: L10n.clipboardTextPinShortcutHeader,
            setAction: #selector(clipboardTextPinShortcutSetClicked),
            restoreAction: #selector(clipboardTextPinShortcutRestoreClicked)
        )
        clipboardTextPinShortcutTitleLabel = clipboardTextPinShortcut.title
        clipboardTextPinShortcutField = clipboardTextPinShortcut.field
        clipboardTextPinShortcutSetButton = clipboardTextPinShortcut.setButton
        clipboardTextPinShortcutRestoreButton = clipboardTextPinShortcut.restoreButton
        clipboardTextPinShortcutRestoreButton.toolTip = L10n.clipboardTextPinShortcutClear
        stack.addArrangedSubview(clipboardTextPinShortcut.card)
        clipboardTextPinShortcut.card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 10
        footer.translatesAutoresizingMaskIntoConstraints = false

        let resetButton = NSButton(title: L10n.toolbarSettingsReset,
                                   target: self,
                                   action: #selector(shortcutsResetClicked))
        resetButton.bezelStyle = .rounded
        resetButton.controlSize = .large
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setContentHuggingPriority(.required, for: .horizontal)
        shortcutResetButton = resetButton

        footer.addArrangedSubview(flexSpacer())
        footer.addArrangedSubview(resetButton)
        stack.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return wrapPane(stack)
    }

    private func buildHistoryCards(into stack: NSStackView) {
        // History cache card
        let historyCard = SettingsGroupView()
        let historyInner = NSStackView()
        historyInner.orientation = .vertical
        historyInner.alignment = .leading
        historyInner.spacing = 10
        historyInner.translatesAutoresizingMaskIntoConstraints = false
        historyCard.content.addSubview(historyInner)
        pin(historyInner, to: historyCard.content, insets: NSEdgeInsets(top: 4, left: 14, bottom: 14, right: 14))

        let historyToggle = makeToggleRow(
            title: L10n.historyCacheToggleLabel,
            subtitle: L10n.historyCacheToggleHint,
            isOn: Defaults.historyCacheEnabled,
            action: #selector(historyCacheToggled(_:))
        )
        historyCacheToggleTitleLabel = historyToggle.title
        historyCacheToggleHintLabel = historyToggle.subtitle
        historyCacheSwitch = historyToggle.toggle
        historyInner.addArrangedSubview(historyToggle.row)
        historyToggle.row.widthAnchor.constraint(equalTo: historyInner.widthAnchor).isActive = true

        let historyHeader = NSStackView()
        historyHeader.orientation = .horizontal
        historyHeader.alignment = .firstBaseline
        historyHeader.spacing = 8
        historyHeader.translatesAutoresizingMaskIntoConstraints = false

        historyCacheTitleLabel = primaryLabel(L10n.historyCacheLabel)
        historyHeader.addArrangedSubview(historyCacheTitleLabel)
        historyHeader.addArrangedSubview(flexSpacer())

        historyCacheValueLabel = NSTextField(labelWithString: "\(Defaults.historyCacheLimit)")
        historyCacheValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        historyCacheValueLabel.textColor = .labelColor
        historyHeader.addArrangedSubview(historyCacheValueLabel)

        historyInner.addArrangedSubview(historyHeader)
        historyHeader.widthAnchor.constraint(equalTo: historyInner.widthAnchor).isActive = true

        let slider = NSSlider(
            value: Double(Defaults.historyCacheLimit),
            minValue: Double(Defaults.historyCacheMin),
            maxValue: Double(Defaults.historyCacheMax),
            target: self,
            action: #selector(historyCacheSliderChanged(_:))
        )
        slider.numberOfTickMarks = (Defaults.historyCacheMax - Defaults.historyCacheMin) / Defaults.historyCacheStep + 1
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        slider.setAccessibilityTitleUIElement(historyCacheTitleLabel)
        slider.translatesAutoresizingMaskIntoConstraints = false
        historyCacheSlider = slider
        historyInner.addArrangedSubview(slider)
        slider.widthAnchor.constraint(equalTo: historyInner.widthAnchor).isActive = true

        updateHistoryCacheControlsEnabled()

        stack.addArrangedSubview(historyCard)
        historyCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        buildHistoryPanelModeCard(into: stack)

    }

    private func buildCountdownCard(into stack: NSStackView) {
        // Countdown card
        let countdownCard = SettingsGroupView()
        let countdownInner = NSStackView()
        countdownInner.orientation = .vertical
        countdownInner.alignment = .leading
        countdownInner.spacing = 10
        countdownInner.translatesAutoresizingMaskIntoConstraints = false
        countdownCard.content.addSubview(countdownInner)
        pin(countdownInner, to: countdownCard.content, insets: NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))

        let countdownHeader = NSStackView()
        countdownHeader.orientation = .horizontal
        countdownHeader.alignment = .firstBaseline
        countdownHeader.spacing = 8
        countdownHeader.translatesAutoresizingMaskIntoConstraints = false

        countdownTitleLabel = primaryLabel(L10n.countdownLabel)
        countdownHeader.addArrangedSubview(countdownTitleLabel)
        countdownHeader.addArrangedSubview(flexSpacer())

        countdownValueLabel = NSTextField(labelWithString: "\(Defaults.countdownSeconds)\(L10n.countdownSecondsSuffix)")
        countdownValueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        countdownValueLabel.textColor = .labelColor
        countdownHeader.addArrangedSubview(countdownValueLabel)

        countdownInner.addArrangedSubview(countdownHeader)
        countdownHeader.widthAnchor.constraint(equalTo: countdownInner.widthAnchor).isActive = true

        let cdSlider = NSSlider(
            value: Double(Defaults.countdownSeconds),
            minValue: Double(Defaults.countdownSecondsMin),
            maxValue: Double(Defaults.countdownSecondsMax),
            target: self,
            action: #selector(countdownSliderChanged(_:))
        )
        cdSlider.numberOfTickMarks = Defaults.countdownSecondsMax - Defaults.countdownSecondsMin + 1
        cdSlider.allowsTickMarkValuesOnly = true
        cdSlider.isContinuous = true
        cdSlider.setAccessibilityTitleUIElement(countdownTitleLabel)
        cdSlider.translatesAutoresizingMaskIntoConstraints = false
        countdownSlider = cdSlider
        countdownInner.addArrangedSubview(cdSlider)
        cdSlider.widthAnchor.constraint(equalTo: countdownInner.widthAnchor).isActive = true

        countdownHintLabel = secondaryLabel(L10n.countdownHint, wrapping: true)
        countdownInner.addArrangedSubview(countdownHintLabel)
        countdownHintLabel.widthAnchor.constraint(equalTo: countdownInner.widthAnchor).isActive = true

        stack.addArrangedSubview(countdownCard)
        countdownCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func buildHistoryPanelModeCard(into stack: NSStackView) {
        let card = SettingsGroupView()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 14
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.content.addSubview(inner)
        pin(inner, to: card.content, insets: NSEdgeInsets(top: 14, left: 16, bottom: 16, right: 16))

        historyPanelDisplayModeTitleLabel = primaryLabel(L10n.historyPanelDisplayModeLabel)
        historyPanelDisplayModeHintLabel = secondaryLabel(L10n.historyPanelDisplayModeHint, wrapping: true)
        inner.addArrangedSubview(historyPanelDisplayModeTitleLabel)
        inner.addArrangedSubview(historyPanelDisplayModeHintLabel)
        historyPanelDisplayModeHintLabel.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let preview = HistoryPanelModePreviewView(mode: selectedHistoryPanelMode())
        preview.translatesAutoresizingMaskIntoConstraints = false
        historyPanelModePreview = preview
        inner.addArrangedSubview(preview)
        NSLayoutConstraint.activate([
            preview.widthAnchor.constraint(equalTo: inner.widthAnchor),
            preview.heightAnchor.constraint(equalToConstant: 136),
        ])

        let optionRow = NSStackView()
        optionRow.orientation = .horizontal
        optionRow.alignment = .top
        optionRow.distribution = .fillEqually
        optionRow.spacing = 12
        optionRow.translatesAutoresizingMaskIntoConstraints = false

        let dialog = HistoryPanelModeOptionView(
            mode: .dialog,
            title: L10n.historyPanelDialogMode,
            subtitle: L10n.historyPanelDialogModeHint
        )
        historyPanelDialogModeTitleLabel = dialog.title
        historyPanelDialogModeHintLabel = dialog.subtitle
        historyPanelDialogOption = dialog
        dialog.target = self
        dialog.action = #selector(historyPanelModeOptionClicked(_:))

        let notch = HistoryPanelModeOptionView(
            mode: .notch,
            title: L10n.historyPanelNotchMode,
            subtitle: L10n.historyPanelNotchModeHint
        )
        historyPanelNotchModeTitleLabel = notch.title
        historyPanelNotchModeHintLabel = notch.subtitle
        historyPanelNotchOption = notch
        notch.target = self
        notch.action = #selector(historyPanelModeOptionClicked(_:))

        optionRow.addArrangedSubview(dialog)
        optionRow.addArrangedSubview(notch)
        inner.addArrangedSubview(optionRow)
        optionRow.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let triggerRow = NSStackView()
        triggerRow.orientation = .horizontal
        triggerRow.alignment = .centerY
        triggerRow.spacing = 10
        historyNotchTriggerRow = triggerRow
        let triggerLabel = primaryLabel(L10n.historyNotchTriggerLabel)
        historyNotchTriggerLabel = triggerLabel
        triggerRow.addArrangedSubview(triggerLabel)
        triggerRow.addArrangedSubview(flexSpacer())
        let triggerPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        triggerPopup.controlSize = .small
        triggerPopup.font = NSFont.systemFont(ofSize: 12)
        triggerPopup.addItems(withTitles: Defaults.HistoryNotchTriggerMode.allCases.map { $0.localizedTitle })
        triggerPopup.setAccessibilityLabel(L10n.historyNotchTriggerLabel)
        triggerPopup.target = self
        triggerPopup.action = #selector(historyNotchTriggerChanged(_:))
        historyNotchTriggerPopup = triggerPopup
        triggerRow.addArrangedSubview(triggerPopup)
        inner.addArrangedSubview(triggerRow)
        triggerRow.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        updateHistoryPanelModeControlsEnabled()

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func buildScreenshotQualityCard(into stack: NSStackView) {
        let card = SettingsGroupView()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.content.addSubview(inner)
        pin(inner, to: card.content, insets: NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))

        let header = NSStackView()
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 3
        header.translatesAutoresizingMaskIntoConstraints = false

        screenshotQualityTitleLabel = primaryLabel(L10n.screenshotQualityTitle)
        screenshotQualitySubtitleLabel = secondaryLabel(L10n.screenshotQualitySubtitle, wrapping: true)
        header.addArrangedSubview(screenshotQualityTitleLabel)
        screenshotQualityTitleLabel.toolTip = L10n.screenshotQualitySubtitle
        inner.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let topDivider = rowDivider()
        inner.addArrangedSubview(topDivider)
        topDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let save = makeScreenshotQualityRow(
            title: L10n.screenshotQualitySaveLabel,
            quality: Defaults.screenshotSaveQuality,
            action: #selector(screenshotSaveQualityChanged(_:))
        )
        screenshotQualitySaveTitleLabel = save.title
        screenshotQualitySaveHintLabel = save.hint
        screenshotQualitySavePopup = save.popup
        inner.addArrangedSubview(save.row)
        save.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let saveDivider = rowDivider()
        inner.addArrangedSubview(saveDivider)
        saveDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let clipboard = makeScreenshotQualityRow(
            title: L10n.screenshotQualityClipboardLabel,
            quality: Defaults.screenshotClipboardQuality,
            action: #selector(screenshotClipboardQualityChanged(_:))
        )
        screenshotQualityClipboardTitleLabel = clipboard.title
        screenshotQualityClipboardHintLabel = clipboard.hint
        screenshotQualityClipboardPopup = clipboard.popup
        inner.addArrangedSubview(clipboard.row)
        clipboard.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        refreshScreenshotQualityControls()

        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func makeScreenshotQualityRow(
        title: String,
        quality: ScreenshotImageQuality,
        action: Selector
    ) -> (row: NSView, title: NSTextField, hint: NSTextField, popup: NSPopUpButton) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 3
        labelStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        let hintLabel = secondaryLabel(quality.localizedHint, wrapping: true)
        labelStack.addArrangedSubview(titleLabel)
        row.addArrangedSubview(labelStack)
        labelStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true

        row.addArrangedSubview(flexSpacer())

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.controlSize = .small
        popup.font = NSFont.systemFont(ofSize: 12)
        popup.target = self
        popup.action = action
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        row.addArrangedSubview(popup)

        return (row, titleLabel, hintLabel, popup)
    }

    private func buildSavePathCard(into stack: NSStackView) {
        let card = SettingsGroupView()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 10
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.content.addSubview(inner)
        pin(inner, to: card.content, insets: NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))

        let header = NSStackView()
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 3
        header.translatesAutoresizingMaskIntoConstraints = false

        savePathTitleLabel = primaryLabel(L10n.savePathTitle)
        savePathSubtitleLabel = secondaryLabel(L10n.savePathSubtitle, wrapping: true)
        header.addArrangedSubview(savePathTitleLabel)
        savePathTitleLabel.toolTip = L10n.savePathSubtitle
        inner.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let topDivider = rowDivider()
        inner.addArrangedSubview(topDivider)
        topDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let screenshotPath = makeSavePathRow(
            title: L10n.screenshotSavePathLabel,
            chooseAction: #selector(chooseScreenshotSavePathClicked),
            revealAction: #selector(revealScreenshotSavePathClicked)
        )
        screenshotSavePathTitleLabel = screenshotPath.title
        screenshotSavePathValueLabel = screenshotPath.value
        screenshotSavePathChooseButton = screenshotPath.chooseButton
        screenshotSavePathRevealButton = screenshotPath.revealButton
        inner.addArrangedSubview(screenshotPath.row)
        screenshotPath.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let pathDivider = rowDivider()
        inner.addArrangedSubview(pathDivider)
        pathDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let recordingPath = makeSavePathRow(
            title: L10n.recordingSavePathLabel,
            chooseAction: #selector(chooseRecordingSavePathClicked),
            revealAction: #selector(revealRecordingSavePathClicked)
        )
        recordingSavePathTitleLabel = recordingPath.title
        recordingSavePathValueLabel = recordingPath.value
        recordingSavePathChooseButton = recordingPath.chooseButton
        recordingSavePathRevealButton = recordingPath.revealButton
        inner.addArrangedSubview(recordingPath.row)
        recordingPath.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let behaviorDivider = rowDivider()
        inner.addArrangedSubview(behaviorDivider)
        behaviorDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let askSave = makeToggleRow(
            title: L10n.askSaveLocationLabel,
            subtitle: L10n.askSaveLocationHint,
            isOn: Defaults.askSaveLocation,
            action: #selector(askSaveLocationToggled(_:))
        )
        askSaveLocationTitleLabel = askSave.title
        askSaveLocationHintLabel = askSave.subtitle
        askSaveLocationSwitch = askSave.toggle
        askSave.subtitle?.isHidden = true
        askSave.title.toolTip = L10n.askSaveLocationHint
        askSave.toggle.toolTip = L10n.askSaveLocationHint
        inner.addArrangedSubview(askSave.row)
        askSave.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let askSaveDivider = rowDivider()
        inner.addArrangedSubview(askSaveDivider)
        askSaveDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let autoReveal = makeToggleRow(
            title: L10n.autoRevealSavedFilesLabel,
            subtitle: L10n.autoRevealSavedFilesHint,
            isOn: Defaults.autoRevealSavedFiles,
            action: #selector(autoRevealSavedFilesToggled(_:))
        )
        autoRevealSavedFilesTitleLabel = autoReveal.title
        autoRevealSavedFilesHintLabel = autoReveal.subtitle
        autoRevealSavedFilesSwitch = autoReveal.toggle
        autoReveal.subtitle?.isHidden = true
        autoReveal.title.toolTip = L10n.autoRevealSavedFilesHint
        autoReveal.toggle.toolTip = L10n.autoRevealSavedFilesHint
        inner.addArrangedSubview(autoReveal.row)
        autoReveal.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        refreshSavePathControls()
        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func buildRecordingCard(into stack: NSStackView) {
        let card = SettingsGroupView()
        let inner = paneStack()
        card.content.addSubview(inner)
        pin(inner, to: card.content, insets: NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        let formatRow = NSStackView()
        formatRow.orientation = .horizontal
        formatRow.alignment = .centerY
        formatRow.spacing = 10
        formatRow.translatesAutoresizingMaskIntoConstraints = false

        recordingSaveFormatTitleLabel = primaryLabel(L10n.recordingSaveFormatSettingLabel)
        formatRow.addArrangedSubview(recordingSaveFormatTitleLabel)
        formatRow.addArrangedSubview(flexSpacer())

        recordingSaveFormatPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        recordingSaveFormatPopup.controlSize = .small
        recordingSaveFormatPopup.font = NSFont.systemFont(ofSize: 12)
        recordingSaveFormatPopup.target = self
        recordingSaveFormatPopup.action = #selector(recordingSaveFormatPreferenceChanged(_:))
        recordingSaveFormatPopup.translatesAutoresizingMaskIntoConstraints = false
        recordingSaveFormatPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        formatRow.addArrangedSubview(recordingSaveFormatPopup)
        inner.addArrangedSubview(formatRow)
        formatRow.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let audioDivider = rowDivider()
        inner.addArrangedSubview(audioDivider)
        audioDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let systemAudioToggle = makeToggleRow(
            title: L10n.recordingSystemAudioLabel,
            subtitle: L10n.recordingSystemAudioHint,
            isOn: Defaults.recordingSystemAudioEnabled,
            action: #selector(recordingSystemAudioToggled(_:))
        )
        recordingSystemAudioTitleLabel = systemAudioToggle.title
        recordingSystemAudioHintLabel = systemAudioToggle.subtitle
        recordingSystemAudioSwitch = systemAudioToggle.toggle
        inner.addArrangedSubview(systemAudioToggle.row)
        systemAudioToggle.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let micDivider = rowDivider()
        inner.addArrangedSubview(micDivider)
        micDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let micToggle = makeToggleRow(
            title: L10n.recordingMicrophoneLabel,
            subtitle: L10n.recordingMicrophoneHint,
            isOn: Defaults.recordingMicrophoneEnabled,
            action: #selector(recordingMicrophoneToggled(_:))
        )
        recordingMicrophoneTitleLabel = micToggle.title
        recordingMicrophoneHintLabel = micToggle.subtitle
        recordingMicrophoneSwitch = micToggle.toggle
        inner.addArrangedSubview(micToggle.row)
        micToggle.row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let micDeviceDivider = rowDivider()
        inner.addArrangedSubview(micDeviceDivider)
        micDeviceDivider.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let micDeviceRow = NSStackView()
        micDeviceRow.orientation = .horizontal
        micDeviceRow.alignment = .centerY
        micDeviceRow.spacing = 10
        micDeviceRow.translatesAutoresizingMaskIntoConstraints = false

        recordingMicrophoneDeviceTitleLabel = primaryLabel(L10n.recordingMicrophoneDeviceLabel)
        micDeviceRow.addArrangedSubview(recordingMicrophoneDeviceTitleLabel!)
        micDeviceRow.addArrangedSubview(flexSpacer())

        recordingMicrophoneDevicePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        recordingMicrophoneDevicePopup?.controlSize = .small
        recordingMicrophoneDevicePopup?.font = NSFont.systemFont(ofSize: 12)
        recordingMicrophoneDevicePopup?.target = self
        recordingMicrophoneDevicePopup?.action = #selector(recordingMicrophoneDeviceChanged(_:))
        recordingMicrophoneDevicePopup?.translatesAutoresizingMaskIntoConstraints = false
        recordingMicrophoneDevicePopup?.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        micDeviceRow.addArrangedSubview(recordingMicrophoneDevicePopup!)
        inner.addArrangedSubview(micDeviceRow)
        micDeviceRow.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        refreshMicrophoneDevicePopup()

        refreshRecordingSaveFormatPopup()
        updateMicrophoneControlsEnabled()
        stack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func makeSavePathRow(
        title: String,
        chooseAction: Selector,
        revealAction: Selector
    ) -> (row: NSView, title: NSTextField, value: NSTextField, chooseButton: NSButton, revealButton: NSButton) {
        let row = NSStackView()
        row.orientation = .horizontal
        row.distribution = .fill
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let valueLabel = secondaryLabel("", wrapping: false)
        valueLabel.isSelectable = true
        valueLabel.lineBreakMode = .byTruncatingMiddle
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true

        let chooseButton = NSButton(title: L10n.savePathChoose, target: self, action: chooseAction)
        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .small
        chooseButton.font = NSFont.systemFont(ofSize: 11)
        chooseButton.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(chooseButton)

        let revealButton = NSButton(title: L10n.savePathReveal, target: self, action: revealAction)
        revealButton.bezelStyle = .rounded
        revealButton.controlSize = .small
        revealButton.font = NSFont.systemFont(ofSize: 11)
        revealButton.setContentHuggingPriority(.required, for: .horizontal)
        row.addArrangedSubview(revealButton)

        return (row, titleLabel, valueLabel, chooseButton, revealButton)
    }

    private func buildToolbarPane() -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        let pane = ToolbarSettingsPane()
        toolbarPane = pane
        host.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.topAnchor.constraint(equalTo: host.topAnchor),
            pane.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            pane.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        return host
    }

    func cancelToolbarShortcutRecording() {
        toolbarPane?.cancelShortcutRecording()
    }

    private func buildTranslationPane() -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        let pane = TranslationSettingsPane()
        host.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.topAnchor.constraint(equalTo: host.topAnchor),
            pane.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            pane.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        return host
    }

    private func buildPermissionsPane() -> NSView {
        let stack = paneStack()

        let permCard = SettingsGroupView()
        let permInner = verticalInnerStack()
        permCard.content.addSubview(permInner)
        pin(permInner, to: permCard.content, insets: NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))

        let acc = makePermissionRow(
            name: L10n.accessibilityPermission,
            description: L10n.accessibilityDescription,
            action: #selector(openAccessibilitySettings(_:))
        )
        accessibilityNameLabel = acc.name
        accessibilityDescLabel = acc.desc
        accessibilityBadge = acc.badge
        permInner.addArrangedSubview(acc.row)
        acc.row.widthAnchor.constraint(equalTo: permInner.widthAnchor).isActive = true
        permInner.addArrangedSubview(rowDivider())

        let sc = makePermissionRow(
            name: L10n.screenRecordingPermission,
            description: L10n.screenRecordingDescription,
            action: #selector(openScreenRecordingSettings(_:))
        )
        screenRecordingNameLabel = sc.name
        screenRecordingDescLabel = sc.desc
        screenRecordingBadge = sc.badge
        permInner.addArrangedSubview(sc.row)
        sc.row.widthAnchor.constraint(equalTo: permInner.widthAnchor).isActive = true

        let micDivider = rowDivider()
        permInner.addArrangedSubview(micDivider)
        micDivider.widthAnchor.constraint(equalTo: permInner.widthAnchor).isActive = true

        // Microphone is optional: the Launch button is not gated on it, but
        // the row lets users grant it from Settings directly.
        let mic = makePermissionRow(
            name: L10n.microphonePermission,
            description: L10n.microphoneDescription,
            action: #selector(openMicrophoneSettings(_:))
        )
        microphoneNameLabel = mic.name
        microphoneDescLabel = mic.desc
        microphoneBadge = mic.badge
        permInner.addArrangedSubview(mic.row)
        mic.row.widthAnchor.constraint(equalTo: permInner.widthAnchor).isActive = true

        stack.addArrangedSubview(permCard)
        permCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return wrapPane(stack)
    }

    private func buildAboutPane() -> NSView {
        let stack = paneStack()

        // Header card — app icon, name and version.
        let headerCard = SettingsGroupView()
        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 14
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerCard.content.addSubview(headerRow)
        pin(headerRow, to: headerCard.content, insets: NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 56).isActive = true
        headerRow.addArrangedSubview(iconView)

        let nameLabel = NSTextField(labelWithString: "capcap")
        nameLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        nameLabel.textColor = .labelColor

        let versionLabel = NSTextField(labelWithString: appVersionString())
        versionLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor

        let taglineLabel = secondaryLabel(L10n.aboutTagline, wrapping: true)
        aboutTaglineLabel = taglineLabel

        let textStack = NSStackView(views: [nameLabel, versionLabel, taglineLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addArrangedSubview(textStack)
        headerRow.addArrangedSubview(flexSpacer())

        stack.addArrangedSubview(headerCard)
        headerCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Info card — license + source link rows.
        let infoCard = SettingsGroupView()
        let infoInner = verticalInnerStack()
        infoCard.content.addSubview(infoInner)
        pin(infoInner, to: infoCard.content, insets: NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))

        let updateRow = makeUpdateRow()
        infoInner.addArrangedSubview(updateRow)
        updateRow.widthAnchor.constraint(equalTo: infoInner.widthAnchor).isActive = true
        infoInner.addArrangedSubview(rowDivider())

        let license = makeInfoRow(title: L10n.aboutLicense, value: "MIT")
        aboutLicenseTitleLabel = license.title
        infoInner.addArrangedSubview(license.row)
        license.row.widthAnchor.constraint(equalTo: infoInner.widthAnchor).isActive = true
        infoInner.addArrangedSubview(rowDivider())

        let repo = makeLinkRow(
            title: L10n.aboutSourceCode,
            value: "github.com/realskyrin/capcap",
            action: #selector(openSourceRepo)
        )
        aboutSourceTitleLabel = repo.title
        infoInner.addArrangedSubview(repo.row)
        repo.row.widthAnchor.constraint(equalTo: infoInner.widthAnchor).isActive = true
        stack.addArrangedSubview(infoCard)
        infoCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        // Error log card — collapsed by default, expands to show the most
        // recent crash report so users can copy it.
        let errorLogCard = buildErrorLogCard()
        stack.addArrangedSubview(errorLogCard)
        errorLogCard.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        return wrapPane(stack)
    }

    /// Builds the expandable "Error Log" card for the About pane. The header is
    /// a clickable row; tapping it animates the crash-log viewer open or shut.
    private func buildErrorLogCard() -> NSView {
        let card = SettingsGroupView()

        // Clickable header — toggles the expand / collapse animation.
        let header = HoverButton()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.target = self
        header.action = #selector(toggleErrorLog)
        header.title = ""
        header.isBordered = false
        header.cornerRadius = 0

        let titleLabel = primaryLabel(L10n.aboutErrorLog)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLogTitleLabel = titleLabel

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLogStatusLabel = statusLabel

        // The chevron lives inside a fixed-size Auto Layout container, while the
        // image view itself uses a static frame. This keeps Auto Layout from
        // resetting the image view's frame on each layout pass — which would
        // otherwise discard the pivot compensation `frameCenterRotation` needs
        // and make the chevron rotate around its corner instead of its center.
        let chevronBox = NSView()
        chevronBox.translatesAutoresizingMaskIntoConstraints = false
        chevronBox.setContentHuggingPriority(.required, for: .horizontal)

        let chevron = NSImageView(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevron.contentTintColor = .tertiaryLabelColor
        chevron.imageScaling = .scaleProportionallyUpOrDown
        chevron.wantsLayer = true
        chevron.autoresizingMask = []
        chevronBox.addSubview(chevron)
        errorLogChevron = chevron

        header.addSubview(titleLabel)
        header.addSubview(statusLabel)
        header.addSubview(chevronBox)
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 46),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            chevronBox.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -14),
            chevronBox.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            chevronBox.widthAnchor.constraint(equalToConstant: 12),
            chevronBox.heightAnchor.constraint(equalToConstant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: chevronBox.leadingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),
        ])

        // Expandable content — clipped to its animatable height.
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.wantsLayer = true
        content.layer?.masksToBounds = true
        content.alphaValue = 0
        errorLogContentContainer = content

        let divider = rowDivider()
        content.addSubview(divider)

        // Crash log — read-only, selectable, monospace.
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 8
        scroll.layer?.masksToBounds = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        errorLogTextView = textView

        // Action buttons.
        func makeLogButton(title: String, action: Selector) -> NSButton {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.font = NSFont.systemFont(ofSize: 12)
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }

        let copyButton = makeLogButton(title: L10n.aboutErrorLogCopy, action: #selector(copyErrorLog))
        errorLogCopyButton = copyButton

        let revealButton = makeLogButton(title: L10n.aboutErrorLogReveal, action: #selector(revealErrorLog))
        errorLogRevealButton = revealButton

        let refreshButton = makeLogButton(title: L10n.aboutErrorLogRefresh, action: #selector(refreshErrorLog))
        errorLogRefreshButton = refreshButton

        let clearButton = makeLogButton(title: L10n.aboutErrorLogClear, action: #selector(clearErrorLog))
        errorLogClearButton = clearButton

        content.addSubview(scroll)
        content.addSubview(copyButton)
        content.addSubview(revealButton)
        content.addSubview(refreshButton)
        content.addSubview(clearButton)
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: content.topAnchor),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            scroll.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            scroll.heightAnchor.constraint(equalToConstant: 220),

            copyButton.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 10),
            copyButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            copyButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),

            revealButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            revealButton.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 8),

            refreshButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: revealButton.trailingAnchor, constant: 8),

            clearButton.centerYAnchor.constraint(equalTo: copyButton.centerYAnchor),
            clearButton.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 8),
        ])

        let inner = verticalInnerStack()
        card.content.addSubview(inner)
        pin(inner, to: card.content, insets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
        inner.addArrangedSubview(header)
        inner.addArrangedSubview(content)
        header.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        content.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        let heightConstraint = content.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.isActive = true
        errorLogHeightConstraint = heightConstraint

        refreshErrorLogStatus()
        return card
    }

    /// Expands or collapses the crash-log viewer with a height animation.
    @objc private func toggleErrorLog() {
        errorLogExpanded.toggle()
        if errorLogExpanded { loadErrorLogIfNeeded() }

        guard let content = errorLogContentContainer,
              let heightConstraint = errorLogHeightConstraint else { return }

        // Measure the content's natural height with the clamp lifted.
        var target: CGFloat = 0
        if errorLogExpanded {
            heightConstraint.isActive = false
            content.layoutSubtreeIfNeeded()
            target = content.fittingSize.height
            heightConstraint.isActive = true
            heightConstraint.constant = 0
            content.layoutSubtreeIfNeeded()
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ctx.allowsImplicitAnimation = true
            heightConstraint.animator().constant = target
            content.animator().alphaValue = errorLogExpanded ? 1 : 0
            errorLogChevron?.animator().frameCenterRotation = errorLogExpanded ? -90 : 0
            self.layoutSubtreeIfNeeded()
        }
    }

    /// Reads the latest crash report into the text view on first expansion.
    private func loadErrorLogIfNeeded() {
        guard !errorLogLoaded else { return }
        renderErrorLogContent()
    }

    /// Re-scans log files and refreshes the visible error-log content.
    private func reloadErrorLogFromDisk() {
        refreshErrorLogStatus()
        renderErrorLogContent()
    }

    private func renderErrorLogContent() {
        errorLogLoaded = true
        if let entry = errorLogEntry {
            errorLogTextView?.string = CrashLogReader.readableText(at: entry.url)
            errorLogTextView?.textColor = .labelColor
            errorLogCopyButton?.isEnabled = true
            errorLogRevealButton?.isEnabled = true
            errorLogClearButton?.isEnabled = true
        } else {
            errorLogTextView?.string = L10n.aboutErrorLogEmptyBody
            errorLogTextView?.textColor = .secondaryLabelColor
            errorLogCopyButton?.isEnabled = false
            errorLogRevealButton?.isEnabled = false
            errorLogClearButton?.isEnabled = false
        }
    }

    /// Syncs the header status label to whether a crash report exists.
    private func refreshErrorLogStatus() {
        errorLogEntry = CrashLogReader.latestLogFile()
        guard let label = errorLogStatusLabel else { return }
        if let entry = errorLogEntry {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            label.stringValue = L10n.aboutErrorLogLastCrash(formatter.string(from: entry.date))
            label.textColor = NSColor.systemOrange
            errorLogCopyButton?.isEnabled = errorLogLoaded
            errorLogRevealButton?.isEnabled = errorLogLoaded
            errorLogClearButton?.isEnabled = true
        } else {
            label.stringValue = L10n.aboutErrorLogNoCrash
            label.textColor = .secondaryLabelColor
            errorLogCopyButton?.isEnabled = false
            errorLogRevealButton?.isEnabled = false
            errorLogClearButton?.isEnabled = false
        }
    }

    /// Copies the crash report to the clipboard, flashing the button as feedback.
    @objc private func copyErrorLog() {
        guard errorLogEntry != nil,
              let text = errorLogTextView?.string, !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let button = errorLogCopyButton else { return }
        button.title = L10n.aboutErrorLogCopied
        button.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.errorLogCopyButton?.title = L10n.aboutErrorLogCopy
            self?.errorLogCopyButton?.isEnabled = true
        }
    }

    /// Reveals the crash report file in Finder.
    @objc private func revealErrorLog() {
        guard let url = errorLogEntry?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Manually reloads logs from disk.
    @objc private func refreshErrorLog() {
        reloadErrorLogFromDisk()
    }

    /// Deletes all capcap crash reports and resets the visible error-log UI.
    @objc private func clearErrorLog() {
        CrashLogReader.deleteAllLogs()
        errorLogEntry = nil
        errorLogLoaded = true
        errorLogTextView?.string = L10n.aboutErrorLogEmptyBody
        errorLogTextView?.textColor = .secondaryLabelColor
        errorLogCopyButton?.isEnabled = false
        errorLogRevealButton?.isEnabled = false
        errorLogClearButton?.isEnabled = false
        refreshErrorLogStatus()
    }

    /// Static left-title / right-value row, mirroring the permission row chrome.
    private func makeInfoRow(title: String, value: String) -> (row: NSView, title: NSTextField) {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(titleLabel)
        row.addSubview(valueLabel)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 46),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),
        ])
        return (row, titleLabel)
    }

    /// Tappable row that opens an external URL, with a chevron affordance.
    private func makeLinkRow(title: String, value: String, action: Selector) -> (row: NSView, title: NSTextField) {
        let button = HoverButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.title = ""
        button.isBordered = false
        button.cornerRadius = 10

        let titleLabel = primaryLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = NSColor.linkColor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let chevron = NSTextField(labelWithString: "\u{203A}")
        chevron.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        chevron.textColor = .tertiaryLabelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        button.addSubview(titleLabel)
        button.addSubview(valueLabel)
        button.addSubview(chevron)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 46),
            titleLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            valueLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),
        ])
        return (button, titleLabel)
    }

    @objc private func openSourceRepo() {
        if let url = URL(string: "https://github.com/realskyrin/capcap") {
            NSWorkspace.shared.open(url)
        }
    }

    /// "Updates" row — a status label plus a button whose role tracks state:
    /// "Check for Updates" normally, "Update Now" once a newer release is found.
    private func makeUpdateRow() -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(L10n.aboutUpdateTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutUpdateTitleLabel = titleLabel

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        aboutUpdateStatusLabel = statusLabel

        let button = NSButton(title: L10n.checkForUpdates, target: self,
                              action: #selector(aboutUpdateButtonClicked))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        aboutUpdateButton = button

        row.addSubview(titleLabel)
        row.addSubview(statusLabel)
        row.addSubview(button)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 46),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            button.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: button.leadingAnchor, constant: -10),
            statusLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),
        ])

        refreshUpdateRow()
        return row
    }

    @objc private func aboutUpdateButtonClicked() {
        switch UpdateChecker.shared.state {
        case .available(let version):
            StatusBarController.presentUpdateAvailableAlertAfterRefresh(fallbackVersion: version)
        case .installFailed:
            if let url = UpdateChecker.shared.latestPageURL {
                NSWorkspace.shared.open(url)
            }
        default:
            UpdateChecker.shared.check(manual: true) { state in
                guard UpdateChecker.isDebugBuild,
                      case .available(let version) = state else { return }
                StatusBarController.presentUpdateAvailableAlert(version: version)
            }
        }
    }

    /// Syncs the Updates row to the current check state.
    @objc private func refreshUpdateRow() {
        guard let statusLabel = aboutUpdateStatusLabel, let button = aboutUpdateButton else { return }
        let dim = NSColor.secondaryLabelColor
        let accent = NSColor.linkColor
        let warn = NSColor.systemOrange

        switch UpdateChecker.shared.state {
        case .idle:
            statusLabel.stringValue = appVersionString()
            statusLabel.textColor = dim
            button.title = L10n.checkForUpdates
            button.isEnabled = true
        case .checking:
            statusLabel.stringValue = L10n.updateChecking
            statusLabel.textColor = dim
            button.title = L10n.checkForUpdates
            button.isEnabled = false
        case .upToDate:
            statusLabel.stringValue = L10n.updateUpToDateStatus
            statusLabel.textColor = dim
            button.title = L10n.checkForUpdates
            button.isEnabled = true
        case .available(let version):
            statusLabel.stringValue = L10n.updateNewVersionStatus(version)
            statusLabel.textColor = accent
            button.title = L10n.updateInstallNowButton
            button.isEnabled = true
        case .downloading(_, let fraction):
            statusLabel.stringValue = L10n.updateDownloadingStatus(Int(fraction * 100))
            statusLabel.textColor = accent
            button.title = L10n.updateInstallNowButton
            button.isEnabled = false
        case .installing:
            statusLabel.stringValue = L10n.updateInstallingStatus
            statusLabel.textColor = accent
            button.title = L10n.updateInstallNowButton
            button.isEnabled = false
        case .failed:
            statusLabel.stringValue = L10n.updateFailedStatus
            statusLabel.textColor = warn
            button.title = L10n.updateRetryButton
            button.isEnabled = true
        case .installFailed:
            statusLabel.stringValue = L10n.updateInstallFailedStatus
            statusLabel.textColor = warn
            button.title = L10n.updateDownloadButton
            button.isEnabled = true
        }
    }

    private func paneStack() -> NSStackView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    private func wrapPane(_ stack: NSStackView) -> NSView {
        let host = NSView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: host.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -22),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -22),
        ])
        return host
    }

    // MARK: - Builders

    private func verticalInnerStack() -> NSStackView {
        let s = NSStackView()
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }

    private func rowDivider() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func flexSpacer() -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setContentHuggingPriority(.init(1), for: .horizontal)
        v.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        return v
    }

    private func primaryLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .labelColor
        return l
    }

    private func secondaryLabel(_ text: String, wrapping: Bool = false) -> NSTextField {
        let l = wrapping ? NSTextField(wrappingLabelWithString: text) : NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        l.textColor = .secondaryLabelColor
        if wrapping {
            l.preferredMaxLayoutWidth = 360
        }
        return l
    }

    private func pin(_ child: NSView, to parent: NSView, insets: NSEdgeInsets) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: insets.top),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: insets.left),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -insets.right),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -insets.bottom),
        ])
    }

    private struct ShortcutCardBuild {
        let card: SettingsGroupView
        let title: NSTextField
        let field: NSTextField
        let setButton: NSButton
        let restoreButton: NSButton
    }

    private func buildShortcutCard(
        title: String,
        setAction: Selector,
        restoreAction: Selector
    ) -> ShortcutCardBuild {
        let card = SettingsGroupView()
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 8
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.content.addSubview(inner)
        pin(inner, to: card.content, insets: NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 14))

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(flexSpacer())

        let field = NSTextField()
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        field.alignment = .center
        field.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        field.textColor = .labelColor
        field.translatesAutoresizingMaskIntoConstraints = false

        let fieldBackground = AdaptiveChromeSurfaceView(style: .card, cornerRadius: 6)
        fieldBackground.translatesAutoresizingMaskIntoConstraints = false
        fieldBackground.addSubview(field)
        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: fieldBackground.topAnchor, constant: 4),
            field.bottomAnchor.constraint(equalTo: fieldBackground.bottomAnchor, constant: -4),
            field.leadingAnchor.constraint(equalTo: fieldBackground.leadingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: fieldBackground.trailingAnchor, constant: -10),
            fieldBackground.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
        ])
        row.addArrangedSubview(fieldBackground)

        let setButton = NSButton(title: L10n.shortcutSet, target: self, action: setAction)
        setButton.bezelStyle = .rounded
        setButton.controlSize = .small
        setButton.font = NSFont.systemFont(ofSize: 12)
        setButton.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(setButton)

        let restoreButton = NSButton(
            image: NSImage(
                systemSymbolName: "arrow.counterclockwise.circle.fill",
                accessibilityDescription: L10n.shortcutRestore
            ) ?? NSImage(),
            target: self,
            action: restoreAction
        )
        restoreButton.bezelStyle = .inline
        restoreButton.isBordered = false
        restoreButton.imagePosition = .imageOnly
        restoreButton.contentTintColor = .secondaryLabelColor
        restoreButton.toolTip = L10n.shortcutRestore
        restoreButton.translatesAutoresizingMaskIntoConstraints = false
        restoreButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
        row.addArrangedSubview(restoreButton)

        inner.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true

        return ShortcutCardBuild(
            card: card,
            title: titleLabel,
            field: field,
            setButton: setButton,
            restoreButton: restoreButton
        )
    }

    private struct ToggleRowBuild {
        let row: NSView
        let title: NSTextField
        let subtitle: NSTextField?
        let toggle: NSSwitch
    }

    private func makeToggleRow(
        title: String,
        subtitle: String?,
        isOn: Bool,
        action: Selector
    ) -> ToggleRowBuild {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)

        var subtitleLabel: NSTextField? = nil
        if let subtitle {
            let sub = secondaryLabel(subtitle, wrapping: true)
            textStack.addArrangedSubview(sub)
            subtitleLabel = sub
        }

        let sw = NSSwitch()
        sw.state = isOn ? .on : .off
        sw.target = self
        sw.action = action
        sw.controlSize = .regular
        sw.setAccessibilityTitleUIElement(titleLabel)
        sw.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(textStack)
        row.addSubview(sw)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: sw.leadingAnchor, constant: -12),

            sw.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            sw.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),
        ])

        return ToggleRowBuild(row: row, title: titleLabel, subtitle: subtitleLabel, toggle: sw)
    }

    private struct RadioRowBuild {
        let row: NSView
        let title: NSTextField
        let subtitle: NSTextField?
        let button: NSButton
    }

    private func makeRadioRow(
        title: String,
        subtitle: String?,
        isOn: Bool,
        action: Selector
    ) -> RadioRowBuild {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = primaryLabel(title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(titleLabel)

        var subtitleLabel: NSTextField? = nil
        if let subtitle {
            let sub = secondaryLabel(subtitle, wrapping: true)
            textStack.addArrangedSubview(sub)
            subtitleLabel = sub
        }

        let button = NSButton(radioButtonWithTitle: "", target: self, action: action)
        button.state = isOn ? .on : .off
        button.setAccessibilityTitleUIElement(titleLabel)
        button.controlSize = .small
        button.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(textStack)
        row.addSubview(button)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -12),

            button.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: textStack.centerYAnchor),
        ])

        return RadioRowBuild(row: row, title: titleLabel, subtitle: subtitleLabel, button: button)
    }

    private struct PermissionRowBuild {
        let row: NSView
        let name: NSTextField
        let desc: NSTextField
        let badge: StatusBadge
    }

    private func makePermissionRow(
        name: String,
        description: String,
        action: Selector
    ) -> PermissionRowBuild {
        let button = HoverButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = action
        button.title = ""
        button.isBordered = false
        button.cornerRadius = 10

        let nameLbl = primaryLabel(name)
        nameLbl.translatesAutoresizingMaskIntoConstraints = false

        let badge = StatusBadge()
        badge.translatesAutoresizingMaskIntoConstraints = false

        let topLine = NSStackView(views: [nameLbl, badge])
        topLine.orientation = .horizontal
        topLine.alignment = .centerY
        topLine.spacing = 8
        topLine.translatesAutoresizingMaskIntoConstraints = false

        let descLbl = secondaryLabel(description, wrapping: true)
        descLbl.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView()
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubview(topLine)
        textStack.addArrangedSubview(descLbl)

        let chevron = NSTextField(labelWithString: "\u{203A}")
        chevron.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        chevron.textColor = .tertiaryLabelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        button.addSubview(textStack)
        button.addSubview(chevron)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12),
            textStack.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -10),

            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
        ])

        return PermissionRowBuild(row: button, name: nameLbl, desc: descLbl, badge: badge)
    }

    private func refreshBottomAction() {
        launchButton.title = isStartup ? L10n.launchApp : L10n.settingsQuit
        launchButton.isEnabled = !isStartup || AppPermissions.allRequiredGranted
        launchButton.keyEquivalent = isStartup ? "\r" : ""
        if #available(macOS 26.0, *) {
            launchButton.bezelStyle = isStartup ? .glass : .rounded
        }
    }

    func setStartupMode(_ startup: Bool) {
        let wasStartup = isStartup
        isStartup = startup
        refreshBottomAction()
        if startup {
            selectTab(.permissions)
        } else if wasStartup && selectedTab == .permissions && AppPermissions.allRequiredGranted {
            selectTab(.general)
        }
    }

    func showPermissionsTab() {
        selectTab(.permissions)
    }

    // MARK: - Permission polling

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    func refreshPermissionStatus() {
        let accessibilityGranted = AppPermissions.accessibilityGranted
        let screenRecordingGranted = AppPermissions.screenRecordingGranted

        accessibilityBadge?.configure(granted: accessibilityGranted)
        screenRecordingBadge?.configure(granted: screenRecordingGranted)
        microphoneBadge?.configure(granted: AppPermissions.microphoneGranted)

        // Only the startup-mode Launch button is gated on permissions; the
        // regular-mode Quit button stays enabled.
        if isStartup {
            refreshBottomAction()
        }
    }

    // MARK: - Actions

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let cases = AppLanguage.allCases
        let index = sender.indexOfSelectedItem
        guard cases.indices.contains(index) else { return }
        Defaults.language = cases[index]
    }

    @objc private func recordingSaveFormatPreferenceChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let preference = RecordingSavePreference(rawValue: raw)
        else {
            return
        }
        Defaults.recordingSavePreference = preference
    }

    @objc private func screenshotSaveQualityChanged(_ sender: NSPopUpButton) {
        guard let quality = selectedScreenshotQuality(from: sender) else { return }
        Defaults.screenshotSaveQuality = quality
        refreshScreenshotQualityControls()
    }

    @objc private func screenshotClipboardQualityChanged(_ sender: NSPopUpButton) {
        guard let quality = selectedScreenshotQuality(from: sender) else { return }
        Defaults.screenshotClipboardQuality = quality
        refreshScreenshotQualityControls()
    }

    private func selectedScreenshotQuality(from sender: NSPopUpButton) -> ScreenshotImageQuality? {
        guard let raw = sender.selectedItem?.representedObject as? String else { return nil }
        return ScreenshotImageQuality(rawValue: raw)
    }

    @objc private func askSaveLocationToggled(_ sender: NSSwitch) {
        Defaults.askSaveLocation = sender.state == .on
    }

    @objc private func autoRevealSavedFilesToggled(_ sender: NSSwitch) {
        Defaults.autoRevealSavedFiles = sender.state == .on
    }

    @objc private func chooseRecordingSavePathClicked() {
        chooseSaveDirectory(
            title: L10n.chooseRecordingSavePathTitle,
            currentURL: Defaults.recordingSaveDirectory
        ) { url in
            Defaults.recordingSaveDirectory = url
            self.refreshSavePathControls()
        }
    }

    @objc private func chooseScreenshotSavePathClicked() {
        chooseSaveDirectory(
            title: L10n.chooseScreenshotSavePathTitle,
            currentURL: Defaults.screenshotSaveDirectory
        ) { url in
            Defaults.screenshotSaveDirectory = url
            self.refreshSavePathControls()
        }
    }

    @objc private func revealRecordingSavePathClicked() {
        revealSaveDirectory(Defaults.recordingSaveDirectory)
    }

    @objc private func revealScreenshotSavePathClicked() {
        revealSaveDirectory(Defaults.screenshotSaveDirectory)
    }

    private func chooseSaveDirectory(
        title: String,
        currentURL: URL,
        completion: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = L10n.savePathChoose
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directoryURLForPanel(currentURL)

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            completion(url)
        }

        if let window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            panel.begin(completionHandler: handle)
        }
    }

    private func directoryURLForPanel(_ url: URL) -> URL {
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let parent = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parent.path) {
            return parent
        }
        return Defaults.defaultScreenshotSaveDirectory.deletingLastPathComponent()
    }

    private func revealSaveDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func historyCacheSliderChanged(_ sender: NSSlider) {
        guard Defaults.historyCacheEnabled else {
            sender.doubleValue = Double(Defaults.historyCacheLimit)
            return
        }
        let value = Int(sender.doubleValue.rounded())
        Defaults.historyCacheLimit = value
        let normalizedValue = Defaults.historyCacheLimit
        sender.doubleValue = Double(normalizedValue)
        historyCacheValueLabel?.stringValue = "\(normalizedValue)"
    }

    @objc private func historyCacheToggled(_ sender: NSSwitch) {
        Defaults.historyCacheEnabled = sender.state == .on
        updateHistoryCacheControlsEnabled()
        updateHistoryPanelModeControlsEnabled()
    }

    @objc private func historyNotchTriggerChanged(_ sender: NSPopUpButton) {
        let modes = Defaults.HistoryNotchTriggerMode.allCases
        guard modes.indices.contains(sender.indexOfSelectedItem) else { return }
        Defaults.historyNotchTriggerMode = modes[sender.indexOfSelectedItem]
    }

    @objc private func historyPanelModeOptionClicked(_ sender: HistoryPanelModeOptionView) {
        guard Defaults.isHistoryCacheAvailable else { return }
        switch sender.mode {
        case .dialog:
            Defaults.historyPanelDialogEnabled = true
        case .notch:
            guard Defaults.historyPanelNotchAvailable else {
                updateHistoryPanelModeControlsEnabled()
                return
            }
            Defaults.historyPanelNotchEnabled = true
        }
        updateHistoryPanelModeControlsEnabled()
    }

    @objc private func screenParametersChanged() {
        updateHistoryPanelModeControlsEnabled()
    }

    @objc private func countdownSliderChanged(_ sender: NSSlider) {
        let value = Int(sender.doubleValue.rounded())
        Defaults.countdownSeconds = value
        countdownValueLabel?.stringValue = "\(Defaults.countdownSeconds)\(L10n.countdownSecondsSuffix)"
    }

    @objc private func windowShadowToggled(_ sender: NSSwitch) {
        Defaults.windowShadowEnabled = sender.state == .on
        updateWindowShadowControlsEnabled()
    }

    @objc private func recordingSystemAudioToggled(_ sender: NSSwitch) {
        Defaults.recordingSystemAudioEnabled = sender.state == .on
    }

    @objc private func recordingMicrophoneToggled(_ sender: NSSwitch) {
        let enabled = sender.state == .on
        Defaults.recordingMicrophoneEnabled = enabled
        updateMicrophoneControlsEnabled()
        guard enabled else { return }

        // Once denied, macOS won't re-prompt — bounce to System Settings and
        // revert the toggle so the UI stays truthful.
        if AppPermissions.microphoneGranted {
            return
        }
        if AppPermissions.microphoneDenied {
            sender.state = .off
            Defaults.recordingMicrophoneEnabled = false
            updateMicrophoneControlsEnabled()
            presentMicrophoneDeniedAlert()
            return
        }
        AppPermissions.requestMicrophonePermission { [weak self] granted in
            guard let self else { return }
            if granted {
                self.refreshPermissionStatus()
                return
            }
            // User declined the prompt or an error occurred. Revert.
            self.recordingMicrophoneSwitch?.state = .off
            Defaults.recordingMicrophoneEnabled = false
            self.updateMicrophoneControlsEnabled()
            self.refreshPermissionStatus()
        }
    }

    private func presentMicrophoneDeniedAlert() {
        guard let win = self.window else { return }
        let alert = NSAlert()
        alert.messageText = L10n.recordingMicrophoneDeniedTitle
        alert.informativeText = L10n.recordingMicrophoneDeniedMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.recordingMicrophoneOpenSettings)
        alert.addButton(withTitle: L10n.shortcutCancel)
        alert.beginSheetModal(for: win) { response in
            if response == .alertFirstButtonReturn {
                self.openMicrophoneSystemSettings()
            }
        }
    }

    @objc private func windowShadowSizeChanged(_ sender: NSSlider) {
        Defaults.windowShadowSize = sender.doubleValue
        windowShadowSizeValueLabel?.stringValue = "\(Int(Defaults.windowShadowSize.rounded()))"
        windowShadowPreview?.shadowSize = CGFloat(Defaults.windowShadowSize)
    }

    @objc private func launchAtLoginToggled(_ sender: NSSwitch) {
        let enable = sender.state == .on
        let ok = LaunchAtLogin.setEnabled(enable)
        if !ok {
            sender.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }

    @objc private func showCopyToastToggled(_ sender: NSSwitch) {
        Defaults.showCopyToast = sender.state == .on
    }

    @objc private func pinAcrossSpacesToggled(_ sender: NSSwitch) {
        Defaults.pinAcrossSpaces = sender.state == .on
    }

    @objc private func menuBarSwitchToggled(_ sender: NSSwitch) {
        let visible = sender.state == .on
        Defaults.showMenuBar = visible
        onMenuBarToggle?(visible)
    }

    @objc private func openAccessibilitySettings(_ sender: NSButton) {
        startPermissionFlow(.accessibility, from: sender)
    }

    @objc private func openScreenRecordingSettings(_ sender: NSButton) {
        startPermissionFlow(.screenRecording, from: sender)
    }

    @objc private func openMicrophoneSettings(_ sender: NSButton) {
        // Microphone is optional and macOS will not re-prompt once a decision
        // has been made. If a decision is still pending, request inline; if it
        // was already denied, jump straight to System Settings.
        if AppPermissions.microphoneGranted {
            return
        }
        if AppPermissions.microphoneDenied {
            openMicrophoneSystemSettings()
            return
        }
        AppPermissions.requestMicrophonePermission { [weak self] granted in
            guard let self else { return }
            self.refreshPermissionStatus()
            if !granted {
                self.openMicrophoneSystemSettings()
            }
        }
    }

    private func openMicrophoneSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func startPermissionFlow(_ pane: PermissionFlowPane, from sourceView: NSView) {
        permissionFlowController.setLocaleIdentifier(Defaults.language.lprojName)
        updateMicrophoneControlsEnabled()
        permissionFlowController.authorize(
            pane: pane,
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: sourceFrameInScreen(for: sourceView)
        )
    }

    private func sourceFrameInScreen(for view: NSView) -> CGRect? {
        guard let window = view.window else { return nil }
        let frameInWindow = view.convert(view.bounds, to: nil)
        return window.convertToScreen(frameInWindow)
    }

    func closePermissionFlowPanel() {
        permissionFlowController.closePanel()
    }

    @objc private func launchClicked() {
        if isStartup {
            guard AppPermissions.allRequiredGranted else {
                showPermissionsTab()
                refreshPermissionStatus()
                return
            }
            refreshTimer?.invalidate()
            refreshTimer = nil
            onLaunch?()
        } else {
            confirmQuit()
        }
    }

    private func confirmQuit() {
        let alert = NSAlert()
        alert.messageText = L10n.quitConfirmTitle
        alert.informativeText = L10n.quitConfirmMessage
        alert.alertStyle = .warning
        let quitBtn = alert.addButton(withTitle: L10n.quitConfirmAction)
        if #available(macOS 11.0, *) {
            quitBtn.hasDestructiveAction = true
        }
        let cancelBtn = alert.addButton(withTitle: L10n.quitConfirmCancel)
        cancelBtn.keyEquivalent = "\u{1b}" // Escape

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertFirstButtonReturn {
                NSApp.terminate(nil)
            }
        }
        if let win = self.window {
            alert.beginSheetModal(for: win, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }

    // MARK: - Shortcut recording

    /// Tells the user a recorded combo is already taken by another function,
    /// so they can pick a different one. Recording is already cancelled by the
    /// caller before this is shown.
    private func presentHotkeyConflictAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.shortcutConflictTitle
        alert.informativeText = message
        alert.alertStyle = .warning
        if let win = self.window {
            alert.beginSheetModal(for: win, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    /// Tells the user a recorded key needs a modifier held with it, so they
    /// can try again. Recording is already cancelled by the caller before
    /// this is shown.
    private func presentShortcutNeedsModifierAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.shortcutNeedsModifierTitle
        alert.informativeText = L10n.shortcutNeedsModifier
        alert.alertStyle = .warning
        if let win = self.window {
            alert.beginSheetModal(for: win, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    private func cancelShortcutRecordings(except slot: HotkeyManager.HotkeySlot) {
        if slot != .screenshot, shortcutRecordingMonitor != nil {
            cancelShortcutRecording()
        }
        if slot != .fullScreenScreenshot, fullScreenScreenshotShortcutRecordingMonitor != nil {
            cancelFullScreenScreenshotShortcutRecording()
        }
        if slot != .quickPin, quickPinShortcutRecordingMonitor != nil {
            cancelQuickPinShortcutRecording()
        }
        if slot != .selectedImagePin, selectedImagePinShortcutRecordingMonitor != nil {
            cancelSelectedImagePinShortcutRecording()
        }
        if slot != .clipboardImagePin, clipboardImagePinShortcutRecordingMonitor != nil {
            cancelClipboardImagePinShortcutRecording()
        }
        if slot != .clipboardTextPin, clipboardTextPinShortcutRecordingMonitor != nil {
            cancelClipboardTextPinShortcutRecording()
        }
        if slot != .selectedImageEdit, selectedImageEditShortcutRecordingMonitor != nil {
            cancelSelectedImageEditShortcutRecording()
        }
        if slot != .clipboardImageEdit, clipboardImageEditShortcutRecordingMonitor != nil {
            cancelClipboardImageEditShortcutRecording()
        }
        if slot != .textRecognition, textRecognitionShortcutRecordingMonitor != nil {
            cancelTextRecognitionShortcutRecording()
        }
        if slot != .copyImageText, copyImageTextShortcutRecordingMonitor != nil {
            cancelCopyImageTextShortcutRecording()
        }
        if slot != .screenshotTranslation, screenshotTranslationShortcutRecordingMonitor != nil {
            cancelScreenshotTranslationShortcutRecording()
        }
        if slot != .record, recordShortcutRecordingMonitor != nil {
            cancelRecordShortcutRecording()
        }
        if slot != .clipboard, clipboardShortcutRecordingMonitor != nil {
            cancelClipboardShortcutRecording()
        }
        if slot != .fileSave, fileSaveShortcutRecordingMonitor != nil {
            cancelFileSaveShortcutRecording()
        }
        if slot != .previousHistoryImage, previousHistoryImageShortcutRecordingMonitor != nil {
            cancelPreviousHistoryImageShortcutRecording()
        }
        if slot != .nextHistoryImage, nextHistoryImageShortcutRecordingMonitor != nil {
            cancelNextHistoryImageShortcutRecording()
        }
        if slot != .historyPanel, historyPanelShortcutRecordingMonitor != nil {
            cancelHistoryPanelShortcutRecording()
        }
    }

    @objc private func shortcutSetClicked() {
        if shortcutRecordingMonitor != nil {
            cancelShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .screenshot)
        HotkeyManager.shared.beginRecording()
        shortcutSetButton.title = L10n.shortcutCancel
        shortcutField.stringValue = L10n.shortcutWaiting
        shortcutRestoreButton.isHidden = true

        shortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            // Reject bare keys (no modifier and not a function key) — the user must
            // hold at least one modifier so the shortcut won't collide with typing.
            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .screenshot) {
                self.cancelShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.screenshotHotkeyKeyCode = Int(keyCode)
            Defaults.screenshotHotkeyModifiers = Int(carbonMods)
            self.finishShortcutRecording()
            return nil
        }
    }

    @objc private func shortcutRestoreClicked() {
        if shortcutRecordingMonitor != nil {
            cancelShortcutRecording()
        }
        Defaults.clearScreenshotHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshShortcutDisplay()
    }

    private func finishShortcutRecording() {
        if let m = shortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            shortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshShortcutDisplay()
    }

    func cancelShortcutRecording() {
        guard shortcutRecordingMonitor != nil else { return }
        if let m = shortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            shortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshShortcutDisplay()
    }

    private func refreshShortcutDisplay() {
        shortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentDisplayString() {
            shortcutField?.stringValue = display
            shortcutRestoreButton?.isHidden = false
        } else {
            shortcutField?.stringValue = L10n.shortcutDefaultDisplay
            shortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func fullScreenScreenshotShortcutSetClicked() {
        if fullScreenScreenshotShortcutRecordingMonitor != nil {
            cancelFullScreenScreenshotShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .fullScreenScreenshot)
        HotkeyManager.shared.beginRecording()
        fullScreenScreenshotShortcutSetButton.title = L10n.shortcutCancel
        fullScreenScreenshotShortcutField.stringValue = L10n.shortcutWaiting
        fullScreenScreenshotShortcutRestoreButton.isHidden = true

        fullScreenScreenshotShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelFullScreenScreenshotShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelFullScreenScreenshotShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .fullScreenScreenshot) {
                self.cancelFullScreenScreenshotShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.fullScreenScreenshotHotkeyKeyCode = Int(keyCode)
            Defaults.fullScreenScreenshotHotkeyModifiers = Int(carbonMods)
            self.finishFullScreenScreenshotShortcutRecording()
            return nil
        }
    }

    @objc private func fullScreenScreenshotShortcutRestoreClicked() {
        if fullScreenScreenshotShortcutRecordingMonitor != nil {
            cancelFullScreenScreenshotShortcutRecording()
        }
        Defaults.clearFullScreenScreenshotHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshFullScreenScreenshotShortcutDisplay()
    }

    private func finishFullScreenScreenshotShortcutRecording() {
        if let m = fullScreenScreenshotShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            fullScreenScreenshotShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshFullScreenScreenshotShortcutDisplay()
    }

    func cancelFullScreenScreenshotShortcutRecording() {
        guard fullScreenScreenshotShortcutRecordingMonitor != nil else { return }
        if let m = fullScreenScreenshotShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            fullScreenScreenshotShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshFullScreenScreenshotShortcutDisplay()
    }

    private func refreshFullScreenScreenshotShortcutDisplay() {
        fullScreenScreenshotShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentFullScreenScreenshotDisplayString() {
            fullScreenScreenshotShortcutField?.stringValue = display
            fullScreenScreenshotShortcutRestoreButton?.isHidden = false
        } else {
            fullScreenScreenshotShortcutField?.stringValue = L10n.fullScreenScreenshotShortcutDefaultDisplay
            fullScreenScreenshotShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func quickPinShortcutSetClicked() {
        if quickPinShortcutRecordingMonitor != nil {
            cancelQuickPinShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .quickPin)
        HotkeyManager.shared.beginRecording()
        quickPinShortcutSetButton.title = L10n.shortcutCancel
        quickPinShortcutField.stringValue = L10n.shortcutWaiting
        quickPinShortcutRestoreButton.isHidden = true

        quickPinShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelQuickPinShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelQuickPinShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .quickPin) {
                self.cancelQuickPinShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.quickPinHotkeyKeyCode = Int(keyCode)
            Defaults.quickPinHotkeyModifiers = Int(carbonMods)
            self.finishQuickPinShortcutRecording()
            return nil
        }
    }

    @objc private func quickPinShortcutRestoreClicked() {
        if quickPinShortcutRecordingMonitor != nil {
            cancelQuickPinShortcutRecording()
        }
        Defaults.clearQuickPinHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshQuickPinShortcutDisplay()
    }

    private func finishQuickPinShortcutRecording() {
        if let monitor = quickPinShortcutRecordingMonitor {
            NSEvent.removeMonitor(monitor)
            quickPinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshQuickPinShortcutDisplay()
    }

    func cancelQuickPinShortcutRecording() {
        guard let monitor = quickPinShortcutRecordingMonitor else { return }
        NSEvent.removeMonitor(monitor)
        quickPinShortcutRecordingMonitor = nil
        HotkeyManager.shared.endRecording()
        refreshQuickPinShortcutDisplay()
    }

    private func refreshQuickPinShortcutDisplay() {
        quickPinShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentQuickPinDisplayString() {
            quickPinShortcutField?.stringValue = display
            quickPinShortcutRestoreButton?.isHidden = false
        } else {
            quickPinShortcutField?.stringValue = L10n.quickPinShortcutDefaultDisplay
            quickPinShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func selectedImagePinShortcutSetClicked() {
        if selectedImagePinShortcutRecordingMonitor != nil {
            cancelSelectedImagePinShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .selectedImagePin)
        HotkeyManager.shared.beginRecording()
        selectedImagePinShortcutSetButton.title = L10n.shortcutCancel
        selectedImagePinShortcutField.stringValue = L10n.shortcutWaiting
        selectedImagePinShortcutRestoreButton.isHidden = true

        selectedImagePinShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelSelectedImagePinShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelSelectedImagePinShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            // No two functions may share a shortcut — reject a combo already
            // bound to the screenshot or countdown hotkey.
            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .selectedImagePin) {
                self.cancelSelectedImagePinShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.selectedImagePinHotkeyKeyCode = Int(keyCode)
            Defaults.selectedImagePinHotkeyModifiers = Int(carbonMods)
            self.finishSelectedImagePinShortcutRecording()
            return nil
        }
    }

    @objc private func selectedImagePinShortcutRestoreClicked() {
        if selectedImagePinShortcutRecordingMonitor != nil {
            cancelSelectedImagePinShortcutRecording()
        }
        Defaults.clearSelectedImagePinHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshSelectedImagePinShortcutDisplay()
    }

    private func finishSelectedImagePinShortcutRecording() {
        if let m = selectedImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImagePinShortcutDisplay()
    }

    func cancelSelectedImagePinShortcutRecording() {
        guard selectedImagePinShortcutRecordingMonitor != nil else { return }
        if let m = selectedImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImagePinShortcutDisplay()
    }

    private func refreshSelectedImagePinShortcutDisplay() {
        selectedImagePinShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentSelectedImagePinDisplayString() {
            selectedImagePinShortcutField?.stringValue = display
            selectedImagePinShortcutRestoreButton?.isHidden = false
        } else {
            selectedImagePinShortcutField?.stringValue = L10n.selectedImagePinShortcutDefaultDisplay
            selectedImagePinShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func clipboardImagePinShortcutSetClicked() {
        if clipboardImagePinShortcutRecordingMonitor != nil {
            cancelClipboardImagePinShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboardImagePin)
        HotkeyManager.shared.beginRecording()
        clipboardImagePinShortcutSetButton.title = L10n.shortcutCancel
        clipboardImagePinShortcutField.stringValue = L10n.shortcutWaiting
        clipboardImagePinShortcutRestoreButton.isHidden = true

        clipboardImagePinShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardImagePinShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelClipboardImagePinShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            // No two functions may share a shortcut — reject a combo already
            // bound to the screenshot or countdown hotkey.
            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboardImagePin) {
                self.cancelClipboardImagePinShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardImagePinHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardImagePinHotkeyModifiers = Int(carbonMods)
            self.finishClipboardImagePinShortcutRecording()
            return nil
        }
    }

    @objc private func clipboardImagePinShortcutRestoreClicked() {
        if clipboardImagePinShortcutRecordingMonitor != nil {
            cancelClipboardImagePinShortcutRecording()
        }
        Defaults.clearClipboardImagePinHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardImagePinShortcutDisplay()
    }

    private func finishClipboardImagePinShortcutRecording() {
        if let m = clipboardImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImagePinShortcutDisplay()
    }

    func cancelClipboardImagePinShortcutRecording() {
        guard clipboardImagePinShortcutRecordingMonitor != nil else { return }
        if let m = clipboardImagePinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImagePinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImagePinShortcutDisplay()
    }

    private func refreshClipboardImagePinShortcutDisplay() {
        clipboardImagePinShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardImagePinDisplayString() {
            clipboardImagePinShortcutField?.stringValue = display
            clipboardImagePinShortcutRestoreButton?.isHidden = false
        } else {
            clipboardImagePinShortcutField?.stringValue = L10n.clipboardImagePinShortcutDefaultDisplay
            clipboardImagePinShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func clipboardTextPinShortcutSetClicked() {
        if clipboardTextPinShortcutRecordingMonitor != nil {
            cancelClipboardTextPinShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboardTextPin)
        HotkeyManager.shared.beginRecording()
        clipboardTextPinShortcutSetButton.title = L10n.shortcutCancel
        clipboardTextPinShortcutField.stringValue = L10n.shortcutWaiting
        clipboardTextPinShortcutRestoreButton.isHidden = true

        clipboardTextPinShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardTextPinShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelClipboardTextPinShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboardTextPin) {
                self.cancelClipboardTextPinShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardTextPinHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardTextPinHotkeyModifiers = Int(carbonMods)
            self.finishClipboardTextPinShortcutRecording()
            return nil
        }
    }

    @objc private func clipboardTextPinShortcutRestoreClicked() {
        if clipboardTextPinShortcutRecordingMonitor != nil {
            cancelClipboardTextPinShortcutRecording()
        }
        Defaults.clearClipboardTextPinHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardTextPinShortcutDisplay()
    }

    private func finishClipboardTextPinShortcutRecording() {
        if let m = clipboardTextPinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardTextPinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardTextPinShortcutDisplay()
    }

    func cancelClipboardTextPinShortcutRecording() {
        guard clipboardTextPinShortcutRecordingMonitor != nil else { return }
        if let m = clipboardTextPinShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardTextPinShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardTextPinShortcutDisplay()
    }

    private func refreshClipboardTextPinShortcutDisplay() {
        clipboardTextPinShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardTextPinDisplayString() {
            clipboardTextPinShortcutField?.stringValue = display
            clipboardTextPinShortcutRestoreButton?.isHidden = false
        } else {
            clipboardTextPinShortcutField?.stringValue = L10n.clipboardTextPinShortcutDefaultDisplay
            clipboardTextPinShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func selectedImageEditShortcutSetClicked() {
        if selectedImageEditShortcutRecordingMonitor != nil {
            cancelSelectedImageEditShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .selectedImageEdit)
        HotkeyManager.shared.beginRecording()
        selectedImageEditShortcutSetButton.title = L10n.shortcutCancel
        selectedImageEditShortcutField.stringValue = L10n.shortcutWaiting
        selectedImageEditShortcutRestoreButton.isHidden = true

        selectedImageEditShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelSelectedImageEditShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelSelectedImageEditShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .selectedImageEdit) {
                self.cancelSelectedImageEditShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.selectedImageEditHotkeyKeyCode = Int(keyCode)
            Defaults.selectedImageEditHotkeyModifiers = Int(carbonMods)
            self.finishSelectedImageEditShortcutRecording()
            return nil
        }
    }

    @objc private func selectedImageEditShortcutRestoreClicked() {
        if selectedImageEditShortcutRecordingMonitor != nil {
            cancelSelectedImageEditShortcutRecording()
        }
        Defaults.clearSelectedImageEditHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshSelectedImageEditShortcutDisplay()
    }

    private func finishSelectedImageEditShortcutRecording() {
        if let m = selectedImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImageEditShortcutDisplay()
    }

    func cancelSelectedImageEditShortcutRecording() {
        guard selectedImageEditShortcutRecordingMonitor != nil else { return }
        if let m = selectedImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            selectedImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshSelectedImageEditShortcutDisplay()
    }

    private func refreshSelectedImageEditShortcutDisplay() {
        selectedImageEditShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentSelectedImageEditDisplayString() {
            selectedImageEditShortcutField?.stringValue = display
            selectedImageEditShortcutRestoreButton?.isHidden = false
        } else {
            selectedImageEditShortcutField?.stringValue = L10n.selectedImageEditShortcutDefaultDisplay
            selectedImageEditShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func clipboardImageEditShortcutSetClicked() {
        if clipboardImageEditShortcutRecordingMonitor != nil {
            cancelClipboardImageEditShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboardImageEdit)
        HotkeyManager.shared.beginRecording()
        clipboardImageEditShortcutSetButton.title = L10n.shortcutCancel
        clipboardImageEditShortcutField.stringValue = L10n.shortcutWaiting
        clipboardImageEditShortcutRestoreButton.isHidden = true

        clipboardImageEditShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardImageEditShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelClipboardImageEditShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboardImageEdit) {
                self.cancelClipboardImageEditShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardImageEditHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardImageEditHotkeyModifiers = Int(carbonMods)
            self.finishClipboardImageEditShortcutRecording()
            return nil
        }
    }

    @objc private func clipboardImageEditShortcutRestoreClicked() {
        if clipboardImageEditShortcutRecordingMonitor != nil {
            cancelClipboardImageEditShortcutRecording()
        }
        Defaults.clearClipboardImageEditHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardImageEditShortcutDisplay()
    }

    private func finishClipboardImageEditShortcutRecording() {
        if let m = clipboardImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImageEditShortcutDisplay()
    }

    func cancelClipboardImageEditShortcutRecording() {
        guard clipboardImageEditShortcutRecordingMonitor != nil else { return }
        if let m = clipboardImageEditShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardImageEditShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardImageEditShortcutDisplay()
    }

    private func refreshClipboardImageEditShortcutDisplay() {
        clipboardImageEditShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardImageEditDisplayString() {
            clipboardImageEditShortcutField?.stringValue = display
            clipboardImageEditShortcutRestoreButton?.isHidden = false
        } else {
            clipboardImageEditShortcutField?.stringValue = L10n.clipboardImageEditShortcutDefaultDisplay
            clipboardImageEditShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func textRecognitionShortcutSetClicked() {
        if textRecognitionShortcutRecordingMonitor != nil {
            cancelTextRecognitionShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .textRecognition)
        HotkeyManager.shared.beginRecording()
        textRecognitionShortcutSetButton.title = L10n.shortcutCancel
        textRecognitionShortcutField.stringValue = L10n.shortcutWaiting
        textRecognitionShortcutRestoreButton.isHidden = true

        textRecognitionShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelTextRecognitionShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelTextRecognitionShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .textRecognition) {
                self.cancelTextRecognitionShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.textRecognitionHotkeyKeyCode = Int(keyCode)
            Defaults.textRecognitionHotkeyModifiers = Int(carbonMods)
            self.finishTextRecognitionShortcutRecording()
            return nil
        }
    }

    @objc private func textRecognitionShortcutRestoreClicked() {
        if textRecognitionShortcutRecordingMonitor != nil {
            cancelTextRecognitionShortcutRecording()
        }
        Defaults.clearTextRecognitionHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshTextRecognitionShortcutDisplay()
    }

    private func finishTextRecognitionShortcutRecording() {
        if let m = textRecognitionShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            textRecognitionShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshTextRecognitionShortcutDisplay()
    }

    func cancelTextRecognitionShortcutRecording() {
        guard textRecognitionShortcutRecordingMonitor != nil else { return }
        if let m = textRecognitionShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            textRecognitionShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshTextRecognitionShortcutDisplay()
    }

    private func refreshTextRecognitionShortcutDisplay() {
        textRecognitionShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentTextRecognitionDisplayString() {
            textRecognitionShortcutField?.stringValue = display
            textRecognitionShortcutRestoreButton?.isHidden = false
        } else {
            textRecognitionShortcutField?.stringValue = L10n.textRecognitionShortcutDefaultDisplay
            textRecognitionShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func copyImageTextShortcutSetClicked() {
        if copyImageTextShortcutRecordingMonitor != nil {
            cancelCopyImageTextShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .copyImageText)
        HotkeyManager.shared.beginRecording()
        copyImageTextShortcutSetButton.title = L10n.shortcutCancel
        copyImageTextShortcutField.stringValue = L10n.shortcutWaiting
        copyImageTextShortcutRestoreButton.isHidden = true

        copyImageTextShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelCopyImageTextShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelCopyImageTextShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .copyImageText) {
                self.cancelCopyImageTextShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.copyImageTextHotkeyKeyCode = Int(keyCode)
            Defaults.copyImageTextHotkeyModifiers = Int(carbonMods)
            self.finishCopyImageTextShortcutRecording()
            return nil
        }
    }

    @objc private func copyImageTextShortcutRestoreClicked() {
        if copyImageTextShortcutRecordingMonitor != nil {
            cancelCopyImageTextShortcutRecording()
        }
        Defaults.clearCopyImageTextHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshCopyImageTextShortcutDisplay()
    }

    private func finishCopyImageTextShortcutRecording() {
        if let m = copyImageTextShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            copyImageTextShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshCopyImageTextShortcutDisplay()
    }

    func cancelCopyImageTextShortcutRecording() {
        guard copyImageTextShortcutRecordingMonitor != nil else { return }
        if let m = copyImageTextShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            copyImageTextShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshCopyImageTextShortcutDisplay()
    }

    private func refreshCopyImageTextShortcutDisplay() {
        copyImageTextShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentCopyImageTextDisplayString() {
            copyImageTextShortcutField?.stringValue = display
            copyImageTextShortcutRestoreButton?.isHidden = false
        } else {
            copyImageTextShortcutField?.stringValue = L10n.copyImageTextShortcutDefaultDisplay
            copyImageTextShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func screenshotTranslationShortcutSetClicked() {
        if screenshotTranslationShortcutRecordingMonitor != nil {
            cancelScreenshotTranslationShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .screenshotTranslation)
        HotkeyManager.shared.beginRecording()
        screenshotTranslationShortcutSetButton.title = L10n.shortcutCancel
        screenshotTranslationShortcutField.stringValue = L10n.shortcutWaiting
        screenshotTranslationShortcutRestoreButton.isHidden = true

        screenshotTranslationShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelScreenshotTranslationShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelScreenshotTranslationShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .screenshotTranslation) {
                self.cancelScreenshotTranslationShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.screenshotTranslationHotkeyKeyCode = Int(keyCode)
            Defaults.screenshotTranslationHotkeyModifiers = Int(carbonMods)
            self.finishScreenshotTranslationShortcutRecording()
            return nil
        }
    }

    @objc private func screenshotTranslationShortcutRestoreClicked() {
        if screenshotTranslationShortcutRecordingMonitor != nil {
            cancelScreenshotTranslationShortcutRecording()
        }
        Defaults.clearScreenshotTranslationHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshScreenshotTranslationShortcutDisplay()
    }

    private func finishScreenshotTranslationShortcutRecording() {
        if let m = screenshotTranslationShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            screenshotTranslationShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshScreenshotTranslationShortcutDisplay()
    }

    func cancelScreenshotTranslationShortcutRecording() {
        guard screenshotTranslationShortcutRecordingMonitor != nil else { return }
        if let m = screenshotTranslationShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            screenshotTranslationShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshScreenshotTranslationShortcutDisplay()
    }

    private func refreshScreenshotTranslationShortcutDisplay() {
        screenshotTranslationShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentScreenshotTranslationDisplayString() {
            screenshotTranslationShortcutField?.stringValue = display
            screenshotTranslationShortcutRestoreButton?.isHidden = false
        } else {
            screenshotTranslationShortcutField?.stringValue = L10n.screenshotTranslationShortcutDefaultDisplay
            screenshotTranslationShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func recordShortcutSetClicked() {
        if recordShortcutRecordingMonitor != nil {
            cancelRecordShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .record)
        HotkeyManager.shared.beginRecording()
        recordShortcutSetButton.title = L10n.shortcutCancel
        recordShortcutField.stringValue = L10n.shortcutWaiting
        recordShortcutRestoreButton.isHidden = true

        recordShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelRecordShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelRecordShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .record) {
                self.cancelRecordShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.recordHotkeyKeyCode = Int(keyCode)
            Defaults.recordHotkeyModifiers = Int(carbonMods)
            self.finishRecordShortcutRecording()
            return nil
        }
    }

    @objc private func recordShortcutRestoreClicked() {
        if recordShortcutRecordingMonitor != nil {
            cancelRecordShortcutRecording()
        }
        Defaults.clearRecordHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshRecordShortcutDisplay()
    }

    private func finishRecordShortcutRecording() {
        if let m = recordShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            recordShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshRecordShortcutDisplay()
    }

    func cancelRecordShortcutRecording() {
        guard recordShortcutRecordingMonitor != nil else { return }
        if let m = recordShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            recordShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshRecordShortcutDisplay()
    }

    private func refreshRecordShortcutDisplay() {
        recordShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentRecordDisplayString() {
            recordShortcutField?.stringValue = display
            recordShortcutRestoreButton?.isHidden = false
        } else {
            recordShortcutField?.stringValue = L10n.recordShortcutDefaultDisplay
            recordShortcutRestoreButton?.isHidden = true
        }
    }


    @objc private func clipboardShortcutSetClicked() {
        if clipboardShortcutRecordingMonitor != nil {
            cancelClipboardShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .clipboard)
        HotkeyManager.shared.beginRecording()
        clipboardShortcutSetButton.title = L10n.shortcutCancel
        clipboardShortcutField.stringValue = L10n.shortcutWaiting
        clipboardShortcutRestoreButton.isHidden = true

        clipboardShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelClipboardShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            // Unlike the screenshot/pin hotkeys, the editor hotkeys are
            // allowed to be bare — they only fire inside the editor overlay,
            // where typing is restricted to text-annotation editing (already
            // guarded against in the local key monitor).

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .clipboard) {
                self.cancelClipboardShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.clipboardHotkeyKeyCode = Int(keyCode)
            Defaults.clipboardHotkeyModifiers = Int(carbonMods)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
            self.finishClipboardShortcutRecording()
            return nil
        }
    }

    @objc private func clipboardShortcutRestoreClicked() {
        if clipboardShortcutRecordingMonitor != nil {
            cancelClipboardShortcutRecording()
        }
        Defaults.clearClipboardHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshClipboardShortcutDisplay()
    }

    private func finishClipboardShortcutRecording() {
        if let m = clipboardShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardShortcutDisplay()
    }

    func cancelClipboardShortcutRecording() {
        guard clipboardShortcutRecordingMonitor != nil else { return }
        if let m = clipboardShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            clipboardShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshClipboardShortcutDisplay()
    }

    private func refreshClipboardShortcutDisplay() {
        clipboardShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentClipboardDisplayString() {
            clipboardShortcutField?.stringValue = display
            clipboardShortcutRestoreButton?.isHidden = false
        } else {
            clipboardShortcutField?.stringValue = L10n.clipboardShortcutDefaultDisplay
            clipboardShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func fileSaveShortcutSetClicked() {
        if fileSaveShortcutRecordingMonitor != nil {
            cancelFileSaveShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .fileSave)
        HotkeyManager.shared.beginRecording()
        fileSaveShortcutSetButton.title = L10n.shortcutCancel
        fileSaveShortcutField.stringValue = L10n.shortcutWaiting
        fileSaveShortcutRestoreButton.isHidden = true

        fileSaveShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelFileSaveShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .fileSave) {
                self.cancelFileSaveShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.fileSaveHotkeyKeyCode = Int(keyCode)
            Defaults.fileSaveHotkeyModifiers = Int(carbonMods)
            self.finishFileSaveShortcutRecording()
            return nil
        }
    }

    @objc private func fileSaveShortcutRestoreClicked() {
        if fileSaveShortcutRecordingMonitor != nil {
            cancelFileSaveShortcutRecording()
        }
        Defaults.clearFileSaveHotkey()
        refreshFileSaveShortcutDisplay()
    }

    private func finishFileSaveShortcutRecording() {
        if let m = fileSaveShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            fileSaveShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshFileSaveShortcutDisplay()
    }

    func cancelFileSaveShortcutRecording() {
        guard fileSaveShortcutRecordingMonitor != nil else { return }
        if let m = fileSaveShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            fileSaveShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshFileSaveShortcutDisplay()
    }

    private func refreshFileSaveShortcutDisplay() {
        fileSaveShortcutSetButton?.title = L10n.shortcutSet
        fileSaveShortcutField?.stringValue = HotkeyManager.currentFileSaveDisplayString()
        fileSaveShortcutRestoreButton?.isHidden = !Defaults.hasCustomFileSaveHotkey
    }

    @objc private func previousHistoryImageShortcutSetClicked() {
        if previousHistoryImageShortcutRecordingMonitor != nil {
            cancelPreviousHistoryImageShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .previousHistoryImage)
        HotkeyManager.shared.beginRecording()
        previousHistoryImageShortcutSetButton.title = L10n.shortcutCancel
        previousHistoryImageShortcutField.stringValue = L10n.shortcutWaiting
        previousHistoryImageShortcutRestoreButton.isHidden = true

        previousHistoryImageShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelPreviousHistoryImageShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .previousHistoryImage) {
                self.cancelPreviousHistoryImageShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.previousHistoryImageHotkeyKeyCode = Int(keyCode)
            Defaults.previousHistoryImageHotkeyModifiers = Int(carbonMods)
            self.finishPreviousHistoryImageShortcutRecording()
            return nil
        }
    }

    @objc private func previousHistoryImageShortcutRestoreClicked() {
        if previousHistoryImageShortcutRecordingMonitor != nil {
            cancelPreviousHistoryImageShortcutRecording()
        }
        Defaults.clearPreviousHistoryImageHotkey()
        refreshPreviousHistoryImageShortcutDisplay()
    }

    private func finishPreviousHistoryImageShortcutRecording() {
        if let m = previousHistoryImageShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            previousHistoryImageShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshPreviousHistoryImageShortcutDisplay()
    }

    func cancelPreviousHistoryImageShortcutRecording() {
        guard previousHistoryImageShortcutRecordingMonitor != nil else { return }
        if let m = previousHistoryImageShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            previousHistoryImageShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshPreviousHistoryImageShortcutDisplay()
    }

    private func refreshPreviousHistoryImageShortcutDisplay() {
        previousHistoryImageShortcutSetButton?.title = L10n.shortcutSet
        previousHistoryImageShortcutField?.stringValue = HotkeyManager.currentPreviousHistoryImageDisplayString()
        previousHistoryImageShortcutRestoreButton?.isHidden = !Defaults.hasCustomPreviousHistoryImageHotkey
    }

    @objc private func nextHistoryImageShortcutSetClicked() {
        if nextHistoryImageShortcutRecordingMonitor != nil {
            cancelNextHistoryImageShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .nextHistoryImage)
        HotkeyManager.shared.beginRecording()
        nextHistoryImageShortcutSetButton.title = L10n.shortcutCancel
        nextHistoryImageShortcutField.stringValue = L10n.shortcutWaiting
        nextHistoryImageShortcutRestoreButton.isHidden = true

        nextHistoryImageShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelNextHistoryImageShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .nextHistoryImage) {
                self.cancelNextHistoryImageShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.nextHistoryImageHotkeyKeyCode = Int(keyCode)
            Defaults.nextHistoryImageHotkeyModifiers = Int(carbonMods)
            self.finishNextHistoryImageShortcutRecording()
            return nil
        }
    }

    @objc private func nextHistoryImageShortcutRestoreClicked() {
        if nextHistoryImageShortcutRecordingMonitor != nil {
            cancelNextHistoryImageShortcutRecording()
        }
        Defaults.clearNextHistoryImageHotkey()
        refreshNextHistoryImageShortcutDisplay()
    }

    private func finishNextHistoryImageShortcutRecording() {
        if let m = nextHistoryImageShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            nextHistoryImageShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshNextHistoryImageShortcutDisplay()
    }

    func cancelNextHistoryImageShortcutRecording() {
        guard nextHistoryImageShortcutRecordingMonitor != nil else { return }
        if let m = nextHistoryImageShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            nextHistoryImageShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshNextHistoryImageShortcutDisplay()
    }

    private func refreshNextHistoryImageShortcutDisplay() {
        nextHistoryImageShortcutSetButton?.title = L10n.shortcutSet
        nextHistoryImageShortcutField?.stringValue = HotkeyManager.currentNextHistoryImageDisplayString()
        nextHistoryImageShortcutRestoreButton?.isHidden = !Defaults.hasCustomNextHistoryImageHotkey
    }

    @objc private func historyPanelShortcutSetClicked() {
        if historyPanelShortcutRecordingMonitor != nil {
            cancelHistoryPanelShortcutRecording()
            return
        }
        cancelShortcutRecordings(except: .historyPanel)
        HotkeyManager.shared.beginRecording()
        historyPanelShortcutSetButton.title = L10n.shortcutCancel
        historyPanelShortcutField.stringValue = L10n.shortcutWaiting
        historyPanelShortcutRestoreButton.isHidden = true

        historyPanelShortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let modifiers = event.modifierFlags
            let isEscape = event.keyCode == UInt16(kVK_Escape)
            let activeModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
            let pressedModifiers = modifiers.intersection(activeModifierMask)

            if isEscape && pressedModifiers.isEmpty {
                self.cancelHistoryPanelShortcutRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
            if modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            let keyCode = UInt32(event.keyCode)

            if carbonMods == 0 && !HotkeyManager.isFunctionKey(keyCode) {
                self.cancelHistoryPanelShortcutRecording()
                self.presentShortcutNeedsModifierAlert()
                return nil
            }

            if let conflict = HotkeyManager.shared.hotkeyConflictMessage(
                forKeyCode: keyCode, modifiers: carbonMods, assigningTo: .historyPanel) {
                self.cancelHistoryPanelShortcutRecording()
                self.presentHotkeyConflictAlert(conflict)
                return nil
            }

            Defaults.historyPanelHotkeyKeyCode = Int(keyCode)
            Defaults.historyPanelHotkeyModifiers = Int(carbonMods)
            self.finishHistoryPanelShortcutRecording()
            return nil
        }
    }

    @objc private func historyPanelShortcutRestoreClicked() {
        if historyPanelShortcutRecordingMonitor != nil {
            cancelHistoryPanelShortcutRecording()
        }
        Defaults.clearHistoryPanelHotkey()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshHistoryPanelShortcutDisplay()
    }

    private func finishHistoryPanelShortcutRecording() {
        if let m = historyPanelShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            historyPanelShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshHistoryPanelShortcutDisplay()
    }

    func cancelHistoryPanelShortcutRecording() {
        guard historyPanelShortcutRecordingMonitor != nil else { return }
        if let m = historyPanelShortcutRecordingMonitor {
            NSEvent.removeMonitor(m)
            historyPanelShortcutRecordingMonitor = nil
        }
        HotkeyManager.shared.endRecording()
        refreshHistoryPanelShortcutDisplay()
    }

    private func refreshHistoryPanelShortcutDisplay() {
        historyPanelShortcutSetButton?.title = L10n.shortcutSet
        if let display = HotkeyManager.currentHistoryPanelDisplayString() {
            historyPanelShortcutField?.stringValue = display
            historyPanelShortcutRestoreButton?.isHidden = false
        } else {
            historyPanelShortcutField?.stringValue = L10n.historyPanelShortcutDefaultDisplay
            historyPanelShortcutRestoreButton?.isHidden = true
        }
    }

    @objc private func shortcutsResetClicked() {
        cancelShortcutRecording()
        cancelFullScreenScreenshotShortcutRecording()
        cancelQuickPinShortcutRecording()
        cancelSelectedImagePinShortcutRecording()
        cancelClipboardImagePinShortcutRecording()
        cancelClipboardTextPinShortcutRecording()
        cancelSelectedImageEditShortcutRecording()
        cancelClipboardImageEditShortcutRecording()
        cancelTextRecognitionShortcutRecording()
        cancelCopyImageTextShortcutRecording()
        cancelScreenshotTranslationShortcutRecording()
        cancelRecordShortcutRecording()
        cancelClipboardShortcutRecording()
        cancelFileSaveShortcutRecording()
        cancelPreviousHistoryImageShortcutRecording()
        cancelNextHistoryImageShortcutRecording()
        cancelHistoryPanelShortcutRecording()

        Defaults.resetShortcutHotkeysToDefaults()
        NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        refreshShortcutDisplay()
        refreshFullScreenScreenshotShortcutDisplay()
        refreshQuickPinShortcutDisplay()
        refreshSelectedImagePinShortcutDisplay()
        refreshClipboardImagePinShortcutDisplay()
        refreshClipboardTextPinShortcutDisplay()
        refreshSelectedImageEditShortcutDisplay()
        refreshClipboardImageEditShortcutDisplay()
        refreshTextRecognitionShortcutDisplay()
        refreshCopyImageTextShortcutDisplay()
        refreshScreenshotTranslationShortcutDisplay()
        refreshRecordShortcutDisplay()
        refreshClipboardShortcutDisplay()
        refreshFileSaveShortcutDisplay()
        refreshPreviousHistoryImageShortcutDisplay()
        refreshNextHistoryImageShortcutDisplay()
        refreshHistoryPanelShortcutDisplay()
    }

    @objc private func updateLocalization() {
        permissionFlowController.setLocaleIdentifier(Defaults.language.lprojName)
        updateMicrophoneControlsEnabled()
        menuBarTitleLabel?.stringValue = L10n.showMenuBarIcon
        launchAtLoginTitleLabel?.stringValue = L10n.launchAtLogin
        pinAcrossSpacesTitleLabel?.stringValue = L10n.pinAcrossSpaces
        pinAcrossSpacesSubtitleLabel?.stringValue = L10n.pinAcrossSpacesHint
        pinAcrossSpacesSwitch?.state = Defaults.pinAcrossSpaces ? .on : .off
        showCopyToastTitleLabel?.stringValue = L10n.showCopyToast
        showCopyToastSubtitleLabel?.stringValue = L10n.showCopyToastHint
        showCopyToastSwitch?.state = Defaults.showCopyToast ? .on : .off
        langTitleLabel?.stringValue = L10n.languageHeader
        filenameRuleCard?.refreshLocalization()
        screenshotQualityTitleLabel?.stringValue = L10n.screenshotQualityTitle
        screenshotQualitySubtitleLabel?.stringValue = L10n.screenshotQualitySubtitle
        screenshotQualityTitleLabel?.toolTip = L10n.screenshotQualitySubtitle
        screenshotQualitySaveTitleLabel?.stringValue = L10n.screenshotQualitySaveLabel
        screenshotQualityClipboardTitleLabel?.stringValue = L10n.screenshotQualityClipboardLabel
        refreshScreenshotQualityControls()
        savePathTitleLabel?.stringValue = L10n.savePathTitle
        savePathSubtitleLabel?.stringValue = L10n.savePathSubtitle
        savePathTitleLabel?.toolTip = L10n.savePathSubtitle
        askSaveLocationTitleLabel?.stringValue = L10n.askSaveLocationLabel
        askSaveLocationHintLabel?.stringValue = L10n.askSaveLocationHint
        askSaveLocationTitleLabel?.toolTip = L10n.askSaveLocationHint
        askSaveLocationSwitch?.toolTip = L10n.askSaveLocationHint
        askSaveLocationSwitch?.state = Defaults.askSaveLocation ? .on : .off
        autoRevealSavedFilesTitleLabel?.stringValue = L10n.autoRevealSavedFilesLabel
        autoRevealSavedFilesHintLabel?.stringValue = L10n.autoRevealSavedFilesHint
        autoRevealSavedFilesTitleLabel?.toolTip = L10n.autoRevealSavedFilesHint
        autoRevealSavedFilesSwitch?.toolTip = L10n.autoRevealSavedFilesHint
        autoRevealSavedFilesSwitch?.state = Defaults.autoRevealSavedFiles ? .on : .off
        recordingSavePathTitleLabel?.stringValue = L10n.recordingSavePathLabel
        recordingSaveFormatTitleLabel?.stringValue = L10n.recordingSaveFormatSettingLabel
        recordingSystemAudioTitleLabel?.stringValue = L10n.recordingSystemAudioLabel
        recordingSystemAudioHintLabel?.stringValue = L10n.recordingSystemAudioHint
        recordingMicrophoneTitleLabel?.stringValue = L10n.recordingMicrophoneLabel
        recordingMicrophoneHintLabel?.stringValue = L10n.recordingMicrophoneHint
        recordingSystemAudioSwitch?.state = Defaults.recordingSystemAudioEnabled ? .on : .off
        recordingMicrophoneSwitch?.state = Defaults.recordingMicrophoneEnabled ? .on : .off
        recordingMicrophoneDeviceTitleLabel?.stringValue = L10n.recordingMicrophoneDeviceLabel
        refreshMicrophoneDevicePopup()
        screenshotSavePathTitleLabel?.stringValue = L10n.screenshotSavePathLabel
        recordingSavePathChooseButton?.title = L10n.savePathChoose
        recordingSavePathRevealButton?.title = L10n.savePathReveal
        screenshotSavePathChooseButton?.title = L10n.savePathChoose
        screenshotSavePathRevealButton?.title = L10n.savePathReveal
        refreshSavePathControls()
        accessibilityNameLabel?.stringValue = L10n.accessibilityPermission
        accessibilityDescLabel?.stringValue = L10n.accessibilityDescription
        screenRecordingNameLabel?.stringValue = L10n.screenRecordingPermission
        screenRecordingDescLabel?.stringValue = L10n.screenRecordingDescription
        microphoneNameLabel?.stringValue = L10n.microphonePermission
        microphoneDescLabel?.stringValue = L10n.microphoneDescription
        historyCacheToggleTitleLabel?.stringValue = L10n.historyCacheToggleLabel
        historyCacheToggleHintLabel?.stringValue = L10n.historyCacheToggleHint
        historyCacheTitleLabel?.stringValue = L10n.historyCacheLabel
        historyPanelDisplayModeTitleLabel?.stringValue = L10n.historyPanelDisplayModeLabel
        historyPanelDisplayModeHintLabel?.stringValue = L10n.historyPanelDisplayModeHint
        historyPanelDialogModeTitleLabel?.stringValue = L10n.historyPanelDialogMode
        historyPanelDialogModeHintLabel?.stringValue = L10n.historyPanelDialogModeHint
        historyPanelNotchModeTitleLabel?.stringValue = L10n.historyPanelNotchMode
        historyPanelNotchModeHintLabel?.stringValue = L10n.historyPanelNotchModeHint
        historyNotchTriggerLabel?.stringValue = L10n.historyNotchTriggerLabel
        historyNotchTriggerPopup?.setAccessibilityLabel(L10n.historyNotchTriggerLabel)
        for (index, mode) in Defaults.HistoryNotchTriggerMode.allCases.enumerated() {
            historyNotchTriggerPopup?.item(at: index)?.title = mode.localizedTitle
        }
        updateHistoryPanelModeControlsEnabled()
        windowShadowTitleLabel?.stringValue = L10n.windowShadowToggleLabel
        windowShadowSubtitleLabel?.stringValue = L10n.windowShadowToggleHint
        windowShadowSizeTitleLabel?.stringValue = L10n.shadowSizeLabel
        windowShadowSizeHintLabel?.stringValue = L10n.windowShadowSizeHint
        countdownTitleLabel?.stringValue = L10n.countdownLabel
        countdownHintLabel?.stringValue = L10n.countdownHint
        countdownValueLabel?.stringValue = "\(Defaults.countdownSeconds)\(L10n.countdownSecondsSuffix)"
        shortcutTitleLabel?.stringValue = L10n.shortcutHeader
        shortcutRestoreButton?.toolTip = L10n.shortcutRestore
        fullScreenScreenshotShortcutTitleLabel?.stringValue = L10n.fullScreenScreenshotShortcutHeader
        fullScreenScreenshotShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        quickPinShortcutTitleLabel?.stringValue = L10n.quickPinShortcutHeader
        quickPinShortcutRestoreButton?.toolTip = L10n.quickPinShortcutClear
        selectedImagePinShortcutTitleLabel?.stringValue = L10n.selectedImagePinShortcutHeader
        selectedImagePinShortcutRestoreButton?.toolTip = L10n.selectedImagePinShortcutClear
        clipboardImagePinShortcutTitleLabel?.stringValue = L10n.clipboardImagePinShortcutHeader
        clipboardImagePinShortcutRestoreButton?.toolTip = L10n.clipboardImagePinShortcutClear
        clipboardTextPinShortcutTitleLabel?.stringValue = L10n.clipboardTextPinShortcutHeader
        clipboardTextPinShortcutRestoreButton?.toolTip = L10n.clipboardTextPinShortcutClear
        selectedImageEditShortcutTitleLabel?.stringValue = L10n.selectedImageEditShortcutHeader
        selectedImageEditShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        clipboardImageEditShortcutTitleLabel?.stringValue = L10n.clipboardImageEditShortcutHeader
        clipboardImageEditShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        textRecognitionShortcutTitleLabel?.stringValue = L10n.textRecognitionShortcutHeader
        textRecognitionShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        copyImageTextShortcutTitleLabel?.stringValue = L10n.copyImageTextShortcutHeader
        copyImageTextShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        screenshotTranslationShortcutTitleLabel?.stringValue = L10n.screenshotTranslationShortcutHeader
        screenshotTranslationShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        recordShortcutTitleLabel?.stringValue = L10n.recordShortcutHeader
        recordShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        clipboardShortcutTitleLabel?.stringValue = L10n.clipboardShortcutHeader
        clipboardShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        fileSaveShortcutTitleLabel?.stringValue = L10n.fileSaveShortcutHeader
        fileSaveShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        previousHistoryImageShortcutTitleLabel?.stringValue = L10n.previousHistoryImageShortcutHeader
        previousHistoryImageShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        nextHistoryImageShortcutTitleLabel?.stringValue = L10n.nextHistoryImageShortcutHeader
        nextHistoryImageShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        historyPanelShortcutTitleLabel?.stringValue = L10n.historyPanelShortcutHeader
        historyPanelShortcutRestoreButton?.toolTip = L10n.shortcutRestore
        shortcutResetButton?.title = L10n.toolbarSettingsReset
        aboutTaglineLabel?.stringValue = L10n.aboutTagline
        aboutLicenseTitleLabel?.stringValue = L10n.aboutLicense
        aboutSourceTitleLabel?.stringValue = L10n.aboutSourceCode
        aboutUpdateTitleLabel?.stringValue = L10n.aboutUpdateTitle
        errorLogTitleLabel?.stringValue = L10n.aboutErrorLog
        errorLogCopyButton?.title = L10n.aboutErrorLogCopy
        errorLogRevealButton?.title = L10n.aboutErrorLogReveal
        errorLogRefreshButton?.title = L10n.aboutErrorLogRefresh
        errorLogClearButton?.title = L10n.aboutErrorLogClear
        if errorLogLoaded, errorLogEntry == nil {
            errorLogTextView?.string = L10n.aboutErrorLogEmptyBody
        }
        refreshErrorLogStatus()
        refreshUpdateRow()
        refreshShortcutDisplay()
        refreshFullScreenScreenshotShortcutDisplay()
        refreshQuickPinShortcutDisplay()
        refreshSelectedImagePinShortcutDisplay()
        refreshClipboardImagePinShortcutDisplay()
        refreshClipboardTextPinShortcutDisplay()
        refreshSelectedImageEditShortcutDisplay()
        refreshClipboardImageEditShortcutDisplay()
        refreshTextRecognitionShortcutDisplay()
        refreshCopyImageTextShortcutDisplay()
        refreshScreenshotTranslationShortcutDisplay()
        refreshRecordShortcutDisplay()
        refreshClipboardShortcutDisplay()
        refreshFileSaveShortcutDisplay()
        refreshPreviousHistoryImageShortcutDisplay()
        refreshNextHistoryImageShortcutDisplay()
        refreshHistoryPanelShortcutDisplay()
        refreshBottomAction()
        accessibilityBadge?.refreshTitle()
        screenRecordingBadge?.refreshTitle()
        microphoneBadge?.refreshTitle()
        navigation.setAccessibilityLabel(L10n.settingsTitle)
        isUpdatingNavigationSelection = true
        navigation.reloadData()
        isUpdatingNavigationSelection = false
        refreshNavigationSelection(scrollToSelection: false)
        detailTitleLabel?.stringValue = selectedTab.title
        window?.title = L10n.settingsTitle
    }
}

// MARK: - Flipped view (top-aligned scroll content)

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Live preview of the window-capture shadow: a small window-like card
/// floating on a desktop-like backdrop. The shadow scales with `shadowSize`
/// so the user sees how high the captured window will appear to float.
private final class ShadowPreviewView: NSView {
    var shadowSize: CGFloat = 22 { didSet { needsDisplay = true } }
    var isEffectEnabled: Bool = true { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let backdrop = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        backdrop.addClip()

        // Desktop-like light backdrop so the dark shadow stays visible
        // (the settings UI itself is dark).
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.74, green: 0.78, blue: 0.85, alpha: 1),
            NSColor(calibratedRed: 0.60, green: 0.64, blue: 0.72, alpha: 1)
        ])
        gradient?.draw(in: bounds, angle: -90)

        // Window card geometry, centered; floats higher as the shadow grows.
        let cardW = min(bounds.width * 0.56, 210)
        let cardH: CGFloat = 64
        let lift = isEffectEnabled ? min(shadowSize, 60) * 0.10 : 0
        let cardRect = NSRect(
            x: ((bounds.width - cardW) / 2).rounded(),
            y: ((bounds.height - cardH) / 2 + lift).rounded(),
            width: cardW,
            height: cardH
        )
        let radius: CGFloat = 9
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)

        guard let ctx = NSGraphicsContext.current else { return }

        // Shadow pass. Scaled down relative to the real export — the preview
        // card is tiny — but proportional, so the slider's effect reads.
        ctx.saveGraphicsState()
        if isEffectEnabled, shadowSize > 0 {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
            shadow.shadowBlurRadius = shadowSize * 0.62
            shadow.shadowOffset = NSSize(width: 0, height: -shadowSize * 0.30)
            shadow.set()
        }
        NSColor.white.setFill()
        cardPath.fill()
        ctx.restoreGraphicsState()

        // Title-bar strip + traffic-light dots, clipped to the card.
        ctx.saveGraphicsState()
        cardPath.addClip()
        NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(
            x: cardRect.minX, y: cardRect.maxY - 16,
            width: cardRect.width, height: 16
        )).fill()
        let dotColors: [NSColor] = [
            NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.35, alpha: 1),
            NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.31, green: 0.79, blue: 0.31, alpha: 1)
        ]
        for (i, color) in dotColors.enumerated() {
            color.setFill()
            let d: CGFloat = 7
            NSBezierPath(ovalIn: NSRect(
                x: cardRect.minX + 9 + CGFloat(i) * 12,
                y: cardRect.maxY - 11.5, width: d, height: d
            )).fill()
        }
        ctx.restoreGraphicsState()

        // Hairline border for crispness.
        NSColor.black.withAlphaComponent(0.08).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()
    }
}

private final class HistoryPanelModePreviewView: NSView {
    var mode: HistoryPanelSettingsMode {
        didSet { needsDisplay = true }
    }

    var isEffectEnabled: Bool = true {
        didSet { needsDisplay = true }
    }

    init(mode: HistoryPanelSettingsMode) {
        self.mode = mode
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current else { return }

        let rect = bounds
        let backdrop = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
        ctx.saveGraphicsState()
        backdrop.addClip()

        NSColor.controlBackgroundColor.setFill()
        backdrop.fill()
        ctx.cgContext.setAlpha(isEffectEnabled ? 1 : 0.42)
        switch mode {
        case .dialog:
            drawDialogPreview(in: rect.insetBy(dx: 24, dy: 18))
        case .notch:
            drawNotchPreview(in: rect.insetBy(dx: 24, dy: 0))
        }
        ctx.restoreGraphicsState()

        NSColor.separatorColor.setStroke()
        backdrop.lineWidth = 1
        backdrop.stroke()
    }

    private func drawDialogPreview(in rect: NSRect) {
        let panelWidth = min(rect.width * 0.82, 560)
        let panelHeight = min(rect.height - 14, 86)
        let panelRect = NSRect(
            x: rect.midX - panelWidth / 2,
            y: rect.midY - panelHeight / 2 - 6,
            width: panelWidth,
            height: panelHeight
        )
        drawFloatingSurface(in: panelRect, radius: 18, shadow: true)
        drawToolbarLine(in: panelRect)
        drawTileRow(in: panelRect.insetBy(dx: 18, dy: 16), count: 4)
    }

    private func drawNotchPreview(in rect: NSRect) {
        let panelWidth = min(rect.width * 0.88, 620)
        let panelHeight = min(rect.height * 0.78, 106)
        let panelRect = NSRect(
            x: rect.midX - panelWidth / 2,
            y: rect.maxY - panelHeight,
            width: panelWidth,
            height: panelHeight
        )

        drawTopAttachedSurface(in: panelRect)

        drawToolbarLine(in: panelRect, leadingInset: 36, darkSurface: true)
        drawTileRow(in: panelRect.insetBy(dx: 34, dy: 16), count: 5, darkSurface: true)
    }

    private func drawFloatingSurface(in rect: NSRect, radius: CGFloat, shadow: Bool) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        guard let ctx = NSGraphicsContext.current else { return }
        ctx.saveGraphicsState()
        if shadow {
            let panelShadow = NSShadow()
            panelShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
            panelShadow.shadowBlurRadius = 18
            panelShadow.shadowOffset = NSSize(width: 0, height: -6)
            panelShadow.set()
        }
        NSColor.windowBackgroundColor.setFill()
        path.fill()
        ctx.restoreGraphicsState()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawTopAttachedSurface(in rect: NSRect) {
        let path = notchPath(in: rect, flare: 14, bottomRadius: 18)
        NSColor.black.setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.14).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawToolbarLine(in panelRect: NSRect, leadingInset: CGFloat = 18, darkSurface: Bool = false) {
        let y = panelRect.maxY - 22
        let active = NSRect(x: panelRect.minX + leadingInset, y: y, width: 46, height: 10)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: active, xRadius: 5, yRadius: 5).fill()

        var x = active.maxX + 10
        for _ in 0..<3 {
            let pill = NSRect(x: x, y: y, width: 34, height: 10)
            (darkSurface ? NSColor.white.withAlphaComponent(0.16) : .tertiarySystemFill).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 5, yRadius: 5).fill()
            x += 44
        }
    }

    private func drawTileRow(in rect: NSRect, count: Int, darkSurface: Bool = false) {
        let contentRect = NSRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: max(28, rect.height - 28)
        )
        let gap: CGFloat = 10
        let tileWidth = max(34, (contentRect.width - gap * CGFloat(count - 1)) / CGFloat(count))
        for index in 0..<count {
            let tileRect = NSRect(
                x: contentRect.minX + CGFloat(index) * (tileWidth + gap),
                y: contentRect.minY,
                width: tileWidth,
                height: contentRect.height
            )
            (darkSurface ? NSColor.white.withAlphaComponent(0.10) : .quaternarySystemFill).setFill()
            NSBezierPath(roundedRect: tileRect, xRadius: 8, yRadius: 8).fill()

            let bar = NSRect(
                x: tileRect.minX + 8,
                y: tileRect.midY - 4,
                width: max(18, tileRect.width - 16),
                height: 8
            )
            let fill = darkSurface ? NSColor.white.withAlphaComponent(0.24) : .tertiarySystemFill
            (index == 0 ? NSColor.controlAccentColor : fill).setFill()
            NSBezierPath(roundedRect: bar, xRadius: 4, yRadius: 4).fill()
        }
    }

    private func notchPath(in rect: NSRect, flare: CGFloat, bottomRadius: CGFloat) -> NSBezierPath {
        let flare = max(0, min(flare, rect.width * 0.25, rect.height))
        let bodyLeft = rect.minX + flare
        let bodyRight = rect.maxX - flare
        let bottom = max(0, min(bottomRadius, (bodyRight - bodyLeft) * 0.5, rect.height))
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        path.curve(
            to: NSPoint(x: bodyRight, y: rect.maxY - flare),
            controlPoint1: NSPoint(x: rect.maxX - flare * 0.5, y: rect.maxY),
            controlPoint2: NSPoint(x: bodyRight, y: rect.maxY - flare * 0.5)
        )
        path.line(to: NSPoint(x: bodyRight, y: rect.minY + bottom))
        path.curve(
            to: NSPoint(x: bodyRight - bottom, y: rect.minY),
            controlPoint1: NSPoint(x: bodyRight, y: rect.minY + bottom * 0.45),
            controlPoint2: NSPoint(x: bodyRight - bottom * 0.45, y: rect.minY)
        )
        path.line(to: NSPoint(x: bodyLeft + bottom, y: rect.minY))
        path.curve(
            to: NSPoint(x: bodyLeft, y: rect.minY + bottom),
            controlPoint1: NSPoint(x: bodyLeft + bottom * 0.45, y: rect.minY),
            controlPoint2: NSPoint(x: bodyLeft, y: rect.minY + bottom * 0.45)
        )
        path.line(to: NSPoint(x: bodyLeft, y: rect.maxY - flare))
        path.curve(
            to: NSPoint(x: rect.minX, y: rect.maxY),
            controlPoint1: NSPoint(x: bodyLeft, y: rect.maxY - flare * 0.5),
            controlPoint2: NSPoint(x: rect.minX + flare * 0.5, y: rect.maxY)
        )
        path.close()
        return path
    }

}

private final class HistoryPanelModeOptionView: NSControl {
    let mode: HistoryPanelSettingsMode
    let title: NSTextField
    let subtitle: NSTextField

    var isSelected: Bool = false {
        didSet { applyAppearance() }
    }

    override var isEnabled: Bool {
        didSet { applyAppearance() }
    }

    private let checkView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { applyAppearance() }
    }

    init(mode: HistoryPanelSettingsMode, title: String, subtitle: String) {
        self.mode = mode
        self.title = NSTextField(labelWithString: title)
        self.subtitle = NSTextField(wrappingLabelWithString: subtitle)
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.cornerCurve = .continuous

        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.isEditable = false
        title.isSelectable = false
        title.refusesFirstResponder = true
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        subtitle.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        subtitle.isEditable = false
        subtitle.isSelectable = false
        subtitle.refusesFirstResponder = true
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitle)

        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        checkView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        checkView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(checkView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 92),

            checkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            checkView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            checkView.widthAnchor.constraint(equalToConstant: 18),
            checkView.heightAnchor.constraint(equalToConstant: 18),

            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            title.trailingAnchor.constraint(lessThanOrEqualTo: checkView.leadingAnchor, constant: -8),

            subtitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            subtitle.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
        ])

        setContentCompressionResistancePriority(.required, for: .vertical)
        setAccessibilityElement(true)
        setAccessibilityRole(.radioButton)
        setAccessibilityTitleUIElement(title)
        applyAppearance()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        guard let result else { return nil }
        return result === self ? result : self
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        sendAction(action, to: target)
    }

    override var acceptsFirstResponder: Bool { isEnabled }

    override func accessibilityValue() -> Any? {
        isSelected ? 1 : 0
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEnabled else { return false }
        return sendAction(action, to: target)
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        let keyCode = Int(event.keyCode)
        if keyCode == kVK_Space || keyCode == kVK_Return {
            sendAction(action, to: target)
        } else {
            super.keyDown(with: event)
        }
    }

    private func applyAppearance() {
        let enabledAlpha: CGFloat = isEnabled ? 1 : 0.42
        let accent = NSColor.controlAccentColor
        let fill: NSColor = isSelected || isHovered ? .quaternarySystemFill : .clear
        let border: NSColor = isSelected ? accent : .separatorColor
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(fill, for: effectiveAppearance)
        layer?.borderColor = AdaptiveChrome.resolvedCGColor(border, for: effectiveAppearance)
        layer?.borderWidth = isSelected ? 2 : 1

        title.textColor = isEnabled ? .labelColor : .tertiaryLabelColor
        subtitle.textColor = isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
        checkView.isHidden = !isSelected
        checkView.contentTintColor = accent.withAlphaComponent(enabledAlpha)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }
}

class SettingsGroupView: NSBox {
    let content = NSView()

    init() {
        super.init(frame: .zero)
        boxType = .custom
        titlePosition = .noTitle
        borderWidth = 0
        fillColor = .quaternarySystemFill
        cornerRadius = 12
        contentViewMargins = .zero
        contentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Status badge

final class StatusBadge: NSView {
    private let label = NSTextField(labelWithString: "")
    private var granted: Bool = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.cornerCurve = .continuous
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func configure(granted: Bool) {
        self.granted = granted
        refreshTitle()
    }

    func refreshTitle() {
        let color: NSColor = granted ? .systemGreen : .systemOrange
        label.stringValue = granted ? L10n.permissionGranted : L10n.permissionNotGranted
        label.textColor = color
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(color.withAlphaComponent(0.14), for: effectiveAppearance)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshTitle()
    }
}

// MARK: - Hover button (clickable permission row)

private final class HoverButton: NSButton {
    var cornerRadius: CGFloat = 10 {
        didSet { layer?.cornerRadius = cornerRadius }
    }
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.clear.cgColor
        (cell as? NSButtonCell)?.highlightsBy = []
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(.quaternarySystemFill, for: effectiveAppearance)
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(.tertiarySystemFill, for: effectiveAppearance)
        super.mouseDown(with: event)
        layer?.backgroundColor = AdaptiveChrome.resolvedCGColor(.quaternarySystemFill, for: effectiveAppearance)
    }
}
