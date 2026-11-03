import Cocoa

MainActor.assumeIsolated {
    let app = NSApplication.shared
    if SingleInstance.shouldTerminate(runningPids: SingleInstance.runningPids(), current: ProcessInfo.processInfo.processIdentifier) {
        SingleInstance.runningOthers().first?.activate()
        exit(0)
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
