import Cocoa

final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 274),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        level = .floating
        isOpaque = true
        backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        hasShadow = true
        hidesOnDeactivate = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 10
        contentView?.layer?.masksToBounds = true
        contentView?.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0).cgColor
    }

    override func resignKey() {
        super.resignKey()
        FloatingPanelController.shared.dismiss()
    }
}

final class FloatingPanelController: NSWindowController {
    static let shared = FloatingPanelController()

    private convenience init() {
        let panel = FloatingPanel()
        panel.contentViewController = FloatingClipboardViewController()
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
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let vc = panel.contentViewController as? FloatingClipboardViewController {
            vc.refresh()
            vc.focusOnList()
        }
    }

    func dismiss() {
        window?.orderOut(nil)
    }
}
