import Cocoa

enum ClipboardTransformType: String, Codable, CaseIterable {
    case trimWhitespace
    case flattenMultiline
    case stripShellPrompts
    case removeBoxDrawing
    case repairWrappedURL
    case quotePathsWithSpaces
    case regexReplace
    case normalizeQuotes
    case tabsToSpaces
    case dedent
    case joinParagraphs
    case collapseBlankLines
    case sortLines
    case uniqueLines
    case commentLines
    case escapeJSON
    case unescapeJSON
    case escapeShell
    case urlEncode
    case urlDecode
    case base64Encode
    case base64Decode
    case prettyJSON
    case minifyJSON
    case jsonToYAML
    case htmlToMarkdown
    case stripTrackingParams
    case extractURLs

    var displayName: String {
        switch self {
        case .trimWhitespace: return "Trim whitespace"
        case .flattenMultiline: return "Flatten multiline"
        case .stripShellPrompts: return "Strip shell prompts"
        case .removeBoxDrawing: return "Remove box-drawing"
        case .repairWrappedURL: return "Repair wrapped URLs"
        case .quotePathsWithSpaces: return "Quote paths"
        case .regexReplace: return "Regex replace"
        case .normalizeQuotes: return "Normalize quotes"
        case .tabsToSpaces: return "Tabs to spaces"
        case .dedent: return "Dedent"
        case .joinParagraphs: return "Join paragraphs"
        case .collapseBlankLines: return "Collapse blanks"
        case .sortLines: return "Sort lines"
        case .uniqueLines: return "Unique lines"
        case .commentLines: return "Comment lines"
        case .escapeJSON: return "Escape JSON"
        case .unescapeJSON: return "Unescape JSON"
        case .escapeShell: return "Escape shell"
        case .urlEncode: return "URL encode"
        case .urlDecode: return "URL decode"
        case .base64Encode: return "Base64 encode"
        case .base64Decode: return "Base64 decode"
        case .prettyJSON: return "Pretty JSON"
        case .minifyJSON: return "Minify JSON"
        case .jsonToYAML: return "JSON to YAML"
        case .htmlToMarkdown: return "HTML to Markdown"
        case .stripTrackingParams: return "Strip tracking"
        case .extractURLs: return "Extract URLs"
        }
    }

    var icon: String {
        switch self {
        case .trimWhitespace: return "scissors"
        case .flattenMultiline: return "text.alignleft"
        case .stripShellPrompts: return "terminal"
        case .removeBoxDrawing: return "rectangle.slash"
        case .repairWrappedURL: return "link"
        case .quotePathsWithSpaces: return "quote.opening"
        case .regexReplace: return "magnifyingglass"
        case .normalizeQuotes: return "textformat.abc"
        case .tabsToSpaces: return "arrow.right.to.line"
        case .dedent: return "decrease.indent"
        case .joinParagraphs: return "text.justify.leading"
        case .collapseBlankLines: return "arrow.up.and.down.text.horizontal"
        case .sortLines: return "arrow.up.arrow.down"
        case .uniqueLines: return "line.3.horizontal.decrease"
        case .commentLines: return "number"
        case .escapeJSON: return "curlybraces"
        case .unescapeJSON: return "curlybraces"
        case .escapeShell: return "terminal.fill"
        case .urlEncode: return "percent"
        case .urlDecode: return "percent"
        case .base64Encode: return "lock"
        case .base64Decode: return "lock.open"
        case .prettyJSON: return "text.badge.plus"
        case .minifyJSON: return "text.badge.minus"
        case .jsonToYAML: return "doc.text"
        case .htmlToMarkdown: return "chevron.left.forwardslash.chevron.right"
        case .stripTrackingParams: return "eye.slash"
        case .extractURLs: return "link.badge.plus"
        }
    }
}

struct ClipboardRule: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var appBundleId: String?
    var transforms: [ClipboardTransform]

    init(name: String, isEnabled: Bool = true, appBundleId: String? = nil, transforms: [ClipboardTransform] = []) {
        id = UUID()
        self.name = name
        self.isEnabled = isEnabled
        self.appBundleId = appBundleId
        self.transforms = transforms
    }

    var appName: String {
        guard let bundleId = appBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        else {
            return "All Applications"
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    var appIcon: NSImage? {
        guard let bundleId = appBundleId,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
        else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

struct ClipboardTransform: Codable, Identifiable, Equatable {
    var id: UUID
    var type: ClipboardTransformType
    var isEnabled: Bool
    var pattern: String
    var replacement: String
    var regexId: String

    init(type: ClipboardTransformType, isEnabled: Bool = true, pattern: String = "", replacement: String = "", regexId: String = "") {
        id = UUID()
        self.type = type
        self.isEnabled = isEnabled
        self.pattern = pattern
        self.replacement = replacement
        self.regexId = regexId
    }
}
