import Carbon
import Cocoa

final class PreferencesWindowController: NSWindowController {
    convenience init(
        settings: SettingsStore,
        onVisibilityChange: @escaping () -> Void,
        onHotkeyChange: @escaping () -> Void
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        let vc = PreferencesViewController()
        vc.onVisibilityChange = onVisibilityChange
        vc.onHotkeyChange = onHotkeyChange
        window.contentViewController = vc

        self.init(window: window)
    }
}

final class PreferencesViewController: NSViewController {
    var onVisibilityChange: (() -> Void)?
    var onHotkeyChange: (() -> Void)?

    private let showInDockCheckbox = NSButton(checkboxWithTitle: "Show in Dock", target: nil, action: nil)
    private let showInMenuBarCheckbox = NSButton(checkboxWithTitle: "Show in Menu Bar", target: nil, action: nil)
    private let storeImagesCheckbox = NSButton(checkboxWithTitle: "Store images in history", target: nil, action: nil)
    private let historySizeField = NSTextField()
    private let hotkeyField = NSTextField(labelWithString: "")
    private var isRecordingHotkey = false
    private var localMonitor: Any?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 320))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        // Visibility section
        let visibilityLabel = makeSectionLabel("Visibility")

        // History section
        let historyLabel = makeSectionLabel("History")
        let historySizeLabel = NSTextField(labelWithString: "Max items:")
        historySizeField.translatesAutoresizingMaskIntoConstraints = false
        historySizeField.placeholderString = "500"
        historySizeField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let historyRow = NSStackView(views: [historySizeLabel, historySizeField])
        historyRow.spacing = 8

        // Hotkey section
        let hotkeyLabel = makeSectionLabel("Hotkey")
        hotkeyField.translatesAutoresizingMaskIntoConstraints = false
        hotkeyField.alignment = .center
        hotkeyField.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        hotkeyField.wantsLayer = true
        hotkeyField.layer?.cornerRadius = 4
        hotkeyField.layer?.borderWidth = 1
        hotkeyField.layer?.borderColor = NSColor.separatorColor.cgColor
        hotkeyField.widthAnchor.constraint(equalToConstant: 160).isActive = true
        hotkeyField.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let recordButton = NSButton(title: "Record Hotkey", target: self, action: #selector(startRecordingHotkey))
        let hotkeyRow = NSStackView(views: [hotkeyField, recordButton])
        hotkeyRow.spacing = 8

        let stack = NSStackView(views: [
            visibilityLabel,
            showInDockCheckbox,
            showInMenuBarCheckbox,
            historyLabel,
            historyRow,
            storeImagesCheckbox,
            hotkeyLabel,
            hotkeyRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        showInDockCheckbox.target = self
        showInDockCheckbox.action = #selector(visibilityChanged)
        showInMenuBarCheckbox.target = self
        showInMenuBarCheckbox.action = #selector(visibilityChanged)
        storeImagesCheckbox.target = self
        storeImagesCheckbox.action = #selector(storeImagesChanged)
        historySizeField.target = self
        historySizeField.action = #selector(historySizeChanged)
    }

    private func makeSectionLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        showInDockCheckbox.state = defaults.bool(forKey: Settings.showInDock) ? .on : .off
        showInMenuBarCheckbox.state = defaults.bool(forKey: Settings.showInMenuBar) ? .on : .off
        storeImagesCheckbox.state = defaults.bool(forKey: Settings.storeImages) ? .on : .off
        historySizeField.integerValue = defaults.integer(forKey: Settings.maxHistorySize)
        updateHotkeyLabel()
    }

    private func updateHotkeyLabel() {
        let keyCode = UserDefaults.standard.integer(forKey: Settings.hotkeyKeyCode)
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: Settings.hotkeyModifiers)))
        hotkeyField.stringValue = hotkeyString(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Actions

    @objc private func visibilityChanged(_ sender: NSButton) {
        let showInDock = showInDockCheckbox.state == .on
        let showInMenuBar = showInMenuBarCheckbox.state == .on

        if !showInDock && !showInMenuBar {
            sender.state = .on
            return
        }

        UserDefaults.standard.set(showInDock, forKey: Settings.showInDock)
        UserDefaults.standard.set(showInMenuBar, forKey: Settings.showInMenuBar)

        onVisibilityChange?()
    }

    @objc private func storeImagesChanged() {
        UserDefaults.standard.set(storeImagesCheckbox.state == .on, forKey: Settings.storeImages)
    }

    @objc private func historySizeChanged() {
        let value = max(10, historySizeField.integerValue)
        UserDefaults.standard.set(value, forKey: Settings.maxHistorySize)
    }

    @objc private func startRecordingHotkey() {
        isRecordingHotkey = true
        hotkeyField.stringValue = "Press shortcut..."

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecordingHotkey else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifiers.isEmpty else { return nil }

            UserDefaults.standard.set(Int(event.keyCode), forKey: Settings.hotkeyKeyCode)
            UserDefaults.standard.set(Int(modifiers.rawValue), forKey: Settings.hotkeyModifiers)

            self.updateHotkeyLabel()
            self.isRecordingHotkey = false

            if let monitor = self.localMonitor {
                NSEvent.removeMonitor(monitor)
                self.localMonitor = nil
            }

            self.onHotkeyChange?()
            return nil
        }
    }

    // MARK: - Hotkey Display

    private func hotkeyString(keyCode: Int, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option) { parts.append("Opt") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }
        parts.append(keyName(for: keyCode))
        return parts.joined(separator: "+")
    }

    private func keyName(for keyCode: Int) -> String {
        let names: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
            kVK_Delete: "Delete", kVK_Escape: "Esc",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8"
        ]
        return names[keyCode] ?? "Key\(keyCode)"
    }
}
