import Cocoa
import CoreData

final class AppCoordinator {
    private let settings: SettingsStore
    private let context: NSManagedObjectContext
    private let repository: ClipboardRepository
    private let clipboardActions: ClipboardActionServicing
    private let clipboardService: ClipboardService
    private let hotkeyService: HotkeyServiceProtocol
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
        clipboardService = ClipboardService(repository: repository, settings: settings)
        hotkeyService = HotkeyService(settings: settings)
        updateService = UpdateService(settings: settings)
        statsService = StatsService(context: context)
    }

    func start() {
        setupStatusItem()
        setupHotkey()
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

        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
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
