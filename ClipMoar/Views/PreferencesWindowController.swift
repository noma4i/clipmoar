import Carbon
import Cocoa

final class PreferencesWindowController: NSWindowController, NSToolbarDelegate {
    private let settings: SettingsStore
    private var onVisibilityChange: () -> Void
    private var onHotkeyChange: () -> Void

    private let tabIdentifiers = ["general", "hotkey", "rules", "about"]
    private lazy var tabViews: [String: NSViewController] = [
        "general": GeneralPrefsViewController(settings: settings, onVisibilityChange: onVisibilityChange),
        "hotkey": HotkeyPrefsViewController(settings: settings, onHotkeyChange: onHotkeyChange),
        "rules": RulesPrefsViewController(),
        "about": AboutPrefsViewController()
    ]

    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void, onHotkeyChange: @escaping () -> Void) {
        self.settings = settings
        self.onVisibilityChange = onVisibilityChange
        self.onHotkeyChange = onHotkeyChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipMoar"
        window.center()

        super.init(window: window)

        let toolbar = NSToolbar(identifier: "PrefsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = NSToolbarItem.Identifier("general")
        window.toolbar = toolbar
        window.toolbarStyle = .preference

        switchTab(to: "general")
    }

    required init?(coder: NSCoder) { nil }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        switchTab(to: sender.itemIdentifier.rawValue)
        window?.toolbar?.selectedItemIdentifier = sender.itemIdentifier
    }

    private func switchTab(to id: String) {
        guard let vc = tabViews[id] else { return }
        window?.contentViewController = vc
    }

    // MARK: - NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        tabIdentifiers.map { NSToolbarItem.Identifier($0) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        tabIdentifiers.map { NSToolbarItem.Identifier($0) }
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        tabIdentifiers.map { NSToolbarItem.Identifier($0) }
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.target = self
        item.action = #selector(toolbarItemClicked)

        switch itemIdentifier.rawValue {
        case "general":
            item.label = "General"
            item.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "General")
        case "hotkey":
            item.label = "Hotkey"
            item.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Hotkey")
        case "rules":
            item.label = "Rules"
            item.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "Rules")
        case "about":
            item.label = "About"
            item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        default:
            break
        }

        return item
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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))
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
            makeSpacer(),
            historyLabel, historyRow, storeImagesCheckbox
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
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
        let showInDock = showInDockCheckbox.state == .on
        let showInMenuBar = showInMenuBarCheckbox.state == .on
        if !showInDock && !showInMenuBar { sender.state = .on; return }
        settings.showInDock = showInDock
        settings.showInMenuBar = showInMenuBar
        onVisibilityChange()
    }

    @objc private func storeImagesChanged() {
        settings.storeImages = storeImagesCheckbox.state == .on
    }

    @objc private func historySizeChanged() {
        settings.maxHistorySize = max(10, historySizeField.integerValue)
    }

    private func makeSectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func makeSpacer() -> NSView {
        let v = NSView()
        v.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return v
    }
}

// MARK: - Hotkey Tab

final class HotkeyPrefsViewController: NSViewController {
    private let settings: SettingsStore
    private let onHotkeyChange: () -> Void
    private let hotkeyField = NSTextField(labelWithString: "")
    private var isRecording = false
    private var localMonitor: Any?

    init(settings: SettingsStore, onHotkeyChange: @escaping () -> Void) {
        self.settings = settings
        self.onHotkeyChange = onHotkeyChange
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

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

        let hotkeyRow = NSStackView(views: [hotkeyField, recordButton])
        hotkeyRow.spacing = 12

        let stack = NSStackView(views: [label, hotkeyRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24)
        ])

        updateHotkeyLabel()
    }

    private func updateHotkeyLabel() {
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        hotkeyField.stringValue = KeyboardShortcutFormatter.string(for: settings.hotkeyKeyCode, modifiers: modifiers)
    }

    @objc private func startRecording() {
        isRecording = true
        hotkeyField.stringValue = "Press shortcut..."

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifiers.isEmpty else { return nil }

            self.settings.hotkeyKeyCode = Int(event.keyCode)
            self.settings.hotkeyModifiers = UInt32(modifiers.rawValue)
            self.updateHotkeyLabel()
            self.isRecording = false

            if let monitor = self.localMonitor {
                NSEvent.removeMonitor(monitor)
                self.localMonitor = nil
            }

            self.onHotkeyChange()
            return nil
        }
    }
}

// MARK: - Rules Tab

final class RulesPrefsViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let label = NSTextField(labelWithString: "Clipboard rules will be available in a future version.")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - About Tab

final class AboutPrefsViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let appName = NSTextField(labelWithString: "ClipMoar")
        appName.font = .boldSystemFont(ofSize: 24)

        let version = NSTextField(labelWithString: "Version 0.1.0")
        version.font = .systemFont(ofSize: 13)
        version.textColor = .secondaryLabelColor

        let description = NSTextField(labelWithString: "Clipboard manager for macOS")
        description.font = .systemFont(ofSize: 13)

        let copyright = NSTextField(labelWithString: "MIT License - 2026 noma4i")
        copyright.font = .systemFont(ofSize: 11)
        copyright.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [appName, version, description, copyright])
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
