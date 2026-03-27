import Cocoa
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    private let settings: SettingsStore

    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void, hotkeyRecorder: HotkeyRecorder, onEditLook: (() -> Void)? = nil, updateService: UpdateService? = nil, statsService: StatsService? = nil) {
        self.settings = settings
        let settingsView = SettingsView(settings: settings, hotkeyRecorder: hotkeyRecorder, onVisibilityChange: onVisibilityChange, onEditLook: onEditLook, updateService: updateService, statsService: statsService)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 720, height: 480)
        window.setAccessibilityIdentifier("preferences_window")
        window.contentViewController = hostingController
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53,
                  self?.window?.isVisible == true,
                  self?.window?.isKeyWindow == true else { return event }
            self?.close()
            return nil
        }
    }

    override func showWindow(_ sender: Any?) {
        if let screen = targetScreen(), let window = window {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY - windowSize.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        super.showWindow(sender)
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

    required init?(coder _: NSCoder) {
        nil
    }
}
