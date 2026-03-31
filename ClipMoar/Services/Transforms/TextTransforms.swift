import Foundation

extension ClipboardRuleEngine {
    static let boxDrawingPattern = "[│┃╎╏┆┇┊┋╽╿￨｜]"

    func removeBoxDrawing(_ text: String) -> String {
        guard text.range(of: Self.boxDrawingPattern, options: .regularExpression) != nil else { return text }

        var result = text
        result = result.replacingOccurrences(
            of: #"\s*"# + Self.boxDrawingPattern + #"+\s*"#,
            with: " ", options: .regularExpression
        )
        result = result.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func repairWrappedURL(_ text: String) -> String {
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

    func quotePathsWithSpaces(_ text: String) -> String {
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

    func dedentText(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmpty.isEmpty else { return text }
        let minIndent = nonEmpty.map { $0.prefix(while: { $0 == " " || $0 == "\t" }).count }.min() ?? 0
        guard minIndent > 0 else { return text }
        return lines.map { $0.count >= minIndent ? String($0.dropFirst(minIndent)) : $0 }.joined(separator: "\n")
    }

    func joinParagraphs(_ text: String) -> String {
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

    private func isStructuralLine(_ trimmed: String) -> Bool {
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") { return true }
        if trimmed.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) != nil { return true }
        if trimmed.hasPrefix("```") { return true }
        if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") { return true }
        if trimmed.hasPrefix("#") { return true }
        if trimmed.hasPrefix(">") { return true }
        return false
    }

    private func lineIndent(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 4 }
            else { break }
        }
        return count
    }

    func smartJoinLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var current = ""
        var currentIndent = 0
        var inCodeFence = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = lineIndent(line)

            if trimmed.hasPrefix("```") {
                if !current.isEmpty { result.append(current); current = "" }
                result.append(line)
                inCodeFence.toggle()
                continue
            }

            if inCodeFence {
                result.append(line)
                continue
            }

            if trimmed.isEmpty {
                if !current.isEmpty { result.append(current); current = "" }
                result.append("")
            } else if isStructuralLine(trimmed) {
                if !current.isEmpty { result.append(current); current = "" }
                result.append(line)
            } else if indent >= 4 || line.hasPrefix("\t") {
                if !current.isEmpty { result.append(current); current = "" }
                result.append(line)
            } else if current.isEmpty {
                current = trimmed
                currentIndent = indent
            } else {
                current = current + " " + trimmed
            }
        }
        if !current.isEmpty { result.append(current) }
        return result.joined(separator: "\n")
    }
}
