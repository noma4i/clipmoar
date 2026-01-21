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
    var panelFontSize: Int { get set }
    var panelTheme: Int { get set }
    var panelAccentColor: Int { get set }
    var largeTypeFontSize: Int { get set }

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
    static let panelFontSize = "panelFontSize"
    static let panelTheme = "panelTheme"
    static let panelAccentColor = "panelAccentColor"
    static let largeTypeFontSize = "largeTypeFontSize"
}

enum PanelTheme: Int, CaseIterable {
    case dark = 0
    case light = 1
    case system = 2

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }
}

enum PanelFontSize: Int, CaseIterable {
    case small = 12
    case medium = 15
    case large = 18

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum AccentColor: Int, CaseIterable {
    case blue = 0
    case purple = 1
    case green = 2
    case orange = 3
    case red = 4
    case gray = 5

    var title: String {
        switch self {
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .green: return "Green"
        case .orange: return "Orange"
        case .red: return "Red"
        case .gray: return "Gray"
        }
    }

    var color: NSColor {
        switch self {
        case .blue: return NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.65, alpha: 0.9)
        case .purple: return NSColor(calibratedRed: 0.45, green: 0.25, blue: 0.65, alpha: 0.9)
        case .green: return NSColor(calibratedRed: 0.2, green: 0.55, blue: 0.35, alpha: 0.9)
        case .orange: return NSColor(calibratedRed: 0.7, green: 0.45, blue: 0.15, alpha: 0.9)
        case .red: return NSColor(calibratedRed: 0.65, green: 0.2, blue: 0.2, alpha: 0.9)
        case .gray: return NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.38, alpha: 0.9)
        }
    }
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

    var panelFontSize: Int {
        get { defaults.integer(forKey: Settings.panelFontSize) }
        set { defaults.set(newValue, forKey: Settings.panelFontSize) }
    }

    var panelTheme: Int {
        get { defaults.integer(forKey: Settings.panelTheme) }
        set { defaults.set(newValue, forKey: Settings.panelTheme) }
    }

    var panelAccentColor: Int {
        get { defaults.integer(forKey: Settings.panelAccentColor) }
        set { defaults.set(newValue, forKey: Settings.panelAccentColor) }
    }

    var largeTypeFontSize: Int {
        get { defaults.integer(forKey: Settings.largeTypeFontSize) }
        set { defaults.set(newValue, forKey: Settings.largeTypeFontSize) }
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
            Settings.largeTypeEnabled: true,
            Settings.panelFontSize: PanelFontSize.medium.rawValue,
            Settings.panelTheme: PanelTheme.dark.rawValue,
            Settings.panelAccentColor: AccentColor.blue.rawValue,
            Settings.largeTypeFontSize: 48,
        ])
    }
}
