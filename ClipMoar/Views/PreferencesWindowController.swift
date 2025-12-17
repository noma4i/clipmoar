import Carbon
import Cocoa

// MARK: - Window Controller

final class PreferencesWindowController: NSWindowController {
    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void, hotkeyRecorder: HotkeyRecorder) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 540),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 860, height: 540)
        window.setAccessibilityIdentifier("preferences_window")

        let splitVC = PreferencesSplitViewController(
            settings: settings,
            onVisibilityChange: onVisibilityChange,
            hotkeyRecorder: hotkeyRecorder
        )
        window.contentViewController = splitVC
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

// MARK: - Split View

final class PreferencesSplitViewController: NSSplitViewController {
    private let sidebarVC: PreferencesSidebarViewController
    private let tabs: [PreferencesTab]

    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void, hotkeyRecorder: HotkeyRecorder) {
        self.tabs = [
            PreferencesTab(id: "general", title: "General", icon: "gearshape",
                           vc: GeneralPrefsViewController(settings: settings, onVisibilityChange: onVisibilityChange)),
            PreferencesTab(id: "hotkey", title: "Hotkeys", icon: "keyboard",
                           vc: HotkeyPrefsViewController(recorder: hotkeyRecorder)),
            PreferencesTab(id: "rules", title: "Rules", icon: "wand.and.stars",
                           vc: RulesPrefsViewController()),
            PreferencesTab(id: "about", title: "About", icon: "info.circle",
                           vc: AboutPrefsViewController())
        ]

        let sidebarItems: [SidebarItem] = [
            .tab(tabs[0]),
            .tab(tabs[1]),
            .separator,
            .tab(tabs[2]),
            .separator,
            .tab(tabs[3])
        ]
        self.sidebarVC = PreferencesSidebarViewController(items: sidebarItems, tabs: tabs)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 160
        sidebarItem.maximumThickness = 160
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: tabs[0].vc)
        addSplitViewItem(contentItem)

        sidebarVC.onSelect = { [weak self] index in
            self?.switchContent(to: index)
        }
    }

    private func switchContent(to index: Int) {
        guard index >= 0, index < tabs.count, splitViewItems.count > 1 else { return }
        let newItem = NSSplitViewItem(viewController: tabs[index].vc)
        removeSplitViewItem(splitViewItems[1])
        addSplitViewItem(newItem)
    }
}

// MARK: - Tab Model

enum SidebarItem {
    case tab(PreferencesTab)
    case separator
}

struct PreferencesTab {
    let id: String
    let title: String
    let icon: String
    let vc: NSViewController
}

// MARK: - Sidebar

final class PreferencesSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let items: [SidebarItem]
    private let tabs: [PreferencesTab]
    private let tableView = NSTableView()
    var onSelect: ((Int) -> Void)?

    init(items: [SidebarItem], tabs: [PreferencesTab]) {
        self.items = items
        self.tabs = tabs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 540))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        view.addSubview(scrollView)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sidebar"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.rowHeight = 30
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.setAccessibilityIdentifier("sidebar_table")

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch items[row] {
        case .separator:
            let sep = NSView()
            let line = NSBox()
            line.boxType = .separator
            line.translatesAutoresizingMaskIntoConstraints = false
            sep.addSubview(line)
            NSLayoutConstraint.activate([
                line.leadingAnchor.constraint(equalTo: sep.leadingAnchor, constant: 16),
                line.trailingAnchor.constraint(equalTo: sep.trailingAnchor, constant: -16),
                line.centerYAnchor.constraint(equalTo: sep.centerYAnchor)
            ])
            return sep
        case .tab(let tab):
            let id = NSUserInterfaceItemIdentifier("SidebarCell")
            let cell: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
                cell = reused
            } else {
                cell = makeSidebarCell(identifier: id)
            }
            cell.imageView?.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.title)
            cell.imageView?.contentTintColor = .secondaryLabelColor
            cell.textField?.stringValue = tab.title
            cell.setAccessibilityIdentifier("sidebar_\(tab.id)")
            cell.setAccessibilityLabel(tab.title)
            return cell
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch items[row] {
        case .separator: return 12
        case .tab: return 30
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .separator = items[row] { return false }
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, case .tab(let tab) = items[row] else { return }
        if let tabIndex = tabs.firstIndex(where: { $0.id == tab.id }) {
            onSelect?(tabIndex)
        }
    }

    private func makeSidebarCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)
        cell.imageView = icon

        let title = NSTextField(labelWithString: "")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.drawsBackground = false
        title.isBordered = false
        title.isEditable = false
        title.font = .systemFont(ofSize: 14)
        cell.addSubview(title)
        cell.textField = title

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            title.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            title.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12)
        ])

        return cell
    }
}

// MARK: - General Tab

final class GeneralPrefsViewController: NSViewController {
    private let settings: SettingsStore
    private let onVisibilityChange: () -> Void
    private let showInDockCheckbox = NSButton(checkboxWithTitle: "Show in Dock", target: nil, action: nil)
    private let showInMenuBarCheckbox = NSButton(checkboxWithTitle: "Show in Menu Bar", target: nil, action: nil)
    private let storeImagesCheckbox = NSButton(checkboxWithTitle: "Store images in history", target: nil, action: nil)
    private let historySizeField = NSTextField()
    private let positionPicker = ScreenPositionPicker()
    private let screenModePopup = NSPopUpButton()

    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void) {
        self.settings = settings
        self.onVisibilityChange = onVisibilityChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let titleLabel = NSTextField(labelWithString: "General")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        let visibilityLabel = makeSectionLabel("Visibility")
        let historyLabel = makeSectionLabel("History")
        let historySizeLabel = NSTextField(labelWithString: "Max items:")
        historySizeField.placeholderString = "500"
        historySizeField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let historyRow = NSStackView(views: [historySizeLabel, historySizeField])
        historyRow.spacing = 8

        let positionLabel = makeSectionLabel("Panel Position")
        positionPicker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            positionPicker.widthAnchor.constraint(equalToConstant: 200),
            positionPicker.heightAnchor.constraint(equalToConstant: 125)
        ])
        positionPicker.positionX = settings.panelPositionX
        positionPicker.positionY = settings.panelPositionY
        positionPicker.onChange = { [weak self] x, y in
            self?.settings.panelPositionX = x
            self?.settings.panelPositionY = y
        }

        let screenLabel = NSTextField(labelWithString: "Show on:")
        screenModePopup.removeAllItems()
        for mode in PanelScreenMode.allCases {
            screenModePopup.addItem(withTitle: mode.title)
        }
        screenModePopup.selectItem(at: settings.panelScreenMode)
        screenModePopup.target = self
        screenModePopup.action = #selector(screenModeChanged)

        let screenRow = NSStackView(views: [screenLabel, screenModePopup])
        screenRow.spacing = 8

        let leftColumn = NSStackView(views: [
            visibilityLabel, showInDockCheckbox, showInMenuBarCheckbox,
            makeSpacer(), historyLabel, historyRow, storeImagesCheckbox
        ])
        leftColumn.orientation = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = 10

        let rightColumn = NSStackView(views: [
            positionLabel, positionPicker, screenRow
        ])
        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 10

        let columns = NSStackView(views: [leftColumn, rightColumn])
        columns.orientation = .horizontal
        columns.alignment = .top
        columns.spacing = 40
        columns.distribution = .fillEqually

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        columns.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        view.addSubview(columns)

        let pad: CGFloat = 24
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            columns.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            columns.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            columns.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad)
        ])

        showInDockCheckbox.target = self
        showInDockCheckbox.action = #selector(visibilityChanged)
        showInMenuBarCheckbox.target = self
        showInMenuBarCheckbox.action = #selector(visibilityChanged)
        storeImagesCheckbox.target = self
        storeImagesCheckbox.action = #selector(storeImagesChanged)
        historySizeField.target = self
        historySizeField.action = #selector(historySizeChanged)
        loadSettings()
    }

    private func loadSettings() {
        showInDockCheckbox.state = settings.showInDock ? .on : .off
        showInMenuBarCheckbox.state = settings.showInMenuBar ? .on : .off
        storeImagesCheckbox.state = settings.storeImages ? .on : .off
        historySizeField.integerValue = settings.maxHistorySize
    }

    @objc private func visibilityChanged(_ sender: NSButton) {
        let dock = showInDockCheckbox.state == .on
        let menu = showInMenuBarCheckbox.state == .on
        if !dock && !menu { sender.state = .on; return }
        settings.showInDock = dock
        settings.showInMenuBar = menu
        onVisibilityChange()
    }

    @objc private func storeImagesChanged() { settings.storeImages = storeImagesCheckbox.state == .on }
    @objc private func screenModeChanged() { settings.panelScreenMode = screenModePopup.indexOfSelectedItem }
    @objc private func historySizeChanged() { settings.maxHistorySize = max(10, historySizeField.integerValue) }

    private func makeSectionLabel(_ t: String) -> NSTextField {
        let l = NSTextField(labelWithString: t)
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .labelColor
        return l
    }

    private func makeSpacer() -> NSView {
        let v = NSView()
        v.heightAnchor.constraint(equalToConstant: 12).isActive = true
        return v
    }
}

// MARK: - Hotkey Tab

final class HotkeyPrefsViewController: NSViewController {
    private let recorder: HotkeyRecorder
    private let hotkeyField = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    init(recorder: HotkeyRecorder) {
        self.recorder = recorder
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400)) }

    override func viewDidLoad() {
        super.viewDidLoad()

        recorder.onResult = { [weak self] result in self?.handleRecorderResult(result) }

        let titleLabel = NSTextField(labelWithString: "Hotkeys")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let label = NSTextField(labelWithString: "Global shortcut to show clipboard:")
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        hotkeyField.alignment = .center
        hotkeyField.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        hotkeyField.isEditable = false
        hotkeyField.isSelectable = false
        hotkeyField.isBezeled = true
        hotkeyField.bezelStyle = .roundedBezel
        hotkeyField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hotkeyField)

        let recordButton = NSButton(title: "Record Hotkey", target: self, action: #selector(startRecording))
        recordButton.bezelStyle = .rounded
        recordButton.setContentHuggingPriority(.required, for: .horizontal)
        recordButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recordButton)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = true
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        let pad: CGFloat = 24
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            hotkeyField.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
            hotkeyField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            hotkeyField.widthAnchor.constraint(equalToConstant: 200),
            hotkeyField.heightAnchor.constraint(equalToConstant: 28),

            recordButton.centerYAnchor.constraint(equalTo: hotkeyField.centerYAnchor),
            recordButton.leadingAnchor.constraint(equalTo: hotkeyField.trailingAnchor, constant: 12),

            statusLabel.topAnchor.constraint(equalTo: hotkeyField.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad)
        ])
        updateHotkeyLabel()
    }

    private func updateHotkeyLabel() {
        let shortcutStr = recorder.currentShortcutString
        hotkeyField.stringValue = shortcutStr

        if recorder.isReserved(shortcutStr) {
            statusLabel.stringValue = "This shortcut is reserved by macOS"
            statusLabel.textColor = .systemRed
        } else {
            statusLabel.stringValue = "Shortcut assigned"
            statusLabel.textColor = .systemGreen
        }
        statusLabel.isHidden = false
    }

    private func handleRecorderResult(_ result: HotkeyRecorderResult) {
        switch result {
        case .recorded:
            updateHotkeyLabel()
        case .cancelled:
            updateHotkeyLabel()
        case .rejected(let shortcut):
            hotkeyField.stringValue = shortcut
            statusLabel.stringValue = "This shortcut is reserved by macOS. Choose another."
            statusLabel.textColor = .systemRed
            statusLabel.isHidden = false
        case .needsModifier:
            statusLabel.stringValue = "At least one modifier key required"
            statusLabel.textColor = .systemOrange
            statusLabel.isHidden = false
        }
    }

    @objc private func startRecording() {
        hotkeyField.stringValue = "Press shortcut..."
        statusLabel.stringValue = "Use Cmd, Opt, Ctrl or Shift + key. Escape to cancel."
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = false
        recorder.startRecording()
    }
}

// MARK: - Rules Tab

final class RulesPrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let engine = ClipboardRuleEngine()
    private let rulesTable = NSTableView()
    private let descField = NSTextField()
    private let appPopup = NSPopUpButton()
    private let transformsContainer = NSStackView()
    private var selectedRuleIndex = -1

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400)) }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        selectRule(at: 0)
    }

    private func setupUI() {
        let pad: CGFloat = 24

        let titleLabel = NSTextField(labelWithString: "Rules")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let rulesScroll = NSScrollView()
        rulesScroll.translatesAutoresizingMaskIntoConstraints = false
        rulesScroll.documentView = rulesTable
        rulesScroll.hasVerticalScroller = true
        rulesScroll.drawsBackground = false
        rulesScroll.borderType = .bezelBorder
        view.addSubview(rulesScroll)

        let rulesCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rules"))
        rulesCol.resizingMask = .autoresizingMask
        rulesTable.addTableColumn(rulesCol)
        rulesTable.headerView = nil
        rulesTable.dataSource = self
        rulesTable.delegate = self
        rulesTable.rowHeight = 28
        rulesTable.tag = 1

        let addRule = NSButton(title: "+", target: self, action: #selector(addRule))
        addRule.bezelStyle = .smallSquare
        let removeRule = NSButton(title: "-", target: self, action: #selector(removeRule))
        removeRule.bezelStyle = .smallSquare
        let ruleButtons = NSStackView(views: [addRule, removeRule])
        ruleButtons.translatesAutoresizingMaskIntoConstraints = false
        ruleButtons.spacing = 0
        view.addSubview(ruleButtons)

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sep)

        let descLabel = makeFieldLabel("Description:")
        descField.font = .systemFont(ofSize: 13)
        descField.target = self
        descField.action = #selector(nameChanged)
        descField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descLabel)
        view.addSubview(descField)

        let appLabel = makeFieldLabel("When copied from")
        appPopup.target = self
        appPopup.action = #selector(appChanged)
        appPopup.translatesAutoresizingMaskIntoConstraints = false
        let appSuffix = NSTextField(labelWithString: "apply transforms:")
        appSuffix.font = .systemFont(ofSize: 13)
        appSuffix.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appLabel)
        view.addSubview(appPopup)
        view.addSubview(appSuffix)

        let transformsScroll = NSScrollView()
        transformsScroll.translatesAutoresizingMaskIntoConstraints = false
        transformsScroll.documentView = transformsContainer
        transformsScroll.hasVerticalScroller = true
        transformsScroll.drawsBackground = false
        view.addSubview(transformsScroll)

        transformsContainer.orientation = .vertical
        transformsContainer.alignment = .leading
        transformsContainer.spacing = 6
        transformsContainer.translatesAutoresizingMaskIntoConstraints = false
        transformsContainer.setContentHuggingPriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: pad),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            rulesScroll.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            rulesScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            rulesScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            rulesScroll.heightAnchor.constraint(equalToConstant: 100),

            ruleButtons.topAnchor.constraint(equalTo: rulesScroll.bottomAnchor, constant: 4),
            ruleButtons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),

            sep.topAnchor.constraint(equalTo: ruleButtons.bottomAnchor, constant: 10),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            descLabel.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 14),
            descLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            descField.centerYAnchor.constraint(equalTo: descLabel.centerYAnchor),
            descField.leadingAnchor.constraint(equalTo: descLabel.trailingAnchor, constant: 8),
            descField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            appLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 14),
            appLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            appPopup.centerYAnchor.constraint(equalTo: appLabel.centerYAnchor),
            appPopup.leadingAnchor.constraint(equalTo: appLabel.trailingAnchor, constant: 6),
            appSuffix.centerYAnchor.constraint(equalTo: appLabel.centerYAnchor),
            appSuffix.leadingAnchor.constraint(equalTo: appPopup.trailingAnchor, constant: 6),

            transformsScroll.topAnchor.constraint(equalTo: appLabel.bottomAnchor, constant: 12),
            transformsScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            transformsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),
            transformsScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -pad),

            transformsContainer.topAnchor.constraint(equalTo: transformsScroll.contentView.topAnchor),
            transformsContainer.leadingAnchor.constraint(equalTo: transformsScroll.contentView.leadingAnchor),
            transformsContainer.trailingAnchor.constraint(equalTo: transformsScroll.contentView.trailingAnchor)
        ])
    }

    private func makeFieldLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 13)
        l.translatesAutoresizingMaskIntoConstraints = false
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }

    private func selectRule(at index: Int) {
        guard index >= 0, index < engine.rules.count else {
            selectedRuleIndex = -1
            descField.stringValue = ""
            return
        }
        selectedRuleIndex = index
        let rule = engine.rules[index]
        descField.stringValue = rule.name
        rebuildAppPopup()
        rebuildTransforms()
        rulesTable.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    }

    private func rebuildAppPopup() {
        appPopup.removeAllItems()
        appPopup.addItem(withTitle: "All Applications")
        appPopup.menu?.addItem(.separator())

        var seen = Set<String>()
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier,
                  !seen.contains(bundleId),
                  app.activationPolicy == .regular else { continue }
            seen.insert(bundleId)
            let item = NSMenuItem()
            item.title = app.localizedName ?? bundleId
            item.representedObject = bundleId
            if let icon = app.icon {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            appPopup.menu?.addItem(item)
        }

        if selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count {
            let rule = engine.rules[selectedRuleIndex]
            if let bundleId = rule.appBundleId {
                for (i, item) in (appPopup.menu?.items ?? []).enumerated() {
                    if (item.representedObject as? String) == bundleId {
                        appPopup.selectItem(at: i)
                        return
                    }
                }
            }
            appPopup.selectItem(at: 0)
        }
    }

    private func rebuildTransforms() {
        transformsContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count else { return }
        let transforms = engine.rules[selectedRuleIndex].transforms

        for (i, transform) in transforms.enumerated() {
            let row = makeTransformRow(transform: transform, index: i)
            transformsContainer.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: transformsContainer.widthAnchor).isActive = true
        }

        let addRow = NSStackView()
        addRow.orientation = .horizontal
        addRow.spacing = 4
        let addBtn = NSButton(title: "+", target: self, action: #selector(addTransform))
        addBtn.bezelStyle = .smallSquare
        addRow.addArrangedSubview(addBtn)
        transformsContainer.addArrangedSubview(addRow)
    }

    private func makeTransformRow(transform: ClipboardTransform, index: Int) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY

        let typePopup = NSPopUpButton()
        typePopup.font = .systemFont(ofSize: 12)
        for type in ClipboardTransformType.allCases {
            let item = NSMenuItem(title: type.displayName, action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: type.icon, accessibilityDescription: nil)
            typePopup.menu?.addItem(item)
        }
        typePopup.selectItem(at: ClipboardTransformType.allCases.firstIndex(of: transform.type) ?? 0)
        typePopup.tag = index
        typePopup.target = self
        typePopup.action = #selector(transformTypeChanged(_:))
        row.addArrangedSubview(typePopup)

        if transform.type == .regexReplace {
            let patternField = NSTextField()
            patternField.placeholderString = "Pattern"
            patternField.stringValue = transform.pattern
            patternField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            patternField.tag = index
            patternField.target = self
            patternField.action = #selector(patternChanged)
            patternField.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
            row.addArrangedSubview(patternField)

            let arrow = NSTextField(labelWithString: "->")
            arrow.font = .systemFont(ofSize: 12)
            row.addArrangedSubview(arrow)

            let replField = NSTextField()
            replField.placeholderString = "Replace"
            replField.stringValue = transform.replacement
            replField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            replField.tag = index
            replField.target = self
            replField.action = #selector(replacementChanged)
            replField.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
            row.addArrangedSubview(replField)
        }

        let removeBtn = NSButton(title: "-", target: self, action: #selector(removeTransformAt(_:)))
        removeBtn.bezelStyle = .smallSquare
        removeBtn.tag = index
        row.addArrangedSubview(removeBtn)

        return row
    }

    @objc private func addRule() {
        var rules = engine.rules
        rules.append(ClipboardRule(name: "New Rule"))
        engine.rules = rules
        rulesTable.reloadData()
        selectRule(at: rules.count - 1)
    }

    @objc private func removeRule() {
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count else { return }
        var rules = engine.rules
        rules.remove(at: selectedRuleIndex)
        engine.rules = rules
        rulesTable.reloadData()
        selectRule(at: min(selectedRuleIndex, rules.count - 1))
    }

    @objc private func nameChanged() {
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count else { return }
        var rules = engine.rules
        rules[selectedRuleIndex].name = descField.stringValue
        engine.rules = rules
        rulesTable.reloadData(forRowIndexes: IndexSet(integer: selectedRuleIndex), columnIndexes: IndexSet(integer: 0))
    }

    @objc private func appChanged() {
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count else { return }
        var rules = engine.rules
        rules[selectedRuleIndex].appBundleId = appPopup.selectedItem?.representedObject as? String
        engine.rules = rules
        rulesTable.reloadData(forRowIndexes: IndexSet(integer: selectedRuleIndex), columnIndexes: IndexSet(integer: 0))
    }

    @objc private func addTransform() {
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count else { return }
        var rules = engine.rules
        rules[selectedRuleIndex].transforms.append(ClipboardTransform(type: .trimWhitespace))
        engine.rules = rules
        rebuildTransforms()
    }

    @objc private func removeTransformAt(_ sender: NSButton) {
        let idx = sender.tag
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count,
              idx >= 0, idx < engine.rules[selectedRuleIndex].transforms.count else { return }
        var rules = engine.rules
        rules[selectedRuleIndex].transforms.remove(at: idx)
        engine.rules = rules
        rebuildTransforms()
    }

    @objc private func transformTypeChanged(_ sender: NSPopUpButton) {
        let idx = sender.tag
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count,
              idx >= 0, idx < engine.rules[selectedRuleIndex].transforms.count else { return }
        let allTypes = ClipboardTransformType.allCases
        let newType = allTypes[sender.indexOfSelectedItem]
        var rules = engine.rules
        rules[selectedRuleIndex].transforms[idx].type = newType
        engine.rules = rules
        rebuildTransforms()
    }

    @objc private func patternChanged(_ sender: NSTextField) {
        let idx = sender.tag
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count,
              idx >= 0, idx < engine.rules[selectedRuleIndex].transforms.count else { return }
        var rules = engine.rules
        rules[selectedRuleIndex].transforms[idx].pattern = sender.stringValue
        engine.rules = rules
    }

    @objc private func replacementChanged(_ sender: NSTextField) {
        let idx = sender.tag
        guard selectedRuleIndex >= 0, selectedRuleIndex < engine.rules.count,
              idx >= 0, idx < engine.rules[selectedRuleIndex].transforms.count else { return }
        var rules = engine.rules
        rules[selectedRuleIndex].transforms[idx].replacement = sender.stringValue
        engine.rules = rules
    }

    @objc private func toggleRule(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < engine.rules.count else { return }
        var rules = engine.rules
        rules[row].isEnabled = sender.state == .on
        engine.rules = rules
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { engine.rules.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < engine.rules.count else { return nil }
        let rule = engine.rules[row]
        let cell = NSView()

        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleRule))
        checkbox.state = rule.isEnabled ? .on : .off
        checkbox.tag = row
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(checkbox)

        let icon = NSImageView()
        icon.image = rule.appIcon
        icon.image?.size = NSSize(width: 16, height: 16)
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)

        let label = NSTextField(labelWithString: rule.name)
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        cell.addSubview(label)

        let appLabel = NSTextField(labelWithString: rule.appName)
        appLabel.font = .systemFont(ofSize: 10)
        appLabel.textColor = .secondaryLabelColor
        appLabel.translatesAutoresizingMaskIntoConstraints = false
        appLabel.alignment = .right
        appLabel.lineBreakMode = .byTruncatingTail
        cell.addSubview(appLabel)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            appLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            appLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            appLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectRule(at: rulesTable.selectedRow)
    }
}

// MARK: - About Tab

final class AboutPrefsViewController: NSViewController {
    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400)) }

    override func viewDidLoad() {
        super.viewDidLoad()

        let appName = NSTextField(labelWithString: "ClipMoar")
        appName.font = .boldSystemFont(ofSize: 24)

        let version = NSTextField(labelWithString: "Version 0.1.0")
        version.font = .systemFont(ofSize: 13)
        version.textColor = .secondaryLabelColor

        let desc = NSTextField(labelWithString: "Clipboard manager for macOS")
        desc.font = .systemFont(ofSize: 13)

        let copyright = NSTextField(labelWithString: "MIT License - 2026 noma4i")
        copyright.font = .systemFont(ofSize: 11)
        copyright.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [appName, version, desc, copyright])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
