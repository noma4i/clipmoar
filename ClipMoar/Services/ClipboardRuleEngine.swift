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
        store.load()
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
            guard let data = Data(base64Encoded: text), let decoded = String(data: data, encoding: .utf8) else { return text }
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

    private func dedentText(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmpty.isEmpty else { return text }
        let minIndent = nonEmpty.map { $0.prefix(while: { $0 == " " || $0 == "\t" }).count }.min() ?? 0
        guard minIndent > 0 else { return text }
        return lines.map { $0.count >= minIndent ? String($0.dropFirst(minIndent)) : $0 }.joined(separator: "\n")
    }

    private func joinParagraphs(_ text: String) -> String {
        var result: [String] = []
        var current = ""
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty { result.append(current); current = "" }
                result.append("")
            } else {
                current = current.isEmpty ? line : current + " " + line.trimmingCharacters(in: .whitespaces)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.joined(separator: "\n")
    }

    private func prettyPrintJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return text }
        return str
    }

    private func minifyJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let compact = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: compact, encoding: .utf8) else { return text }
        return str
    }

    private func jsonToYAML(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return text }
        return yamlEncode(obj, indent: 0)
    }

    private func yamlEncode(_ value: Any, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent)
        if let dict = value as? [String: Any] {
            return dict.sorted(by: { $0.key < $1.key }).map { key, val in
                if let arr = val as? [Any] {
                    return "\(pad)\(key):\n" + arr.map { "\(pad)  - \(yamlScalar($0))" }.joined(separator: "\n")
                } else if val is [String: Any] {
                    return "\(pad)\(key):\n\(yamlEncode(val, indent: indent + 1))"
                }
                return "\(pad)\(key): \(yamlScalar(val))"
            }.joined(separator: "\n")
        }
        return "\(pad)\(yamlScalar(value))"
    }

    private func yamlScalar(_ value: Any) -> String {
        switch value {
        case let s as String: return s.contains(":") || s.contains("#") ? "\"\(s)\"" : s
        case let n as NSNumber where CFBooleanGetTypeID() == CFGetTypeID(n): return n.boolValue ? "true" : "false"
        case let n as NSNumber: return "\(n)"
        case is NSNull: return "null"
        default: return "\(value)"
        }
    }

    private func htmlToMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<strong>(.*?)</strong>"#, with: "**$1**", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<b>(.*?)</b>"#, with: "**$1**", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<em>(.*?)</em>"#, with: "*$1*", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<i>(.*?)</i>"#, with: "*$1*", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<code>(.*?)</code>"#, with: "`$1`", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<a\s+href="([^"]*)"[^>]*>(.*?)</a>"#, with: "[$2]($1)", options: .regularExpression)
        for level in 1 ... 6 {
            let hashes = String(repeating: "#", count: level)
            result = result.replacingOccurrences(of: "<h\(level)[^>]*>(.*?)</h\(level)>", with: "\(hashes) $1", options: .regularExpression)
        }
        result = result.replacingOccurrences(of: #"<li>(.*?)</li>"#, with: "- $1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        return result
    }

    private static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "gclsrc", "dclid", "msclkid",
        "mc_cid", "mc_eid", "ref", "ref_src", "ref_url",
    ]

    private func stripTrackingParams(_ text: String) -> String {
        guard var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return text }
        guard let items = components.queryItems, !items.isEmpty else { return text }
        let filtered = items.filter { !Self.trackingParams.contains($0.name.lowercased()) }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.string ?? text
    }

    private func extractURLs(_ text: String) -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let detector else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)
        let urls = matches.compactMap { $0.url?.absoluteString }
        guard !urls.isEmpty else { return text }
        return urls.joined(separator: "\n")
    }
}
