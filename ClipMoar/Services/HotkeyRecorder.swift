import Cocoa

enum HotkeyRecorderResult {
    case recorded(keyCode: Int, modifiers: UInt32)
    case cancelled
    case rejected(reason: String)
    case needsModifier
}

final class HotkeyRecorder {
    private let settings: SettingsStore
    private let onSuspend: () -> Void
    private let onResume: () -> Void
    private let onHotkeyChange: () -> Void
    private let getKeyCode: (SettingsStore) -> Int
    private let setKeyCode: (SettingsStore, Int) -> Void
    private let getModifiers: (SettingsStore) -> UInt32
    private let setModifiers: (SettingsStore, UInt32) -> Void

    private(set) var isRecording = false
    private var savedKeyCode: Int = 0
    private var savedModifiers: UInt32 = 0
    private var localMonitor: Any?

    var onResult: ((HotkeyRecorderResult) -> Void)?

    private static let reservedShortcuts: Set<String> = [
        "Cmd+C", "Cmd+V", "Cmd+X", "Cmd+Z", "Cmd+A", "Cmd+S",
        "Cmd+Q", "Cmd+W", "Cmd+N", "Cmd+O", "Cmd+P", "Cmd+F",
        "Cmd+H", "Cmd+M", "Cmd+Tab", "Cmd+Space",
    ]

    init(
        settings: SettingsStore,
        onSuspend: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onHotkeyChange: @escaping () -> Void,
        keyCode: @escaping (SettingsStore) -> Int = { $0.hotkeyKeyCode },
        setKeyCode: @escaping (SettingsStore, Int) -> Void = { $0.hotkeyKeyCode = $1 },
        modifiers: @escaping (SettingsStore) -> UInt32 = { $0.hotkeyModifiers },
        setModifiers: @escaping (SettingsStore, UInt32) -> Void = { $0.hotkeyModifiers = $1 }
    ) {
        self.settings = settings
        self.onSuspend = onSuspend
        self.onResume = onResume
        self.onHotkeyChange = onHotkeyChange
        getKeyCode = keyCode
        self.setKeyCode = setKeyCode
        getModifiers = modifiers
        self.setModifiers = setModifiers
    }

    func startRecording() {
        savedKeyCode = getKeyCode(settings)
        savedModifiers = getModifiers(settings)
        isRecording = true
        onSuspend()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.handleKeyEvent(event)
            return nil
        }
    }

    func cancel() {
        guard isRecording else { return }
        setKeyCode(settings, savedKeyCode)
        setModifiers(settings, savedModifiers)
        stopMonitor()
        onResume()
        onResult?(.cancelled)
    }

    func clearHotkey() {
        setKeyCode(settings, 0)
        setModifiers(settings, 0)
        onHotkeyChange()
    }

    var currentShortcutString: String {
        let kc = getKeyCode(settings)
        let mods = getModifiers(settings)
        guard kc != 0 || mods != 0 else { return "Not assigned" }
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(mods))
        return KeyboardShortcutFormatter.string(for: kc, modifiers: modifiers)
    }

    func isReserved(_ shortcut: String) -> Bool {
        Self.reservedShortcuts.contains(shortcut)
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == 53 {
            cancel()
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            onResult?(.needsModifier)
            return
        }

        let shortcutStr = KeyboardShortcutFormatter.string(for: Int(event.keyCode), modifiers: modifiers)

        if Self.reservedShortcuts.contains(shortcutStr) {
            onResult?(.rejected(reason: shortcutStr))
            return
        }

        setKeyCode(settings, Int(event.keyCode))
        setModifiers(settings, UInt32(modifiers.rawValue))
        stopMonitor()
        onHotkeyChange()
        onResult?(.recorded(keyCode: Int(event.keyCode), modifiers: UInt32(modifiers.rawValue)))
    }

    private func stopMonitor() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }
}
