import Carbon
import Cocoa

// MARK: - Window Controller

final class PreferencesWindowController: NSWindowController {
    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void, hotkeyRecorder: HotkeyRecorder) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"

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
            PreferencesTab(id: "general", title: "General", icon: "gear",
                           vc: GeneralPrefsViewController(settings: settings, onVisibilityChange: onVisibilityChange)),
            PreferencesTab(id: "hotkey", title: "Hotkeys", icon: "keyboard",
                           vc: HotkeyPrefsViewController(recorder: hotkeyRecorder)),
            PreferencesTab(id: "rules", title: "Rules", icon: "list.bullet.rectangle",
                           vc: RulesPrefsViewController()),
            PreferencesTab(id: "about", title: "About", icon: "info.circle",
                           vc: AboutPrefsViewController())
        ]
        self.sidebarVC = PreferencesSidebarViewController(tabs: tabs)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 220
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

struct PreferencesTab {
    let id: String
    let title: String
    let icon: String
    let vc: NSViewController
}

// MARK: - Sidebar

final class PreferencesSidebarViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let tabs: [PreferencesTab]
    private let tableView = NSTableView()
    var onSelect: ((Int) -> Void)?

    init(tabs: [PreferencesTab]) {
        self.tabs = tabs
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 420))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let titleLabel = NSTextField(labelWithString: "Settings")
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

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
        tableView.rowHeight = 32
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 2)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { tabs.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let tab = tabs[row]
        let id = NSUserInterfaceItemIdentifier("SidebarCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeSidebarCell(identifier: id)
        }

        cell.imageView?.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.title)
        cell.textField?.stringValue = tab.title
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelect?(tableView.selectedRow)
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
        title.font = .systemFont(ofSize: 13)
        cell.addSubview(title)
        cell.textField = title

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            title.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8)
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

    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void) {
        self.settings = settings
        self.onVisibilityChange = onVisibilityChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 380))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let visibilityLabel = makeSectionLabel("Visibility")
        let historyLabel = makeSectionLabel("History")
        let historySizeLabel = NSTextField(labelWithString: "Max items:")
        historySizeField.placeholderString = "500"
        historySizeField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let historyRow = NSStackView(views: [historySizeLabel, historySizeField])
        historyRow.spacing = 8

        let stack = NSStackView(views: [
            visibilityLabel, showInDockCheckbox, showInMenuBarCheckbox,
            makeSpacer(), historyLabel, historyRow, storeImagesCheckbox
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
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
    @objc private func historySizeChanged() { settings.maxHistorySize = max(10, historySizeField.integerValue) }

    private func makeSectionLabel(_ t: String) -> NSTextField { let l = NSTextField(labelWithString: t); l.font = .boldSystemFont(ofSize: 13); return l }
    private func makeSpacer() -> NSView { let v = NSView(); v.heightAnchor.constraint(equalToConstant: 8).isActive = true; return v }
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

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 380)) }

    override func viewDidLoad() {
        super.viewDidLoad()

        recorder.onResult = { [weak self] result in self?.handleRecorderResult(result) }

        let label = NSTextField(labelWithString: "Global shortcut to show clipboard:")
        label.font = .systemFont(ofSize: 13)

        hotkeyField.alignment = .center
        hotkeyField.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        hotkeyField.wantsLayer = true
        hotkeyField.layer?.cornerRadius = 4
        hotkeyField.layer?.borderWidth = 1
        hotkeyField.layer?.borderColor = NSColor.separatorColor.cgColor
        hotkeyField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        hotkeyField.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let recordButton = NSButton(title: "Record Hotkey", target: self, action: #selector(startRecording))

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = true

        let hotkeyRow = NSStackView(views: [hotkeyField, recordButton])
        hotkeyRow.spacing = 12

        let hintLabel = NSTextField(labelWithString: "Recommended: Shift+Cmd+V, Ctrl+Cmd+V, Opt+Cmd+V")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [label, hotkeyRow, statusLabel, hintLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
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
        statusLabel.stringValue = "Press a key combination with at least one modifier (Cmd, Opt, Ctrl, Shift). Escape to cancel."
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.isHidden = false
        recorder.startRecording()
    }
}

// MARK: - Rules Tab

final class RulesPrefsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let engine = ClipboardRuleEngine()
    private let tableView = NSTableView()
    private var currentRuleIndex = 0

    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 380)) }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        reloadTransforms()
    }

    private func setupUI() {
        let headerLabel = NSTextField(labelWithString: "Transform blocks applied to clipboard on copy:")
        headerLabel.font = .systemFont(ofSize: 12)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("transform"))
        column.title = "Transforms"
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 36

        let addButton = NSButton(title: "+", target: self, action: #selector(addTransform))
        addButton.bezelStyle = .smallSquare
        let removeButton = NSButton(title: "-", target: self, action: #selector(removeTransform))
        removeButton.bezelStyle = .smallSquare
        let buttonRow = NSStackView(views: [addButton, removeButton])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.spacing = 2
        view.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -8),

            buttonRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    private var transforms: [ClipboardTransform] {
        get {
            guard currentRuleIndex < engine.rules.count else { return [] }
            return engine.rules[currentRuleIndex].transforms
        }
        set {
            guard currentRuleIndex < engine.rules.count else { return }
            var rules = engine.rules
            rules[currentRuleIndex].transforms = newValue
            engine.rules = rules
        }
    }

    private func reloadTransforms() {
        tableView.reloadData()
    }

    @objc private func addTransform() {
        let menu = NSMenu()
        for type in ClipboardTransformType.allCases {
            let item = NSMenuItem(title: type.displayName, action: #selector(addTransformOfType(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type
            item.image = NSImage(systemSymbolName: type.icon, accessibilityDescription: nil)
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 20, y: 0), in: view)
    }

    @objc private func addTransformOfType(_ sender: NSMenuItem) {
        guard let type = sender.representedObject as? ClipboardTransformType else { return }
        var list = transforms
        list.append(ClipboardTransform(type: type))
        transforms = list
        reloadTransforms()
    }

    @objc private func removeTransform() {
        let row = tableView.selectedRow
        guard row >= 0, row < transforms.count else { return }
        var list = transforms
        list.remove(at: row)
        transforms = list
        reloadTransforms()
    }

    @objc private func toggleTransform(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < transforms.count else { return }
        var list = transforms
        list[row].isEnabled = sender.state == .on
        transforms = list
    }

    @objc private func patternChanged(_ sender: NSTextField) {
        let row = sender.tag
        guard row >= 0, row < transforms.count else { return }
        var list = transforms
        list[row].pattern = sender.stringValue
        transforms = list
    }

    @objc private func replacementChanged(_ sender: NSTextField) {
        let row = sender.tag
        guard row >= 0, row < transforms.count else { return }
        var list = transforms
        list[row].replacement = sender.stringValue
        transforms = list
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { transforms.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < transforms.count else { return nil }
        let transform = transforms[row]

        let cell = NSView()

        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleTransform))
        checkbox.state = transform.isEnabled ? .on : .off
        checkbox.tag = row
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(checkbox)

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: transform.type.icon, accessibilityDescription: nil)
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)

        let label = NSTextField(labelWithString: transform.type.displayName)
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

            icon.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        if transform.type == .regexReplace {
            let patternField = NSTextField()
            patternField.placeholderString = "Pattern (regex)"
            patternField.stringValue = transform.pattern
            patternField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            patternField.tag = row
            patternField.target = self
            patternField.action = #selector(patternChanged)
            patternField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(patternField)

            let replField = NSTextField()
            replField.placeholderString = "Replacement"
            replField.stringValue = transform.replacement
            replField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            replField.tag = row
            replField.target = self
            replField.action = #selector(replacementChanged)
            replField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(replField)

            NSLayoutConstraint.activate([
                patternField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
                patternField.centerYAnchor.constraint(equalTo: cell.centerYAnchor, constant: -8),
                patternField.widthAnchor.constraint(equalToConstant: 140),

                replField.leadingAnchor.constraint(equalTo: patternField.leadingAnchor),
                replField.centerYAnchor.constraint(equalTo: cell.centerYAnchor, constant: 8),
                replField.widthAnchor.constraint(equalToConstant: 140)
            ])
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < transforms.count else { return 36 }
        return transforms[row].type == .regexReplace ? 52 : 36
    }
}

// MARK: - About Tab

final class AboutPrefsViewController: NSViewController {
    override func loadView() { view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 380)) }

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
