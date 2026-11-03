import Cocoa

enum SingleInstance {
    static func shouldTerminate(runningPids: [pid_t], current: pid_t) -> Bool {
        runningPids.contains { $0 != current }
    }

    static func runningOthers() -> [NSRunningApplication] {
        guard let id = Bundle.main.bundleIdentifier else { return [] }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }

    static func runningPids() -> [pid_t] {
        guard let id = Bundle.main.bundleIdentifier else { return [] }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).map(\.processIdentifier)
    }
}
