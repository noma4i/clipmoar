import CompanionKit
import Foundation

struct NotePreview: Equatable {
    let note: Note
    let annotated: URL?
    let bundle: URL
}

enum NotePreviewLoader {
    static let sourceBundleId = "com.noma4i.DrawMoar"

    static func bundleURL(text: String?, sourceAppBundleId: String?) -> URL? {
        guard sourceAppBundleId == sourceBundleId, let text else { return nil }
        let prefix = "Bundle: "
        guard let line = text.components(separatedBy: .newlines).last(where: { $0.hasPrefix(prefix) }) else { return nil }
        let path = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        guard path.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func load(text: String?, sourceAppBundleId: String?) -> NotePreview? {
        guard let bundle = bundleURL(text: text, sourceAppBundleId: sourceAppBundleId),
              let data = try? Data(contentsOf: bundle.appendingPathComponent("note.json")),
              let note = try? JSONDecoder().decode(Note.self, from: data) else { return nil }
        let annotated = bundle.appendingPathComponent("annotated.png")
        return NotePreview(note: note, annotated: FileManager.default.fileExists(atPath: annotated.path) ? annotated : nil, bundle: bundle)
    }
}

struct NoteAnimationSchedule {
    static let phraseDuration = 1.2
    static let pause = 2.0

    private let order: [Int]

    init?(starts: [Double], reduceMotion: Bool) {
        guard !reduceMotion, !starts.isEmpty else { return nil }
        order = starts.indices.sorted { starts[$0] < starts[$1] }
    }

    var cycle: Double {
        Double(order.count) * Self.phraseDuration + Self.pause
    }

    func activeIndex(at time: Double) -> Int? {
        guard time >= 0 else { return nil }
        let position = time.truncatingRemainder(dividingBy: cycle)
        let slot = Int(position / Self.phraseDuration)
        return slot < order.count ? order[slot] : nil
    }
}
