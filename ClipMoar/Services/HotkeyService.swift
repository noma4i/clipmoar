import Carbon
import Cocoa

protocol HotkeyServiceProtocol: AnyObject {
    func register(onTrigger: @escaping () -> Void)
    func reregister()
    func unregister()
    func suspend()
    func resume()
}

final class HotkeyService: HotkeyServiceProtocol {
    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTrigger: (() -> Void)?
    private var settings: SettingsStore = UserDefaultsSettingsStore()

    init(settings: SettingsStore = UserDefaultsSettingsStore()) {
        self.settings = settings
    }

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
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        onTrigger = nil
    }

    func suspend() {
        if let ref = eventHotKey {
            UnregisterEventHotKey(ref)
            eventHotKey = nil
        }
    }

    func resume() {
        guard onTrigger != nil else { return }
        registerHotkey()
    }

    private func registerHotkey() {
        let keyCode = settings.hotkeyKeyCode
        let modifiers = Int(settings.hotkeyModifiers)
        let carbonModifiers = carbonFlags(from: NSEvent.ModifierFlags(rawValue: UInt(modifiers)))

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C5052) // "CLPR"
        hotKeyID.id = 1

        if eventHandler == nil {
            var handlerRef: EventHandlerRef?
            var spec = eventTypeSpec()
            InstallEventHandler(
                GetApplicationEventTarget(),
                hotkeyEventHandler(),
                1,
                &spec,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
            eventHandler = handlerRef
        }

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

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

    private func eventTypeSpec() -> EventTypeSpec {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)
        return eventType
    }

    private func hotkeyEventHandler() -> EventHandlerUPP {
        { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                service.onTrigger?()
            }
            return noErr
        }
    }
}
