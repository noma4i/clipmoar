import Carbon
import Cocoa

final class TransformGestureController {
    enum State {
        case idle
        case pending(gestureID: UUID)
        case overlay(gestureID: UUID)
    }

    private let overlayController: TransformOverlayController
    private let onInstantPaste: () -> Void
    private let readModifiers: () -> NSEvent.ModifierFlags
    private let readHoldDelay: () -> TimeInterval
    private let hasQuickPresets: () -> Bool

    private(set) var state: State = .idle
    private var holdTimer: DispatchSourceTimer?
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    init(
        overlay: TransformOverlayController,
        onInstantPaste: @escaping () -> Void,
        readModifiers: @escaping () -> NSEvent.ModifierFlags,
        readHoldDelay: @escaping () -> TimeInterval = { 0.5 },
        hasQuickPresets: @escaping () -> Bool = { true }
    ) {
        overlayController = overlay
        self.onInstantPaste = onInstantPaste
        self.readModifiers = readModifiers
        self.readHoldDelay = readHoldDelay
        self.hasQuickPresets = hasQuickPresets
    }

    func handleHotkeyPress() {
        switch state {
        case .idle:
            if hasQuickPresets() {
                beginPending()
            } else {
                onInstantPaste()
            }
        case .pending:
            break
        case .overlay:
            overlayController.selectNext()
        }
    }

    private func beginPending() {
        let gestureID = UUID()
        state = .pending(gestureID: gestureID)
        startMonitors()
        scheduleHoldTimer(for: gestureID)
    }

    private func scheduleHoldTimer(for gestureID: UUID) {
        holdTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + readHoldDelay())
        timer.setEventHandler { [weak self] in
            self?.handleHoldTimer(gestureID: gestureID)
        }
        holdTimer = timer
        timer.resume()
    }

    private func handleHoldTimer(gestureID: UUID) {
        guard case let .pending(currentID) = state, currentID == gestureID else { return }
        guard areModifiersHeld() else {
            performInstantPaste()
            return
        }
        overlayController.show()
        state = .overlay(gestureID: gestureID)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let required = readModifiers()
        let current = event.modifierFlags.intersection([.command, .option, .control, .shift])

        switch state {
        case let .pending(gestureID):
            if !required.isSubset(of: current) {
                holdTimer?.cancel()
                holdTimer = nil
                performInstantPaste()
                _ = gestureID
            }
        case .overlay:
            if !required.isSubset(of: current) {
                overlayController.dismiss(paste: true)
                cleanup()
            }
        case .idle:
            break
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard case .overlay = state else { return }
        if event.keyCode == 53 {
            overlayController.dismiss(paste: false)
            cleanup()
        }
    }

    private func performInstantPaste() {
        onInstantPaste()
        cleanup()
    }

    private func areModifiersHeld() -> Bool {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(CGEventSource.flagsState(.combinedSessionState).rawValue))
        let current = flags.intersection([.command, .option, .control, .shift])
        return readModifiers().isSubset(of: current)
    }

    private func startMonitors() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
    }

    private func cleanup() {
        holdTimer?.cancel()
        holdTimer = nil
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m); globalFlagsMonitor = nil }
        if let m = localFlagsMonitor { NSEvent.removeMonitor(m); localFlagsMonitor = nil }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
        if let m = localKeyMonitor { NSEvent.removeMonitor(m); localKeyMonitor = nil }
        state = .idle
    }
}
