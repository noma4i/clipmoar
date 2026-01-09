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
              let decoded = try? JSONDecoder().decode([ClipboardRule].self, from: data) else {
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

    init(store: ClipboardRuleStore = UserDefaultsRuleStore()) {
        self.store = store
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
        var result = text
        var appliedRules: [String] = []

        for rule in store.rules where rule.isEnabled {
            if let ruleApp = rule.appBundleId, ruleApp != sourceAppBundleId {
                continue
            }
            let before = result
            for transform in rule.transforms where transform.isEnabled {
                result = applyTransform(transform, to: result)
            }
            if result != before {
                appliedRules.append(rule.name)
            }
        }

        return ApplyResult(text: result, appliedRules: appliedRules)
    }

    private func applyTransform(_ transform: ClipboardTransform, to text: String) -> String {
        switch transform.type {
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        case .flattenMultiline:
            return text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

        case .stripShellPrompts:
            return text
                .components(separatedBy: .newlines)
                .map { line in
                    var stripped = line
                    if let range = stripped.range(of: #"^[\$#>]\s*"#, options: .regularExpression) {
                        stripped.removeSubrange(range)
                    }
                    return stripped
                }
                .joined(separator: "\n")

        case .regexReplace:
            guard !transform.pattern.isEmpty,
                  let regex = try? NSRegularExpression(pattern: transform.pattern) else { return text }
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: transform.replacement)
        }
    }
}
