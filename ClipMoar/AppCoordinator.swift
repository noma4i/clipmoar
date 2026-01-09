import Cocoa
import CoreData

final class AppCoordinator {
    private let settings: SettingsStore
    private let context: NSManagedObjectContext
    private let repository: ClipboardRepository
    private let clipboardActions: ClipboardActionServicing
    private let clipboardService: ClipboardService
    private let hotkeyService: HotkeyServiceProtocol

    private var statusItem: NSStatusItem?
    private var mainWindowController: MainWindowController?
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
    private lazy var preferencesWindowController = PreferencesWindowController(
        settings: settings,
        onVisibilityChange: { [weak self] in self?.applyVisibilitySettings() },
        hotkeyRecorder: hotkeyRecorder
    )

    init(
        settings: SettingsStore = UserDefaultsSettingsStore(),
        context: NSManagedObjectContext = CoreDataStack.shared.viewContext
    ) {
        self.settings = settings
        self.context = context
        self.repository = CoreDataClipboardRepository(context: context)
        self.clipboardActions = ClipboardActionService()
        self.clipboardService = ClipboardService(repository: repository, settings: settings)
        self.hotkeyService = HotkeyService(settings: settings)
    }

    func start() {
        setupStatusItem()
        setupHotkey()
        setupKeyboardShortcuts()
        applyVisibilitySettings()
        clipboardService.startMonitoring()
        floatingPanelController.onOpenPreferences = { [weak self] in self?.showPreferences() }
    }

    func stop() {
        clipboardService.stopMonitoring()
        hotkeyService.unregister()
    }

    func handleReopen(hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            showMainWindow()
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

    @objc func showMainWindow() {
        if mainWindowController == nil {
            let historyController = ClipboardHistoryViewController(
                repository: repository,
                actionService: clipboardActions,
                context: context
            )
            mainWindowController = MainWindowController(historyViewController: historyController)
        }

        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleFloatingPanel() {
        floatingPanelController.toggle()
    }

    @objc func showPreferences() {
        preferencesWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let iconPath = Bundle.main.path(forResource: "menubar_icon@2x", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath) {
            image.isTemplate = true
            image.size = NSSize(width: 22, height: 22)
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipMoar")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show ClipMoar", action: #selector(showMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Clipboard", action: #selector(toggleFloatingPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items {
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
}
