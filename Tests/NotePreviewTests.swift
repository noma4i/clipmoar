@testable import ClipMoar
import CompanionKit
import Foundation
import XCTest

final class NotePreviewTests: XCTestCase {
    private func makeBundle() throws -> (URL, Note) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let note = Note(displayName: nil, width: 10, height: 10, duration: 3, marks: [NoteMark(number: 1, start: 1, x: 0, y: 0, width: 1, height: 1, on: nil)], phrases: [NotePhrase(start: 0, end: 1, text: "One", marks: []), NotePhrase(start: 1, end: 2, text: "Two", marks: [1])])
        try JSONEncoder().encode(note).write(to: directory.appendingPathComponent("note.json"))
        try Data([1]).write(to: directory.appendingPathComponent("annotated.png"))
        return (directory, note)
    }

    func testLoaderReadsBundleOnlyForDrawMoar() throws {
        let (directory, _) = try makeBundle()
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = "DrawMoar note · 0:03\n\nBundle: \(directory.path)"
        let preview = try XCTUnwrap(NotePreviewLoader.load(text: text, sourceAppBundleId: "com.noma4i.DrawMoar"))
        XCTAssertEqual(preview.note.phrases.count, 2)
        XCTAssertEqual(preview.annotated, directory.appendingPathComponent("annotated.png"))
        XCTAssertNil(NotePreviewLoader.load(text: text, sourceAppBundleId: "com.apple.Notes"))
        XCTAssertNil(NotePreviewLoader.load(text: "Bundle: /nonexistent/\(UUID().uuidString)", sourceAppBundleId: "com.noma4i.DrawMoar"))
    }

    func testScheduleActivatesPhrasesInTimeOrderAndLoops() throws {
        let schedule = try XCTUnwrap(NoteAnimationSchedule(starts: [0.5, 10.5, 30], reduceMotion: false))
        XCTAssertEqual(schedule.activeIndex(at: 0), 0)
        XCTAssertEqual(schedule.activeIndex(at: 1.3), 1)
        XCTAssertEqual(schedule.activeIndex(at: 2.5), 2)
        XCTAssertNil(schedule.activeIndex(at: 4.0))
        XCTAssertEqual(schedule.activeIndex(at: 3 * 1.2 + 2), 0)
        XCTAssertNil(NoteAnimationSchedule(starts: [0.5, 10.5, 30], reduceMotion: true))
    }
}
