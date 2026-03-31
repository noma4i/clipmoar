import CommonCrypto
import Foundation

extension ClipboardRuleEngine {
    func prettyPrintJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return text }
        return str
    }

    func minifyJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let compact = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: compact, encoding: .utf8) else { return text }
        return str
    }

    func jsonToYAML(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return text }
        return yamlEncode(obj, indent: 0)
    }

    func yamlEncode(_ value: Any, indent: Int) -> String {
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

    func yamlScalar(_ value: Any) -> String {
        switch value {
        case let s as String: return s.contains(":") || s.contains("#") ? "\"\(s)\"" : s
        case let n as NSNumber where CFBooleanGetTypeID() == CFGetTypeID(n): return n.boolValue ? "true" : "false"
        case let n as NSNumber: return "\(n)"
        case is NSNull: return "null"
        default: return "\(value)"
        }
    }

    func htmlToMarkdown(_ text: String) -> String {
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

    static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "gclsrc", "dclid", "msclkid",
        "mc_cid", "mc_eid", "ref", "ref_src", "ref_url",
    ]

    func stripTrackingParams(_ text: String) -> String {
        guard var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return text }
        guard let items = components.queryItems, !items.isEmpty else { return text }
        let filtered = items.filter { !Self.trackingParams.contains($0.name.lowercased()) }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.string ?? text
    }

    func extractURLs(_ text: String) -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let detector else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)
        let urls = matches.compactMap { $0.url?.absoluteString }
        guard !urls.isEmpty else { return text }
        return urls.joined(separator: "\n")
    }

    func htmlEncode(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    func htmlDecode(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    func addSlashes(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    func removeSlashes(_ text: String) -> String {
        text.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\'", with: "'")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    func md5Hash(_ text: String) -> String {
        let data = Data(text.utf8)
        var digest = [UInt8](repeating: 0, count: 16)
        _ = data.withUnsafeBytes { CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func sha256Hash(_ text: String) -> String {
        let data = Data(text.utf8)
        var digest = [UInt8](repeating: 0, count: 32)
        _ = data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func rot13(_ text: String) -> String {
        String(text.map { ch in
            switch ch {
            case "a" ... "m", "A" ... "M":
                return Character(UnicodeScalar(ch.asciiValue! + 13))
            case "n" ... "z", "N" ... "Z":
                return Character(UnicodeScalar(ch.asciiValue! - 13))
            default:
                return ch
            }
        })
    }

    func jsonToQueryString(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return text }
        let pairs = json.sorted { $0.key < $1.key }.compactMap { key, value -> String? in
            let v = "\(value)"
            guard let encoded = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return "\(key)=\(encoded)"
        }
        return pairs.joined(separator: "&")
    }

    func queryStringToJson(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = trimmed.hasPrefix("?") ? String(trimmed.dropFirst()) : trimmed
        var dict: [String: String] = [:]
        for pair in query.components(separatedBy: "&") {
            let parts = pair.components(separatedBy: "=")
            guard parts.count == 2 else { continue }
            dict[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: data, encoding: .utf8)
        else { return text }
        return result
    }
}
