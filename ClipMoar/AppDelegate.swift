import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = UserDefaultsSettingsStore()
        settings.registerDefaults()
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator.handleReopen(hasVisibleWindows: flag)
    }
}
