import Cocoa

enum ClipboardTransformType: String, Codable, CaseIterable {
    case trimWhitespace
    case flattenMultiline
    case stripShellPrompts
    case regexReplace

    var displayName: String {
        switch self {
        case .trimWhitespace: return "Trim whitespace"
        case .flattenMultiline: return "Flatten multiline"
        case .stripShellPrompts: return "Strip shell prompts"
        case .regexReplace: return "Regex replace"
        }
    }

    var icon: String {
        switch self {
        case .trimWhitespace: return "scissors"
        case .flattenMultiline: return "text.alignleft"
        case .stripShellPrompts: return "terminal"
        case .regexReplace: return "magnifyingglass"
        }
    }
}

struct ClipboardRule: Codable, Identifiable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var appBundleId: String?
    var transforms: [ClipboardTransform]

    init(name: String, isEnabled: Bool = true, appBundleId: String? = nil, transforms: [ClipboardTransform] = []) {
        self.id = UUID()
        self.name = name
        self.isEnabled = isEnabled
        self.appBundleId = appBundleId
        self.transforms = transforms
    }

    var appName: String {
        guard let bundleId = appBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return "All Applications"
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    var appIcon: NSImage? {
        guard let bundleId = appBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

struct ClipboardTransform: Codable, Identifiable {
    var id: UUID
    var type: ClipboardTransformType
    var isEnabled: Bool
    var pattern: String
    var replacement: String

    init(type: ClipboardTransformType, isEnabled: Bool = true, pattern: String = "", replacement: String = "") {
        self.id = UUID()
        self.type = type
        self.isEnabled = isEnabled
        self.pattern = pattern
        self.replacement = replacement
    }
}
