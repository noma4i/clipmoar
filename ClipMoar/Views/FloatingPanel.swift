import Cocoa

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

final class FloatingPanel: KeyablePanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 344),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isMovableByWindowBackground = true
        level = .floating
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        hidesOnDeactivate = true
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override func resignKey() {
        super.resignKey()
        if hidesOnDeactivate {
            orderOut(nil)
        }
    }
}

final class FloatingPanelController: NSWindowController {
    private let clipViewController: FloatingClipboardViewController
    private let settings: SettingsStore

    var onOpenPreferences: (() -> Void)? {
        get { clipViewController.onOpenPreferences }
        set { clipViewController.onOpenPreferences = newValue }
    }

    var onStatEvent: ((StatEventKind) -> Void)? {
        get { clipViewController.onStatEvent }
        set { clipViewController.onStatEvent = newValue }
    }

    init(repository: ClipboardRepository, actionService: ClipboardActionServicing, settings: SettingsStore = UserDefaultsSettingsStore()) {
        let panel = FloatingPanel()
        self.settings = settings
        clipViewController = FloatingClipboardViewController(
            repository: repository,
            actionService: actionService,
            settings: settings
        )
        super.init(window: panel)
        panel.contentView = clipViewController.view
    }

    required init?(coder _: NSCoder) {
        nil
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            dismiss()
        } else {
            present()
        }
    }

    func present() {
        guard let panel = window,
              let screen = targetScreen() else { return }

        clipViewController.previousApp = NSWorkspace.shared.frontmostApplication

        let configuration = settings.panelConfiguration()
        let panelWidth = configuration.layout.listWidth

        clipViewController.refresh()

        let panelHeight = configuration.layout.panelHeight
        let screenFrame = screen.visibleFrame

        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) * settings.panelPositionX
        let y = screenFrame.origin.y + (screenFrame.height - panelHeight) * settings.panelPositionY

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        clipViewController.updateAccessibilityBanner()

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            panel.makeFirstResponder(self.clipViewController.tableView)
        }
    }

    func dismiss() {
        window?.orderOut(nil)
        (window as? FloatingPanel)?.hidesOnDeactivate = true
    }

    func refreshTheme() {
        clipViewController.applyTheme()
    }

    func setSticky(_ sticky: Bool) {
        (window as? FloatingPanel)?.hidesOnDeactivate = !sticky
    }

    func setSecureInputActive(_ active: Bool) {
        clipViewController.updateSecureInputBanner(isActive: active)
    }

    private func targetScreen() -> NSScreen? {
        let mode = PanelScreenMode(rawValue: settings.panelScreenMode) ?? .defaultScreen
        switch mode {
        case .defaultScreen:
            return NSScreen.screens.first
        case .mouseScreen:
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        case .activeScreen:
            return NSApp.keyWindow?.screen ?? NSScreen.main
        }
    }
}
