import Cocoa
import CoreData

final class AppCoordinator {
    private let settings: SettingsStore
    private let presetStore = PresetStore()
    private let context: NSManagedObjectContext
    private let repository: ClipboardRepository
    private let clipboardActions: ClipboardActionServicing
    private let clipboardService: ClipboardService
    private let hotkeyService: HotkeyServiceProtocol
    private let transformHotkeyService: HotkeyServiceProtocol
    private let ruleEngine: ClipboardRuleEngine
    private let updateService: UpdateService
    private let statsService: StatsService
    private let secureInputDetector = SecureInputDetector()

    private var statusItem: NSStatusItem?
    private lazy var floatingPanelController = FloatingPanelController(
        repository: repository,
        actionService: clipboardActions,
        settings: settings
    )
    private lazy var hotkeyRecorder = HotkeyRecorder(
        settings: settings,
        onSuspend: { [weak self] in self?.hotkeyService.suspend() },
        onResume: { [weak self] in self?.hotkeyService.resume() },
        onHotkeyChange: { [weak self] in self?.reregisterHotkey() }
    )
    private lazy var transformHotkeyRecorder = HotkeyRecorder(
        settings: settings,
        onSuspend: { [weak self] in self?.transformHotkeyService.suspend() },
        onResume: { [weak self] in self?.transformHotkeyService.resume() },
        onHotkeyChange: { [weak self] in self?.setupTransformHotkey() },
        keyCode: { $0.transformHotkeyKeyCode },
        setKeyCode: { $0.transformHotkeyKeyCode = $1 },
        modifiers: { $0.transformHotkeyModifiers },
        setModifiers: { $0.transformHotkeyModifiers = $1 }
    )
    private lazy var lookEditorController = LookEditorController(
        settings: settings,
        repository: repository,
        actionService: clipboardActions,
        onDismiss: { [weak self] in self?.exitLookEditor() }
    )
    private lazy var preferencesWindowController = PreferencesWindowController(
        settings: settings,
        onVisibilityChange: { [weak self] in self?.applyVisibilitySettings() },
        hotkeyRecorder: hotkeyRecorder,
        transformHotkeyRecorder: transformHotkeyRecorder,
        onEditLook: { [weak self] in self?.enterLookEditor() },
        updateService: updateService,
        statsService: statsService
    )

    init(
        settings: SettingsStore = UserDefaultsSettingsStore(),
        context: NSManagedObjectContext = CoreDataStack.shared.viewContext
    ) {
        self.settings = settings
        settings.registerDefaults()
        self.context = context
        repository = CoreDataClipboardRepository(context: context)
        clipboardActions = ClipboardActionService()
        let ruleEngine = ClipboardRuleEngine(presetStore: presetStore)
        self.ruleEngine = ruleEngine
        clipboardService = ClipboardService(repository: repository, settings: settings, ruleEngine: ruleEngine)
        hotkeyService = HotkeyService(settings: settings)
        transformHotkeyService = HotkeyService(
            settings: settings,
            keyCode: { $0.transformHotkeyKeyCode },
            modifiers: { $0.transformHotkeyModifiers }
        )
        updateService = UpdateService(settings: settings)
        statsService = StatsService(context: context)
    }

    func start() {
        setupStatusItem()
        setupHotkey()
        setupTransformHotkey()
        setupKeyboardShortcuts()
        setupSecureInputDetector()
        applyVisibilitySettings()
        clipboardService.onStatEvent = { [weak self] kind in self?.statsService.record(kind) }
        clipboardService.startMonitoring()
        floatingPanelController.onStatEvent = { [weak self] kind in self?.statsService.record(kind) }
        floatingPanelController.onOpenPreferences = { [weak self] in self?.showPreferences() }
        updateService.scheduleAutomaticCheck()
        statsService.record(.launch)
    }

    func stop() {
        clipboardService.stopMonitoring()
        hotkeyService.unregister()
        transformHotkeyService.unregister()
        secureInputDetector.stopMonitoring()
    }

    func handleReopen(hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            toggleFloatingPanel()
        }
        return true
    }

    func applyVisibilitySettings() {
        NSApp.setActivationPolicy(settings.showInDock ? .regular : .accessory)
        statusItem?.isVisible = settings.showInMenuBar
    }

    func reregisterHotkey() {
        hotkeyService.reregister()
    }

    @objc func toggleFloatingPanel() {
        secureInputDetector.check()
        floatingPanelController.toggle()
        statsService.record(.panelOpen)
    }

    @objc func openPreferencesTab(_ sender: NSMenuItem) {
        if let tab = sender.representedObject as? String {
            preferencesWindowController.selectTab(tab)
        }
        showPreferences()
    }

    @objc func showPreferences() {
        if let window = preferencesWindowController.window,
           let screen = NSScreen.main ?? NSScreen.screens.first
        {
            let x = screen.frame.midX - window.frame.width / 2
            let y = screen.frame.midY - window.frame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        preferencesWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func enterLookEditor() {
        preferencesWindowController.window?.orderOut(nil)
        lookEditorController.show()
    }

    private func exitLookEditor() {
        preferencesWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let iconPath = Bundle.main.path(forResource: "menubar_icon@2x", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath)
        {
            image.isTemplate = true
            image.size = NSSize(width: 22, height: 22)
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipMoar")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show ClipMoar", action: #selector(toggleFloatingPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let secureItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        secureItem.tag = 100
        secureItem.isHidden = true
        menu.addItem(secureItem)

        let hintItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        hintItem.tag = 101
        hintItem.isHidden = true
        menu.addItem(hintItem)
        menu.addItem(NSMenuItem.separator())

        let tabs: [(String, String, String, String)] = [
            ("Stats", "stats", "", "chart.bar.fill"),
            ("General", "general", ",", "gearshape"),
            ("Hotkeys", "hotkeys", "", "keyboard"),
            ("Rules", "rules", "", "wand.and.stars"),
            ("Transforms", "transforms", "", "wand.and.rays"),
            ("Presets", "presets", "", "tray.2"),
            ("Regex", "regex", "", "number.circle"),
            ("Images", "images", "", "photo"),
            ("Ignore Apps", "ignore", "", "nosign"),
            ("AI", "ai", "", "brain"),
            ("About", "about", "", "info.circle"),
        ]
        for (title, tag, key, icon) in tabs {
            let item = NSMenuItem(title: title, action: #selector(openPreferencesTab(_:)), keyEquivalent: key)
            item.representedObject = tag
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let versionItem = NSMenuItem(title: "ClipMoar v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        versionItem.attributedTitle = NSAttributedString(string: "ClipMoar v\(version)", attributes: attrs)
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }

        statusItem?.menu = menu
    }

    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command), event.characters == "," {
                self?.showPreferences()
                return nil
            }
            return event
        }
    }

    private func setupHotkey() {
        hotkeyService.register { [weak self] in
            self?.toggleFloatingPanel()
        }
    }

    private func setupTransformHotkey() {
        if settings.transformHotkeyKeyCode == 0 {
            transformHotkeyService.unregister()
            return
        }
        transformHotkeyService.register { [weak self] in
            self?.pasteTransformed()
        }
    }

    private func pasteTransformed() {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        let targetApp = NSWorkspace.shared.frontmostApplication
        let sourceApp = clipboardService.lastSourceAppBundleId ?? targetApp?.bundleIdentifier
        let result = ruleEngine.apply(to: text, sourceAppBundleId: sourceApp)
        let transformed = result.text != text

        NSLog("[ClipMoar] pasteTransformed: source=%@ target=%@ transformed=%d rules=%@",
              sourceApp ?? "nil", targetApp?.bundleIdentifier ?? "nil",
              transformed ? 1 : 0, result.appliedRules.joined(separator: ", "))

        if transformed {
            pasteboard.clearContents()
            pasteboard.setString(result.text, forType: .string)
            pasteboard.setData(Data(), forType: ClipboardActionService.markerType)
        }

        sendPasteEvent(to: targetApp)

        if transformed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                pasteboard.setData(Data(), forType: ClipboardActionService.markerType)
            }
        }
    }

    private func sendPasteEvent(to app: NSRunningApplication?) {
        app?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let source = CGEventSource(stateID: .hidSystemState),
                  let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            else { return }
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    private func setupSecureInputDetector() {
        secureInputDetector.onChange = { [weak self] isActive in
            self?.updateStatusBarIcon(secureInput: isActive)
            self?.floatingPanelController.setSecureInputActive(isActive)
        }
        secureInputDetector.startMonitoring()
    }

    private func updateStatusBarIcon(secureInput: Bool) {
        guard let button = statusItem?.button else { return }
        if let iconPath = Bundle.main.path(forResource: "menubar_icon@2x", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath)
        {
            image.size = NSSize(width: 22, height: 22)
            if secureInput {
                image.isTemplate = false
                button.image = image.tinted(with: .systemRed)
            } else {
                image.isTemplate = true
                button.image = image
            }
        } else {
            let name = secureInput ? "clipboard.fill" : "clipboard"
            let icon = NSImage(systemSymbolName: name, accessibilityDescription: "ClipMoar")
            if secureInput {
                icon?.isTemplate = false
                button.image = icon?.tinted(with: .systemRed)
            } else {
                button.image = icon
            }
        }

        if let secureItem = statusItem?.menu?.item(withTag: 100) {
            secureItem.isHidden = !secureInput
            secureItem.title = secureInput ? "Secure Input is active" : ""
            secureItem.image = secureInput
                ? NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
                : nil
        }

        if let hintItem = statusItem?.menu?.item(withTag: 101) {
            hintItem.isHidden = !secureInput
            if secureInput {
                let hint = "Another app has enabled Secure Keyboard\n"
                    + "Entry. Clipboard monitoring and hotkeys\n"
                    + "will not work until it is disabled."
                let attr = NSAttributedString(string: hint, attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ])
                hintItem.attributedTitle = attr
            }
        }
    }
}
