import Carbon
import Cocoa

protocol HotkeyServiceProtocol: AnyObject {
    func register(onTrigger: @escaping () -> Void)
    func reregister()
    func unregister()
    func suspend()
    func resume()
}

protocol CarbonHotkeyBackend: AnyObject {
    var isHotkeyRegistered: Bool { get }
    var isHandlerInstalled: Bool { get }
    func installHandler(service: HotkeyService)
    func registerHotkey(keyCode: UInt32, modifiers: UInt32)
    func unregisterHotkey()
    func removeHandler()
}

final class RealCarbonBackend: CarbonHotkeyBackend {
    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    var isHotkeyRegistered: Bool {
        eventHotKey != nil
    }

    var isHandlerInstalled: Bool {
        eventHandler != nil
    }

    func installHandler(service: HotkeyService) {
        guard eventHandler == nil else { return }
        var handlerRef: EventHandlerRef?
        var spec = EventTypeSpec()
        spec.eventClass = OSType(kEventClassKeyboard)
        spec.eventKind = UInt32(kEventHotKeyPressed)
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let svc = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { svc.fireTrigger() }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(service).toOpaque(),
            &handlerRef
        )
        eventHandler = handlerRef
    }

    func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C_5052)
        hotKeyID.id = 1
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKey
        )
    }

    func unregisterHotkey() {
        if let ref = eventHotKey {
            UnregisterEventHotKey(ref)
            eventHotKey = nil
        }
    }

    func removeHandler() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

final class HotkeyService: HotkeyServiceProtocol {
    private var onTrigger: (() -> Void)?
    private let settings: SettingsStore
    private let backend: CarbonHotkeyBackend

    init(
        settings: SettingsStore = UserDefaultsSettingsStore(),
        backend: CarbonHotkeyBackend = RealCarbonBackend()
    ) {
        self.settings = settings
        self.backend = backend
    }

    func fireTrigger() {
        onTrigger?()
    }

    func register(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        registerHotkey()
    }

    func reregister() {
        unregisterCarbon()
        registerHotkey()
    }

    func unregister() {
        unregisterCarbon()
        onTrigger = nil
    }

    func suspend() {
        backend.unregisterHotkey()
    }

    func resume() {
        guard onTrigger != nil else { return }
        registerHotkey()
    }

    private func unregisterCarbon() {
        backend.unregisterHotkey()
        backend.removeHandler()
    }

    private func registerHotkey() {
        let keyCode = settings.hotkeyKeyCode
        let modifiers = Int(settings.hotkeyModifiers)
        let carbonModifiers = carbonFlags(from: NSEvent.ModifierFlags(rawValue: UInt(modifiers)))
        backend.installHandler(service: self)
        backend.registerHotkey(keyCode: UInt32(keyCode), modifiers: UInt32(carbonModifiers))
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
