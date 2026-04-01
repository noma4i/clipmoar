import Foundation

extension ClipboardRuleEngine {
    static let boxDrawingPattern = "[│┃╎╏┆┇┊┋╽╿￨｜]"

    private static let invisibleCodepoints: Set<UInt32> = {
        var set: Set<UInt32> = [
            0x00A0, 0x00AD, 0x034F, 0x061C,
            0x115F, 0x1160, 0x1680, 0x17B4, 0x17B5, 0x180E,
            0x200B, 0x200C, 0x200D, 0x200E, 0x200F,
            0x202F, 0x205F, 0x2060, 0x2061, 0x2062, 0x2063, 0x2064, 0x2065,
            0x2800, 0x3000, 0x3164, 0xFEFF, 0xFFA0, 0xFFFC,
        ]
        for cp in 0x2000 ... 0x200A {
            set.insert(UInt32(cp))
        }
        for cp in 0x206A ... 0x206F {
            set.insert(UInt32(cp))
        }
        for cp in 0xFFF9 ... 0xFFFB {
            set.insert(UInt32(cp))
        }
        return set
    }()

    func stripNonASCII(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if Self.invisibleCodepoints.contains(scalar.value) {
                result.append("\u{1F479}")
            } else {
                result.append(Character(scalar))
            }
        }
        return result
    }

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

    func camelToSnake(_ text: String) -> String {
        var result = ""
        for (i, ch) in text.enumerated() {
            if ch.isUppercase {
                if i > 0 { result.append("_") }
                result.append(ch.lowercased())
            } else {
                result.append(ch)
            }
        }
        return result
    }

    func snakeToCamel(_ text: String) -> String {
        let parts = text.components(separatedBy: "_")
        guard let first = parts.first else { return text }
        return first + parts.dropFirst().map(\.capitalized).joined()
    }

    func toKebabCase(_ text: String) -> String {
        let snake = camelToSnake(text)
        return snake.replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
    }

    func reverseLines(_ text: String) -> String {
        text.components(separatedBy: "\n").reversed().joined(separator: "\n")
    }

    func markdownQuote(_ text: String) -> String {
        text.components(separatedBy: "\n").map { "> \($0)" }.joined(separator: "\n")
    }

    func countStats(_ text: String) -> String {
        let chars = text.count
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        let lines = text.components(separatedBy: "\n").count
        return "Characters: \(chars)\nWords: \(words)\nLines: \(lines)"
    }

    func numberLines(_ text: String) -> String {
        text.components(separatedBy: "\n").enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
    }
}
