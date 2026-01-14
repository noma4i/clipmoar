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

    private static let knownCommands: Set<String> = [
        "sudo", "apt", "brew", "git", "python", "pip", "pnpm", "npm", "yarn",
        "cargo", "bundle", "rails", "go", "make", "xcodebuild", "swift",
        "kubectl", "docker", "podman", "aws", "gcloud", "az",
        "ls", "cd", "cat", "echo", "env", "export", "open", "node",
        "java", "ruby", "perl", "bash", "zsh", "sh", "curl", "wget",
        "rm", "cp", "mv", "mkdir", "chmod", "chown", "grep", "find", "sed", "awk",
    ]

    private static let boxDrawingPattern = "[│┃╎╏┆┇┊┋╽╿￨｜]"

    private func applyTransform(_ transform: ClipboardTransform, to text: String) -> String {
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
        }
    }

    private func stripPrompts(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmpty.isEmpty else { return text }

        var strippedCount = 0
        let rebuilt = lines.map { line -> String in
            if let stripped = stripSinglePrompt(line) {
                strippedCount += 1
                return stripped
            }
            return line
        }

        let threshold = nonEmpty.count == 1 ? 1 : (nonEmpty.count / 2 + 1)
        guard strippedCount >= threshold else { return text }

        let result = rebuilt.joined(separator: "\n")
        return result == text ? text : result
    }

    private func stripSinglePrompt(_ line: String) -> String? {
        let leading = line.prefix(while: { $0.isWhitespace })
        let remainder = line.dropFirst(leading.count)
        guard let first = remainder.first, first == "$" || first == "#" || first == ">" else { return nil }
        let afterPrompt = remainder.dropFirst().drop(while: { $0.isWhitespace })
        guard !afterPrompt.isEmpty else { return nil }

        let firstToken = String(afterPrompt.prefix(while: { !$0.isWhitespace })).lowercased()
        let isKnown = Self.knownCommands.contains(where: { firstToken.hasPrefix($0) })
            || firstToken.contains("/") || firstToken.hasPrefix("./") || firstToken.hasPrefix("~/")

        guard isKnown else { return nil }
        return String(leading) + String(afterPrompt)
    }

    private func flattenCommands(_ text: String) -> String {
        guard text.contains("\n") else { return text }

        let hasBackslashContinuation = text.contains("\\\n")
        let hasLineJoiner = text.range(of: #"(?m)(\\|[|&]{1,2}|;)\s*$"#, options: .regularExpression) != nil
        let hasPipeline = text.range(of: #"(?m)^\s*[|&]{1,2}\s+\S"#, options: .regularExpression) != nil

        guard hasBackslashContinuation || hasLineJoiner || hasPipeline else { return text }

        var result = text
        result = result.replacingOccurrences(of: #"\\\s*\n"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeBoxDrawing(_ text: String) -> String {
        guard text.range(of: Self.boxDrawingPattern, options: .regularExpression) != nil else { return text }

        var result = text
        result = result.replacingOccurrences(
            of: #"\s*"# + Self.boxDrawingPattern + #"+\s*"#,
            with: " ", options: .regularExpression
        )
        result = result.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func repairWrappedURL(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return text }
        let schemeCount = lower.components(separatedBy: "https://").count - 1
            + lower.components(separatedBy: "http://").count - 1
        guard schemeCount == 1 else { return text }

        let collapsed = trimmed.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        guard collapsed != trimmed else { return text }
        guard collapsed.range(of: #"^https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+$"#, options: .regularExpression) != nil else { return text }

        return collapsed
    }

    private func quotePathsWithSpaces(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n") else { return text }

        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) { return text }

        guard trimmed.contains(" ") else { return text }
        guard !trimmed.contains("://") else { return text }

        let hasPathPrefix = trimmed.hasPrefix("/") || trimmed.hasPrefix("~/")
            || trimmed.hasPrefix("./") || trimmed.hasPrefix("../")
        let hasSlash = trimmed.contains("/")

        guard hasPathPrefix || hasSlash else { return text }

        if trimmed.range(of: #"\s-[A-Za-z]"#, options: .regularExpression) != nil { return text }

        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
