import Cocoa

struct ClipboardItemMeta {
    let text: String
    let needsPreview: Bool
}

final class FloatingPanelDataSource {
    private let repository: ClipboardRepository
    private let actionService: ClipboardActionServicing
    private(set) var items: [ClipboardItem] = []

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    init(repository: ClipboardRepository, actionService: ClipboardActionServicing) {
        self.repository = repository
        self.actionService = actionService
    }

    func fetch(filter: String = "") {
        items = repository.fetchItems(filter: filter)
    }

    func item(at index: Int) -> ClipboardItem? {
        guard index >= 0, index < items.count else { return nil }
        return items[index]
    }

    func meta(for item: ClipboardItem, availableTextWidth: CGFloat, font: NSFont) -> ClipboardItemMeta {
        var parts: [String] = []

        if let content = item.content {
            let words = content.split(separator: " ").count
            parts.append("\(words) words; \(content.count) chars")
        }

        if let date = item.createdAt {
            parts.append("Copied Today \(Self.timeFormatter.string(from: date))")
        }

        let needsPreview = isPreviewNeeded(for: item, availableWidth: availableTextWidth, font: font)
        return ClipboardItemMeta(text: parts.joined(separator: "  "), needsPreview: needsPreview)
    }

    func imageMetadata(for item: ClipboardItem) -> String {
        guard item.isImage, let data = item.imageData else { return "" }

        var parts: [String] = []
        if let img = NSImage(data: data) {
            let w = Int(img.representations.first?.pixelsWide ?? Int(img.size.width))
            let h = Int(img.representations.first?.pixelsHigh ?? Int(img.size.height))
            parts.append("\(w)x\(h)")
        }
        let kb = Double(data.count) / 1024.0
        parts.append(kb > 1024 ? String(format: "%.1f MB", kb / 1024.0) : String(format: "%.0f KB", kb))
        return parts.joined(separator: " - ")
    }

    func paste(at index: Int) {
        guard let item = item(at: index) else { return }
        actionService.pasteFromPasteboard(item: item)
    }

    func remove(at index: Int) {
        guard let item = item(at: index),
              !item.isPinned,
              let uuid = item.uuid else { return }
        repository.removeItem(uuid: uuid)
        items.remove(at: index)
    }

    func openInExternalPreview(_ item: ClipboardItem) {
        guard item.isImage, let data = item.imageData else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let filename = "ClipMoar_\(item.uuid?.uuidString ?? "temp").png"
        let url = tempDir.appendingPathComponent(filename)

        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }

        try? png.write(to: url)
        NSWorkspace.shared.open(url)
    }

    private func isPreviewNeeded(for item: ClipboardItem, availableWidth: CGFloat, font: NSFont) -> Bool {
        if item.isImage, item.imageData != nil { return true }

        guard let text = item.content else { return false }
        if text.contains("\n") { return true }

        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        return textWidth > availableWidth
    }
}
