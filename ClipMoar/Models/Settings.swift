import Carbon
import Cocoa

protocol SettingsStore: AnyObject {
    var showInDock: Bool { get set }
    var showInMenuBar: Bool { get set }
    var maxHistorySize: Int { get set }
    var hotkeyKeyCode: Int { get set }
    var hotkeyModifiers: UInt32 { get set }
    var storeImages: Bool { get set }
    var panelPositionX: Double { get set }
    var panelPositionY: Double { get set }
    var panelScreenMode: Int { get set }

    func registerDefaults()
}

enum PanelScreenMode: Int, CaseIterable {
    case defaultScreen = 0
    case mouseScreen = 1
    case activeScreen = 2

    var title: String {
        switch self {
        case .defaultScreen: return "Default Screen"
        case .mouseScreen: return "Mouse Screen"
        case .activeScreen: return "Active Screen"
        }
    }
}

enum Settings {
    static let showInDock = "showInDock"
    static let showInMenuBar = "showInMenuBar"
    static let maxHistorySize = "maxHistorySize"
    static let hotkeyKeyCode = "hotkeyKeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
    static let storeImages = "storeImages"
    static let panelPositionX = "panelPositionX"
    static let panelPositionY = "panelPositionY"
    static let panelScreenMode = "panelScreenMode"
}

final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var showInDock: Bool {
        get { defaults.bool(forKey: Settings.showInDock) }
        set { defaults.set(newValue, forKey: Settings.showInDock) }
    }

    var showInMenuBar: Bool {
        get { defaults.bool(forKey: Settings.showInMenuBar) }
        set { defaults.set(newValue, forKey: Settings.showInMenuBar) }
    }

    var maxHistorySize: Int {
        get { max(1, defaults.integer(forKey: Settings.maxHistorySize)) }
        set { defaults.set(max(1, newValue), forKey: Settings.maxHistorySize) }
    }

    var hotkeyKeyCode: Int {
        get { defaults.integer(forKey: Settings.hotkeyKeyCode) }
        set { defaults.set(newValue, forKey: Settings.hotkeyKeyCode) }
    }

    var hotkeyModifiers: UInt32 {
        get { UInt32(defaults.integer(forKey: Settings.hotkeyModifiers)) }
        set { defaults.set(Int(newValue), forKey: Settings.hotkeyModifiers) }
    }

    var storeImages: Bool {
        get { defaults.bool(forKey: Settings.storeImages) }
        set { defaults.set(newValue, forKey: Settings.storeImages) }
    }

    var panelPositionX: Double {
        get { defaults.double(forKey: Settings.panelPositionX) }
        set { defaults.set(newValue, forKey: Settings.panelPositionX) }
    }

    var panelPositionY: Double {
        get { defaults.double(forKey: Settings.panelPositionY) }
        set { defaults.set(newValue, forKey: Settings.panelPositionY) }
    }

    var panelScreenMode: Int {
        get { defaults.integer(forKey: Settings.panelScreenMode) }
        set { defaults.set(newValue, forKey: Settings.panelScreenMode) }
    }

    func registerDefaults() {
        defaults.register(defaults: [
            Settings.showInDock: true,
            Settings.showInMenuBar: true,
            Settings.maxHistorySize: 500,
            Settings.hotkeyKeyCode: kVK_ANSI_V,
            Settings.hotkeyModifiers: NSEvent.ModifierFlags.shift.rawValue | NSEvent.ModifierFlags.command.rawValue,
            Settings.storeImages: true,
            Settings.panelPositionX: 0.5,
            Settings.panelPositionY: 0.65,
            Settings.panelScreenMode: PanelScreenMode.defaultScreen.rawValue
        ])
    }
}
