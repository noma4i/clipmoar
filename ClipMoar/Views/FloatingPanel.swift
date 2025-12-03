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
        FloatingPanelController.shared.dismiss()
    }
}

final class FloatingPanelController: NSWindowController {
    static let shared = FloatingPanelController()
    private let clipViewController = FloatingClipboardViewController()

    private convenience init() {
        let panel = FloatingPanel()
        self.init(window: panel)
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
        guard let panel = window else { return }

        clipViewController.refresh()

        panel.contentView = clipViewController.view
        panel.setContentSize(NSSize(width: 460, height: 344))
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
