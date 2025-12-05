import Cocoa

final class FloatingPanel: NSPanel {
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
        backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1.0)
        hasShadow = false
        hidesOnDeactivate = true
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }
}

final class FloatingPanelController: NSWindowController {
    private let clipViewController: FloatingClipboardViewController

    init(repository: ClipboardRepository, actionService: ClipboardActionServicing) {
        let panel = FloatingPanel()
        self.clipViewController = FloatingClipboardViewController(
            repository: repository,
            actionService: actionService
        )
        super.init(window: panel)
        panel.contentView = clipViewController.view
    }

    required init?(coder: NSCoder) { nil }

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
        guard let panel = window else { return }

        clipViewController.refresh()

        panel.setFrame(NSRect(x: 0, y: 0, width: 460, height: 344), display: false)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            panel.makeFirstResponder(self.clipViewController.tableView)
        }
    }

    func dismiss() {
        window?.orderOut(nil)
    }
}
