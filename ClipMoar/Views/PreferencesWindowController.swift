import Cocoa
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(settings: SettingsStore, onVisibilityChange: @escaping () -> Void, hotkeyRecorder: HotkeyRecorder) {
        let settingsView = SettingsView(settings: settings, hotkeyRecorder: hotkeyRecorder)
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
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 720, height: 480)
        window.setAccessibilityIdentifier("preferences_window")
        window.contentViewController = hostingController
        window.center()
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

    required init?(coder: NSCoder) { nil }
}
