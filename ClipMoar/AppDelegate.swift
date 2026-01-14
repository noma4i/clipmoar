import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_: Notification) {
        let settings = UserDefaultsSettingsStore()
        settings.registerDefaults()
        coordinator.start()
    }

    func applicationWillTerminate(_: Notification) {
        coordinator.stop()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator.handleReopen(hasVisibleWindows: flag)
    }
}
