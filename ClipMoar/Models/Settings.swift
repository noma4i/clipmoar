import Carbon
import Cocoa

enum Settings {
    static let showInDock = "showInDock"
    static let showInMenuBar = "showInMenuBar"
    static let maxHistorySize = "maxHistorySize"
    static let hotkeyKeyCode = "hotkeyKeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
    static let storeImages = "storeImages"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showInDock: true,
            showInMenuBar: true,
            maxHistorySize: 500,
            hotkeyKeyCode: kVK_ANSI_V,
            hotkeyModifiers: NSEvent.ModifierFlags.shift.rawValue | NSEvent.ModifierFlags.command.rawValue,
            storeImages: true
        ])
    }
}
