import CompanionKit
import Foundation

struct NotePaths {
    let bundle: URL
    var hasScreenshot = true
    var annotated: URL {
        bundle.appendingPathComponent("annotated.png")
    }

    var screenshot: URL {
        bundle.appendingPathComponent("screenshot.png")
    }
}

final class NoteBundle {
    private let base: URL
    private var sessions: [String: URL] = [:]

    init(base: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipMoar/Notes")) {
        self.base = base.standardizedFileURL
    }

    static func summary(_ note: Note, paths: NotePaths?) -> String {
        guard let paths else { return note.phrases.map(\.text).joined(separator: " ") }
        func time(_ value: Double) -> String {
            let seconds = max(0, Int(value))
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        func line(_ mark: NoteMark) -> String {
            let number = (1 ... 20).contains(mark.number) ? String(UnicodeScalar(0x2460 + mark.number - 1)!) : "(\(mark.number))"
            let location = mark.on.map { " in \($0)," } ?? ""
            return "✎\(number) \(time(mark.start))\(location) at \(mark.x),\(mark.y) \(mark.width)x\(mark.height)"
        }
        var header = "DrawMoar note · \(time(note.duration))"
        if let name = note.displayName { header += " · \(name) \(note.width)x\(note.height)" }
        var lines = [header, ""]
        var used = Set<Int>()
        for phrase in note.phrases {
            let marks = phrase.marks.compactMap { number in note.marks.first { $0.number == number } }
            if marks.isEmpty {
                lines.append("\(time(phrase.start)) \(phrase.text)")
            } else {
                lines.append(contentsOf: marks.map(line))
                lines.append("  \(phrase.text)")
                used.formUnion(marks.map(\.number))
            }
        }
        lines.append(contentsOf: note.marks.filter { !used.contains($0.number) }.map(line))
        lines.append("")
        lines.append("Image with marks: \(paths.annotated.path)")
        if paths.hasScreenshot { lines.append("Screenshot: \(paths.screenshot.path)") }
        lines.append("Bundle: \(paths.bundle.path)")
        return lines.joined(separator: "\n")
    }

    func write(annotated: Data, screenshot: Data, note: Note, session: String) throws -> String {
        guard !annotated.isEmpty || !screenshot.isEmpty else { return Self.summary(note, paths: nil) }
        let manager = FileManager.default
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        let suffix = String(session.prefix(8))
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        let existing = try manager.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey]).first { url in
            guard url.lastPathComponent.hasSuffix("-" + suffix),
                  let data = try? Data(contentsOf: url.appendingPathComponent("note.json")),
                  let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
            return object["session"] as? String == session
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var directory = sessions[session] ?? existing ?? base.appendingPathComponent("\(formatter.string(from: Date()))-\(suffix)", isDirectory: true)
        var date = Date()
        while sessions[session] == nil, existing == nil, manager.fileExists(atPath: directory.path) {
            date.addTimeInterval(1)
            directory = base.appendingPathComponent("\(formatter.string(from: date))-\(suffix)", isDirectory: true)
        }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let paths = NotePaths(bundle: directory, hasScreenshot: !screenshot.isEmpty)
        let text = Self.summary(note, paths: paths)
        try annotated.write(to: paths.annotated, options: .atomic)
        if screenshot.isEmpty {
            try? manager.removeItem(at: paths.screenshot)
        } else {
            try screenshot.write(to: paths.screenshot, options: .atomic)
        }
        try text.write(to: directory.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as! [String: Any]
        object["session"] = session
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: directory.appendingPathComponent("note.json"), options: .atomic)
        try manager.setAttributes([.modificationDate: Date()], ofItemAtPath: directory.path)
        sessions[session] = directory
        return text
    }

    func removeExpired(now: Date = Date()) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: base.path) else { return }
        for url in try manager.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey]) {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            if values.isDirectory == true, let date = values.contentModificationDate, date < now.addingTimeInterval(-30 * 24 * 60 * 60) {
                try manager.removeItem(at: url)
                sessions = sessions.filter { $0.value != url }
            }
        }
    }
}
