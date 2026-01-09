import Carbon
import Cocoa

protocol SettingsStore: AnyObject {
    var showInDock: Bool { get set }
    var showInMenuBar: Bool { get set }
    var maxHistorySize: Int { get set }
    var hotkeyKeyCode: Int { get set }
    var hotkeyModifiers: UInt32 { get set }
    var storeText: Bool { get set }
    var storeImages: Bool { get set }
    var textRetentionHours: Int { get set }
    var imageRetentionHours: Int { get set }
    var panelPositionX: Double { get set }
    var panelPositionY: Double { get set }
    var panelScreenMode: Int { get set }
    var largeTypeEnabled: Bool { get set }

    func registerDefaults()
}

enum TextRetention: Int, CaseIterable {
    case oneDay = 24
    case threeDays = 72
    case oneWeek = 168
    case oneMonth = 720
    case threeMonths = 2160
    case forever = 0

    var title: String {
        switch self {
        case .oneDay: return "24 Hours"
        case .threeDays: return "3 Days"
        case .oneWeek: return "7 Days"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .forever: return "Forever"
        }
    }
}

enum ImageRetention: Int, CaseIterable {
    case oneDay = 24
    case oneWeek = 168
    case oneMonth = 720
    case threeMonths = 2160

    var title: String {
        switch self {
        case .oneDay: return "24 Hours"
        case .oneWeek: return "7 Days"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        }
    }
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
    static let storeText = "storeText"
    static let storeImages = "storeImages"
    static let textRetentionHours = "textRetentionHours"
    static let imageRetentionHours = "imageRetentionHours"
    static let panelPositionX = "panelPositionX"
    static let panelPositionY = "panelPositionY"
    static let panelScreenMode = "panelScreenMode"
    static let largeTypeEnabled = "largeTypeEnabled"
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

    var storeText: Bool {
        get { defaults.bool(forKey: Settings.storeText) }
        set { defaults.set(newValue, forKey: Settings.storeText) }
    }

    var storeImages: Bool {
        get { defaults.bool(forKey: Settings.storeImages) }
        set { defaults.set(newValue, forKey: Settings.storeImages) }
    }

    var textRetentionHours: Int {
        get { defaults.integer(forKey: Settings.textRetentionHours) }
        set { defaults.set(newValue, forKey: Settings.textRetentionHours) }
    }

    var imageRetentionHours: Int {
        get { defaults.integer(forKey: Settings.imageRetentionHours) }
        set { defaults.set(newValue, forKey: Settings.imageRetentionHours) }
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

    var largeTypeEnabled: Bool {
        get { defaults.bool(forKey: Settings.largeTypeEnabled) }
        set { defaults.set(newValue, forKey: Settings.largeTypeEnabled) }
    }

    func registerDefaults() {
        defaults.register(defaults: [
            Settings.showInDock: true,
            Settings.showInMenuBar: true,
            Settings.maxHistorySize: 500,
            Settings.hotkeyKeyCode: kVK_ANSI_V,
            Settings.hotkeyModifiers: NSEvent.ModifierFlags.shift.rawValue | NSEvent.ModifierFlags.command.rawValue,
            Settings.storeText: true,
            Settings.storeImages: true,
            Settings.textRetentionHours: TextRetention.forever.rawValue,
            Settings.imageRetentionHours: ImageRetention.oneDay.rawValue,
            Settings.panelPositionX: 0.5,
            Settings.panelPositionY: 0.65,
            Settings.panelScreenMode: PanelScreenMode.defaultScreen.rawValue,
            Settings.largeTypeEnabled: true
        ])
    }
}
