import Cocoa

final class MainWindowController: NSWindowController {
    convenience init(historyViewController: ClipboardHistoryViewController) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipMoar"
        window.center()
        window.contentViewController = historyViewController
        window.setFrameAutosaveName("MainWindow")

        self.init(window: window)
    }
}
