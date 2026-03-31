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

private final class CarbonHotkeyRegistry {
    static let shared = CarbonHotkeyRegistry()
    private var services: [UInt32: HotkeyService] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextId: UInt32 = 1

    func allocateId() -> UInt32 {
        let id = nextId
        nextId += 1
        return id
    }

    func register(id: UInt32, service: HotkeyService) {
        services[id] = service
        installHandlerIfNeeded()
    }

    func unregister(id: UInt32) {
        services.removeValue(forKey: id)
        if services.isEmpty, let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var handlerRef: EventHandlerRef?
        var spec = EventTypeSpec()
        spec.eventClass = OSType(kEventClassKeyboard)
        spec.eventKind = UInt32(kEventHotKeyPressed)
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return OSStatus(eventNotHandledErr) }
                let id = hotKeyID.id
                DispatchQueue.main.async {
                    CarbonHotkeyRegistry.shared.services[id]?.fireTrigger()
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &handlerRef
        )
        eventHandler = handlerRef
    }
}

final class RealCarbonBackend: CarbonHotkeyBackend {
    private var eventHotKey: EventHotKeyRef?
    private let hotkeyId: UInt32

    init() {
        hotkeyId = CarbonHotkeyRegistry.shared.allocateId()
    }

    var isHotkeyRegistered: Bool {
        eventHotKey != nil
    }

    var isHandlerInstalled: Bool {
        true
    }

    func installHandler(service: HotkeyService) {
        CarbonHotkeyRegistry.shared.register(id: hotkeyId, service: service)
    }

    func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C_5052)
        hotKeyID.id = hotkeyId
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
        CarbonHotkeyRegistry.shared.unregister(id: hotkeyId)
    }
}

final class HotkeyService: HotkeyServiceProtocol {
    private var onTrigger: (() -> Void)?
    private let settings: SettingsStore
    private let backend: CarbonHotkeyBackend
    private let readKeyCode: (SettingsStore) -> Int
    private let readModifiers: (SettingsStore) -> UInt32

    init(
        settings: SettingsStore = UserDefaultsSettingsStore(),
        backend: CarbonHotkeyBackend = RealCarbonBackend(),
        keyCode: @escaping (SettingsStore) -> Int = { $0.hotkeyKeyCode },
        modifiers: @escaping (SettingsStore) -> UInt32 = { $0.hotkeyModifiers }
    ) {
        self.settings = settings
        self.backend = backend
        readKeyCode = keyCode
        readModifiers = modifiers
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
        let keyCode = readKeyCode(settings)
        let modifiers = Int(readModifiers(settings))
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
