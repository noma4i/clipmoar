import Foundation

protocol ClipboardRuleStore: AnyObject {
    var rules: [ClipboardRule] { get set }
    func save()
    func load()
}

final class UserDefaultsRuleStore: ClipboardRuleStore {
    private let key = "clipboardRules"
    private let defaults: UserDefaults

    var rules: [ClipboardRule] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: key)
    }

    func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ClipboardRule].self, from: data)
        else {
            rules = [ClipboardRule(name: "Default", transforms: defaultTransforms())]
            save()
            return
        }
        rules = decoded
    }

    private func defaultTransforms() -> [ClipboardTransform] {
        [ClipboardTransform(type: .trimWhitespace, isEnabled: true)]
    }
}

final class ClipboardRuleEngine {
    private let store: ClipboardRuleStore
    var presetStore: PresetStore?

    init(store: ClipboardRuleStore = UserDefaultsRuleStore(), presetStore: PresetStore? = nil) {
        self.store = store
        self.presetStore = presetStore
    }

    var rules: [ClipboardRule] {
        get { store.rules }
        set { store.rules = newValue; store.save() }
    }

    struct ApplyResult {
        let text: String
        let appliedRules: [String]
    }

    func apply(to text: String, sourceAppBundleId: String? = nil) -> ApplyResult {
        store.load()
        presetStore?.load()
        var result = text
        var appliedRules: [String] = []

        for rule in store.rules where rule.isEnabled {
            if let ruleApp = rule.appBundleId, ruleApp != sourceAppBundleId {
                continue
            }
            let before = result
            if let presetUUID = UUID(uuidString: rule.presetId),
               let preset = presetStore?.presets.first(where: { $0.id == presetUUID })
            {
                for type in preset.transformTypes {
                    result = applyTransform(ClipboardTransform(type: type), to: result)
                }
            }
            for transform in rule.transforms where transform.isEnabled {
                result = applyTransform(transform, to: result)
            }
            if result != before {
                appliedRules.append(rule.name)
            }
        }

        return ApplyResult(text: result, appliedRules: appliedRules)
    }

    func applyTransform(_ transform: ClipboardTransform, to text: String) -> String {
        switch transform.type {
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        case .flattenMultiline:
            return flattenCommands(text)

        case .stripShellPrompts:
            return stripPrompts(text)

        case .removeBoxDrawing:
            return removeBoxDrawing(text)

        case .repairWrappedURL:
            return repairWrappedURL(text)

        case .quotePathsWithSpaces:
            return quotePathsWithSpaces(text)

        case .regexReplace:
            guard !transform.pattern.isEmpty,
                  let regex = try? NSRegularExpression(pattern: transform.pattern) else { return text }
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: transform.replacement)

        case .normalizeQuotes:
            return text
                .replacingOccurrences(of: "\u{201C}", with: "\"")
                .replacingOccurrences(of: "\u{201D}", with: "\"")
                .replacingOccurrences(of: "\u{2018}", with: "'")
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: "\u{00AB}", with: "\"")
                .replacingOccurrences(of: "\u{00BB}", with: "\"")

        case .tabsToSpaces:
            return text.replacingOccurrences(of: "\t", with: "    ")

        case .dedent:
            return dedentText(text)

        case .joinParagraphs:
            return joinParagraphs(text)

        case .collapseBlankLines:
            return text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        case .sortLines:
            let lines = text.components(separatedBy: "\n")
            return lines.sorted().joined(separator: "\n")

        case .uniqueLines:
            var seen = Set<String>()
            return text.components(separatedBy: "\n").filter { seen.insert($0).inserted }.joined(separator: "\n")

        case .commentLines:
            return text.components(separatedBy: "\n").map { "# \($0)" }.joined(separator: "\n")

        case .escapeJSON:
            return text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")

        case .unescapeJSON:
            return text
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")

        case .escapeShell:
            return "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"

        case .urlEncode:
            return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text

        case .urlDecode:
            return text.removingPercentEncoding ?? text

        case .base64Encode:
            return Data(text.utf8).base64EncodedString()

        case .base64Decode:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters),
                  let decoded = String(data: data, encoding: .utf8) else { return text }
            return decoded

        case .prettyJSON:
            return prettyPrintJSON(text)

        case .minifyJSON:
            return minifyJSON(text)

        case .jsonToYAML:
            return jsonToYAML(text)

        case .htmlToMarkdown:
            return htmlToMarkdown(text)

        case .stripTrackingParams:
            return stripTrackingParams(text)

        case .extractURLs:
            return extractURLs(text)

        case .collapseMultilineBash:
            return collapseMultilineBash(text)

        case .smartJoinLines:
            return smartJoinLines(text)
        }
    }
}
