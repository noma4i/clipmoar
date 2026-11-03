@testable import ClipMoar
import CompanionKit
import Foundation
import XCTest

final class NoteBundleTests: XCTestCase {
    func testSummaryAndBundleReplacement() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let bundle = NoteBundle(base: base)
        let marks = [NoteMark(number: 1, start: 5, x: 120, y: 840, width: 640, height: 90, on: "Xcode"), NoteMark(number: 2, start: 19, x: 2900, y: 400, width: 900, height: 300, on: nil)]
        let phrases = [NotePhrase(start: 0, end: 4, text: "Build fails.", marks: []), NotePhrase(start: 5, end: 10, text: "This line.", marks: [1]), NotePhrase(start: 19, end: 22, text: "This check.", marks: [2])]
        let note = Note(displayName: "Display", width: 5120, height: 2880, duration: 42, marks: marks, phrases: phrases)
        let text = try bundle.write(annotated: Data([1]), screenshot: Data([2]), note: note, session: "abcdefgh-123")
        let directories = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
        let directory = try XCTUnwrap(directories.first).standardizedFileURL
        let expected = """
        DrawMoar note · 0:42 · Display 5120x2880

        0:00 Build fails.
        ✎① 0:05 in Xcode, at 120,840 640x90
          This line.
        ✎② 0:19 at 2900,400 900x300
          This check.

        Image with marks: \(directory.path)/annotated.png
        Screenshot: \(directory.path)/screenshot.png
        Bundle: \(directory.path)
        """
        XCTAssertEqual(text, expected)
        XCTAssertEqual(try Set(FileManager.default.contentsOfDirectory(atPath: directory.path)), Set(["annotated.png", "screenshot.png", "summary.md", "note.json"]))
        let updated = Note(displayName: nil, width: 1, height: 1, duration: 1, marks: [], phrases: [NotePhrase(start: 0, end: 1, text: "Updated", marks: [])])
        let second = try bundle.write(annotated: Data([3]), screenshot: Data([4]), note: updated, session: "abcdefgh-123")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil).count, 1)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("annotated.png")), Data([3]))
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("summary.md"), encoding: .utf8), second)
        XCTAssertEqual(try JSONDecoder().decode(Note.self, from: Data(contentsOf: directory.appendingPathComponent("note.json"))), updated)
    }

    func testDictationDoesNotCreateBundle() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let note = Note(displayName: nil, width: 0, height: 0, duration: 2, marks: [], phrases: [NotePhrase(start: 0, end: 1, text: "Hello", marks: []), NotePhrase(start: 1, end: 2, text: "world", marks: [])])
        XCTAssertEqual(try NoteBundle(base: base).write(annotated: Data(), screenshot: Data(), note: note, session: "session"), "Hello world")
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.path))
    }

    func testRetention() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let manager = FileManager.default
        let now = Date()
        for days in [29, 31] {
            let directory = base.appendingPathComponent("\(days)")
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            try manager.setAttributes([.modificationDate: now.addingTimeInterval(Double(-days * 86400))], ofItemAtPath: directory.path)
        }
        try NoteBundle(base: base).removeExpired(now: now)
        XCTAssertEqual(try manager.contentsOfDirectory(atPath: base.path), ["29"])
    }
}
