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
        actionService: clipboardActions
    )
    private lazy var preferencesWindowController = PreferencesWindowController(
        settings: settings,
        onVisibilityChange: { [weak self] in self?.applyVisibilitySettings() },
        onHotkeyChange: { [weak self] in self?.reregisterHotkey() }
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
        applyVisibilitySettings()
        clipboardService.startMonitoring()
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

        button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipMoar")

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

    private func setupHotkey() {
        hotkeyService.register { [weak self] in
            self?.toggleFloatingPanel()
        }
    }
}
