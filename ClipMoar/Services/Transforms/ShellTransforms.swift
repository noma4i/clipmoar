import Foundation

extension ClipboardRuleEngine {
    static let knownCommands: Set<String> = [
        "sudo", "apt", "brew", "git", "python", "pip", "pnpm", "npm", "yarn",
        "cargo", "bundle", "rails", "go", "make", "xcodebuild", "swift",
        "kubectl", "docker", "podman", "aws", "gcloud", "az",
        "ls", "cd", "cat", "echo", "env", "export", "open", "node",
        "java", "ruby", "perl", "bash", "zsh", "sh", "curl", "wget",
        "rm", "cp", "mv", "mkdir", "chmod", "chown", "grep", "find", "sed", "awk",
    ]

    static let searchPaths = [
        "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin",
        "/usr/sbin", "/bin", "/sbin",
    ]

    func isKnownCommand(_ word: String) -> Bool {
        let cmd = word.lowercased()
        if Self.knownCommands.contains(cmd) { return true }
        if cmd.contains("/") || cmd.hasPrefix("./") || cmd.hasPrefix("~/") { return true }
        for dir in Self.searchPaths {
            if FileManager.default.isExecutableFile(atPath: "\(dir)/\(cmd)") { return true }
        }
        return false
    }

    func stripPrompts(_ text: String) -> String {
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

    func stripSinglePrompt(_ line: String) -> String? {
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

    func flattenCommands(_ text: String) -> String {
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

    func collapseMultilineBash(_ text: String) -> String {
        guard text.contains("\n") else { return text }

        let lines = text.components(separatedBy: "\n")
        let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let tokens = firstLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return text }

        var commandToken = tokens[0]
        if commandToken == "sudo", tokens.count > 1 {
            commandToken = tokens[1]
        }

        guard isKnownCommand(commandToken) else { return text }

        var result = text
        result = result.replacingOccurrences(of: #"\\\s*\n"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
