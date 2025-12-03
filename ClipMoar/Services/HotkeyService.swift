import Carbon
import Cocoa

final class HotkeyService {
    private var eventHotKey: EventHotKeyRef?
    private var onTrigger: (() -> Void)?

    func register(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        registerHotkey()
    }

    func reregister() {
        unregister()
        registerHotkey()
    }

    func unregister() {
        if let ref = eventHotKey {
            UnregisterEventHotKey(ref)
            eventHotKey = nil
        }
    }

    private func registerHotkey() {
        let keyCode = UserDefaults.standard.integer(forKey: Settings.hotkeyKeyCode)
        let modifiers = UserDefaults.standard.integer(forKey: Settings.hotkeyModifiers)
        let carbonModifiers = carbonFlags(from: NSEvent.ModifierFlags(rawValue: UInt(modifiers)))

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C5052) // "CLPR"
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        let handlerPtr = UnsafeMutablePointer<HotkeyService>.allocate(capacity: 1)
        handlerPtr.initialize(to: self)

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    service.onTrigger?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKey
        )
    }

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift) { result |= shiftKey }
        return result
    }
}
