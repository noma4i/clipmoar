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
    var panelFontName: String { get set }
    var panelAccentHex: String { get set }
    var panelCornerRadius: Int { get set }
    var panelPaddingH: Int { get set }
    var panelPaddingV: Int { get set }
    var panelMargin: Int { get set }
    var panelFontWeight: Int { get set }
    var panelIconSize: Int { get set }
    var panelVisibleRows: Int { get set }
    var panelTextColorHex: String { get set }
    var previewFontName: String { get set }
    var previewFontSize: Int { get set }
    var previewPadding: Int { get set }
    var previewTextColorHex: String { get set }
    var previewBgColorHex: String { get set }
    var searchFontName: String { get set }
    var searchFontSize: Int { get set }
    var searchTextColorHex: String { get set }
    var searchPlaceholderColorHex: String { get set }
    var metaFontSize: Int { get set }
    var largeTypeFontSize: Int { get set }
    var compressImages: Bool { get set }
    var imageMaxWidth: Int { get set }
    var imageMaxHeight: Int { get set }
    var imageQuality: Int { get set }
    var imageRemoveBackground: Bool { get set }
    var imageConvertToPNG: Bool { get set }
    var imageConvertToJPEG: Bool { get set }
    var imageStripMetadata: Bool { get set }
    var imageAutoEnhance: Bool { get set }
    var imageGrayscale: Bool { get set }
    var imageAutoRotate: Bool { get set }
    var imageTrimWhitespace: Bool { get set }
    var imageSharpen: Bool { get set }
    var imageReduceNoise: Bool { get set }
    var ignoredAppBundleIds: [String] { get set }

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
    static let panelFontName = "panelFontName"
    static let panelAccentHex = "panelAccentHex"
    static let panelCornerRadius = "panelCornerRadius"
    static let panelPaddingH = "panelPaddingH"
    static let panelPaddingV = "panelPaddingV"
    static let panelMargin = "panelMargin"
    static let panelFontWeight = "panelFontWeight"
    static let panelIconSize = "panelIconSize"
    static let panelVisibleRows = "panelVisibleRows"
    static let panelTextColorHex = "panelTextColorHex"
    static let previewFontName = "previewFontName"
    static let previewFontSize = "previewFontSize"
    static let previewPadding = "previewPadding"
    static let previewTextColorHex = "previewTextColorHex"
    static let previewBgColorHex = "previewBgColorHex"
    static let searchFontName = "searchFontName"
    static let searchFontSize = "searchFontSize"
    static let searchTextColorHex = "searchTextColorHex"
    static let searchPlaceholderColorHex = "searchPlaceholderColorHex"
    static let metaFontSize = "metaFontSize"
    static let largeTypeFontSize = "largeTypeFontSize"
    static let compressImages = "compressImages"
    static let imageMaxWidth = "imageMaxWidth"
    static let imageMaxHeight = "imageMaxHeight"
    static let imageQuality = "imageQuality"
    static let imageRemoveBackground = "imageRemoveBackground"
    static let imageConvertToPNG = "imageConvertToPNG"
    static let imageConvertToJPEG = "imageConvertToJPEG"
    static let imageStripMetadata = "imageStripMetadata"
    static let imageAutoEnhance = "imageAutoEnhance"
    static let imageGrayscale = "imageGrayscale"
    static let imageAutoRotate = "imageAutoRotate"
    static let imageTrimWhitespace = "imageTrimWhitespace"
    static let imageSharpen = "imageSharpen"
    static let imageReduceNoise = "imageReduceNoise"
    static let ignoredAppBundleIds = "ignoredAppBundleIds"
}

enum PanelTheme: Int, CaseIterable {
    case dark = 0
    case light = 1

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
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

extension NSColor {
    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1.0
        )
    }

    static func fromHex(_ hex: String) -> NSColor {
        NSColor(hex: hex)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "000000" }
        return String(format: "%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let img = copy() as! NSImage
        img.lockFocus()
        color.set()
        NSRect(origin: .zero, size: img.size).fill(using: .sourceAtop)
        img.unlockFocus()
        img.isTemplate = false
        return img
    }
}

enum PanelTextColor: Int, CaseIterable {
    case white = 0
    case silver = 1
    case cream = 2
    case sky = 3
    case lime = 4
    case peach = 5

    var color: NSColor {
        switch self {
        case .white: return NSColor(calibratedWhite: 0.9, alpha: 1.0)
        case .silver: return NSColor(calibratedWhite: 0.7, alpha: 1.0)
        case .cream: return NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.84, alpha: 1.0)
        case .sky: return NSColor(calibratedRed: 0.75, green: 0.85, blue: 0.95, alpha: 1.0)
        case .lime: return NSColor(calibratedRed: 0.8, green: 0.95, blue: 0.75, alpha: 1.0)
        case .peach: return NSColor(calibratedRed: 0.95, green: 0.82, blue: 0.78, alpha: 1.0)
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

    var panelFontName: String {
        get { defaults.string(forKey: Settings.panelFontName) ?? "" }
        set { defaults.set(newValue, forKey: Settings.panelFontName) }
    }

    var panelAccentHex: String {
        get { defaults.string(forKey: Settings.panelAccentHex) ?? "" }
        set { defaults.set(newValue, forKey: Settings.panelAccentHex) }
    }

    var panelCornerRadius: Int {
        get { defaults.integer(forKey: Settings.panelCornerRadius) }
        set { defaults.set(newValue, forKey: Settings.panelCornerRadius) }
    }

    var panelPaddingH: Int {
        get { defaults.integer(forKey: Settings.panelPaddingH) }
        set { defaults.set(newValue, forKey: Settings.panelPaddingH) }
    }

    var panelPaddingV: Int {
        get { defaults.integer(forKey: Settings.panelPaddingV) }
        set { defaults.set(newValue, forKey: Settings.panelPaddingV) }
    }

    var panelMargin: Int {
        get { defaults.integer(forKey: Settings.panelMargin) }
        set { defaults.set(newValue, forKey: Settings.panelMargin) }
    }

    var panelFontWeight: Int {
        get { defaults.integer(forKey: Settings.panelFontWeight) }
        set { defaults.set(newValue, forKey: Settings.panelFontWeight) }
    }

    var panelIconSize: Int {
        get { defaults.integer(forKey: Settings.panelIconSize) }
        set { defaults.set(newValue, forKey: Settings.panelIconSize) }
    }

    var panelVisibleRows: Int {
        get { defaults.integer(forKey: Settings.panelVisibleRows) }
        set { defaults.set(newValue, forKey: Settings.panelVisibleRows) }
    }

    var panelTextColorHex: String {
        get { defaults.string(forKey: Settings.panelTextColorHex) ?? "" }
        set { defaults.set(newValue, forKey: Settings.panelTextColorHex) }
    }

    var previewFontName: String {
        get { defaults.string(forKey: Settings.previewFontName) ?? "" }
        set { defaults.set(newValue, forKey: Settings.previewFontName) }
    }

    var previewFontSize: Int {
        get { defaults.integer(forKey: Settings.previewFontSize) }
        set { defaults.set(newValue, forKey: Settings.previewFontSize) }
    }

    var previewPadding: Int {
        get { defaults.integer(forKey: Settings.previewPadding) }
        set { defaults.set(newValue, forKey: Settings.previewPadding) }
    }

    var previewTextColorHex: String {
        get { defaults.string(forKey: Settings.previewTextColorHex) ?? "" }
        set { defaults.set(newValue, forKey: Settings.previewTextColorHex) }
    }

    var previewBgColorHex: String {
        get { defaults.string(forKey: Settings.previewBgColorHex) ?? "" }
        set { defaults.set(newValue, forKey: Settings.previewBgColorHex) }
    }

    var searchFontName: String {
        get { defaults.string(forKey: Settings.searchFontName) ?? "" }
        set { defaults.set(newValue, forKey: Settings.searchFontName) }
    }

    var searchFontSize: Int {
        get { defaults.integer(forKey: Settings.searchFontSize) }
        set { defaults.set(newValue, forKey: Settings.searchFontSize) }
    }

    var searchTextColorHex: String {
        get { defaults.string(forKey: Settings.searchTextColorHex) ?? "" }
        set { defaults.set(newValue, forKey: Settings.searchTextColorHex) }
    }

    var searchPlaceholderColorHex: String {
        get { defaults.string(forKey: Settings.searchPlaceholderColorHex) ?? "" }
        set { defaults.set(newValue, forKey: Settings.searchPlaceholderColorHex) }
    }

    var metaFontSize: Int {
        get { defaults.integer(forKey: Settings.metaFontSize) }
        set { defaults.set(newValue, forKey: Settings.metaFontSize) }
    }

    var largeTypeFontSize: Int {
        get { defaults.integer(forKey: Settings.largeTypeFontSize) }
        set { defaults.set(newValue, forKey: Settings.largeTypeFontSize) }
    }

    var compressImages: Bool {
        get { defaults.bool(forKey: Settings.compressImages) }
        set { defaults.set(newValue, forKey: Settings.compressImages) }
    }

    var imageMaxWidth: Int {
        get { defaults.integer(forKey: Settings.imageMaxWidth) }
        set { defaults.set(newValue, forKey: Settings.imageMaxWidth) }
    }

    var imageMaxHeight: Int {
        get { defaults.integer(forKey: Settings.imageMaxHeight) }
        set { defaults.set(newValue, forKey: Settings.imageMaxHeight) }
    }

    var imageQuality: Int {
        get { defaults.integer(forKey: Settings.imageQuality) }
        set { defaults.set(newValue, forKey: Settings.imageQuality) }
    }

    var imageRemoveBackground: Bool {
        get { defaults.bool(forKey: Settings.imageRemoveBackground) }
        set { defaults.set(newValue, forKey: Settings.imageRemoveBackground) }
    }

    var imageConvertToPNG: Bool {
        get { defaults.bool(forKey: Settings.imageConvertToPNG) }
        set { defaults.set(newValue, forKey: Settings.imageConvertToPNG) }
    }

    var imageConvertToJPEG: Bool {
        get { defaults.bool(forKey: Settings.imageConvertToJPEG) }
        set { defaults.set(newValue, forKey: Settings.imageConvertToJPEG) }
    }

    var imageStripMetadata: Bool {
        get { defaults.bool(forKey: Settings.imageStripMetadata) }
        set { defaults.set(newValue, forKey: Settings.imageStripMetadata) }
    }

    var imageAutoEnhance: Bool {
        get { defaults.bool(forKey: Settings.imageAutoEnhance) }
        set { defaults.set(newValue, forKey: Settings.imageAutoEnhance) }
    }

    var imageGrayscale: Bool {
        get { defaults.bool(forKey: Settings.imageGrayscale) }
        set { defaults.set(newValue, forKey: Settings.imageGrayscale) }
    }

    var imageAutoRotate: Bool {
        get { defaults.bool(forKey: Settings.imageAutoRotate) }
        set { defaults.set(newValue, forKey: Settings.imageAutoRotate) }
    }

    var imageTrimWhitespace: Bool {
        get { defaults.bool(forKey: Settings.imageTrimWhitespace) }
        set { defaults.set(newValue, forKey: Settings.imageTrimWhitespace) }
    }

    var imageSharpen: Bool {
        get { defaults.bool(forKey: Settings.imageSharpen) }
        set { defaults.set(newValue, forKey: Settings.imageSharpen) }
    }

    var imageReduceNoise: Bool {
        get { defaults.bool(forKey: Settings.imageReduceNoise) }
        set { defaults.set(newValue, forKey: Settings.imageReduceNoise) }
    }

    var ignoredAppBundleIds: [String] {
        get {
            guard let data = defaults.data(forKey: Settings.ignoredAppBundleIds),
                  let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return ids
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Settings.ignoredAppBundleIds)
        }
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
            Settings.panelFontName: "",
            Settings.panelAccentHex: "2672B5",
            Settings.panelCornerRadius: 0,
            Settings.panelPaddingH: 12,
            Settings.panelPaddingV: 4,
            Settings.panelMargin: 0,
            Settings.panelFontWeight: 0,
            Settings.panelIconSize: 22,
            Settings.panelVisibleRows: 9,
            Settings.panelTextColorHex: "E6E6E6",
            Settings.previewFontName: "",
            Settings.previewFontSize: 11,
            Settings.previewPadding: 10,
            Settings.previewTextColorHex: "D9D9D9",
            Settings.previewBgColorHex: "1A1A1A",
            Settings.searchFontName: "",
            Settings.searchFontSize: 16,
            Settings.searchTextColorHex: "E6E6E6",
            Settings.searchPlaceholderColorHex: "666666",
            Settings.metaFontSize: 10,
            Settings.largeTypeFontSize: 48,
            Settings.compressImages: false,
            Settings.imageMaxWidth: 0,
            Settings.imageMaxHeight: 0,
            Settings.imageQuality: 80,
        ])
    }
}
