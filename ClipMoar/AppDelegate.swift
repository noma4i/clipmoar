import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindowController: MainWindowController?
    private let clipboardService = ClipboardService()
    private let hotkeyService = HotkeyService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        setupStatusItem()
        setupHotkey()
        applyVisibilitySettings()
        clipboardService.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardService.stopMonitoring()
        hotkeyService.unregister()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindowController?.showWindow(nil)
        }
        return true
    }

    // MARK: - Status Item

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
        statusItem?.menu = menu
    }

    // MARK: - Main Window

    private func setupMainWindow() {
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyService.register { [weak self] in
            self?.toggleFloatingPanel()
        }
    }

    func reregisterHotkey() {
        hotkeyService.reregister()
    }

    // MARK: - Visibility

    func applyVisibilitySettings() {
        let showInDock = UserDefaults.standard.bool(forKey: Settings.showInDock)
        let showInMenuBar = UserDefaults.standard.bool(forKey: Settings.showInMenuBar)

        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        statusItem?.isVisible = showInMenuBar
    }

    // MARK: - Actions

    @objc private func showMainWindow() {
        mainWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleFloatingPanel() {
        FloatingPanelController.shared.toggle()
    }

    @objc private func showPreferences() {
        PreferencesWindowController.shared.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
