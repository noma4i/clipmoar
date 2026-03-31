import Cocoa

/// Derived metadata for the selected clipboard item.
struct ClipboardItemMeta {
    let text: String
    let needsPreview: Bool
}

/// Preview state is rendered directly by FloatingClipboardViewController.
struct FloatingPanelPreviewState {
    enum Content {
        case none
        case text(String)
        case image(Data)
    }

    var isVisible = false
    var content: Content = .none
    var infoText = ""
    var ruleText: String?
}

/// View state is the single source of truth for panel content and selection.
struct FloatingPanelViewState {
    var items: [ClipboardItem] = []
    var filter = ""
    var selectedRow = -1
    var metaText = ""
    var preview = FloatingPanelPreviewState()
}

final class FloatingPanelStateController {
    private let repository: ClipboardRepository
    private let actionService: ClipboardActionServicing
    private let settings: SettingsStore
    var onStatEvent: ((StatEventKind) -> Void)?

    private(set) var state = FloatingPanelViewState()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init(repository: ClipboardRepository, actionService: ClipboardActionServicing, settings: SettingsStore = UserDefaultsSettingsStore()) {
        self.repository = repository
        self.settings = settings
        self.actionService = actionService
    }

    var items: [ClipboardItem] {
        state.items
    }

    var selectedItem: ClipboardItem? {
        item(at: state.selectedRow)
    }

    func reload(configuration: PanelConfiguration) {
        state.filter = ""
        state.items = repository.fetchItems(filter: "")
        if state.items.isEmpty {
            clearSelection()
            return
        }

        selectRow(0, configuration: configuration, forcePreview: true)
    }

    func updateFilter(_ filter: String, configuration: PanelConfiguration) {
        state.filter = filter
        state.items = repository.fetchItems(filter: filter)
        if !filter.isEmpty { onStatEvent?(.search) }
        if state.items.isEmpty {
            clearSelection()
            return
        }

        selectRow(0, configuration: configuration, forcePreview: false)
    }

    func selectRow(_ row: Int, configuration: PanelConfiguration, forcePreview: Bool) {
        guard let item = item(at: row) else {
            clearSelection()
            return
        }

        state.selectedRow = row
        let meta = meta(for: item, configuration: configuration)
        state.metaText = meta.text
        updatePreview(for: item, showPreview: forcePreview || meta.needsPreview)
    }

    func showPreviewForSelection() {
        guard let item = selectedItem else { return }
        updatePreview(for: item, showPreview: true)
    }

    func hidePreview() {
        state.preview = FloatingPanelPreviewState()
    }

    func pasteSelected(previousApp: NSRunningApplication? = nil) {
        paste(at: state.selectedRow, previousApp: previousApp)
    }

    func paste(at index: Int, previousApp: NSRunningApplication? = nil) {
        guard let item = item(at: index) else { return }
        if settings.moveToTopOnUse, let uuid = item.uuid {
            repository.moveToTop(uuid: uuid)
        }
        if settings.autoPasteOnReturn {
            actionService.pasteFromPasteboard(item: item, previousApp: previousApp)
        } else {
            actionService.writeToPasteboard(item: item)
        }
        onStatEvent?(.paste)
    }

    @discardableResult
    func removeSelected(configuration: PanelConfiguration) -> Int? {
        let row = state.selectedRow
        guard let item = item(at: row),
              !item.isPinned,
              let uuid = item.uuid else { return normalizedSelection() }

        repository.removeItem(uuid: uuid)
        state.items.remove(at: row)

        guard !state.items.isEmpty else {
            clearSelection()
            return nil
        }

        let newRow = min(row, state.items.count - 1)
        selectRow(newRow, configuration: configuration, forcePreview: state.preview.isVisible)
        return newRow
    }

    func openExternalPreviewForSelection() {
        guard let item = selectedItem, item.isImage, let data = item.imageData else { return }

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

    func item(at index: Int) -> ClipboardItem? {
        guard index >= 0, index < state.items.count else { return nil }
        return state.items[index]
    }

    private func normalizedSelection() -> Int? {
        guard !state.items.isEmpty else { return nil }
        state.selectedRow = min(max(state.selectedRow, 0), state.items.count - 1)
        return state.selectedRow
    }

    private func clearSelection() {
        state.selectedRow = -1
        state.metaText = ""
        hidePreview()
    }

    private func updatePreview(for item: ClipboardItem, showPreview: Bool) {
        guard showPreview else {
            hidePreview()
            return
        }

        var preview = FloatingPanelPreviewState()
        preview.isVisible = true
        preview.infoText = previewInfo(for: item)
        preview.ruleText = item.appliedRule?.isEmpty == false ? item.appliedRule : nil

        if item.isImage, let data = item.imageData {
            preview.content = .image(data)
        } else {
            preview.content = .text(item.content ?? "")
        }

        state.preview = preview
    }

    private func previewInfo(for item: ClipboardItem) -> String {
        guard item.isImage, let data = item.imageData else { return "" }

        var parts: [String] = []
        if let dims = ClipboardItem.imageDimensions(from: data) {
            parts.append("\(dims.width)x\(dims.height)")
        }

        let kilobytes = Double(data.count) / 1024.0
        parts.append(kilobytes > 1024
            ? String(format: "%.1f MB", kilobytes / 1024.0)
            : String(format: "%.0f KB", kilobytes))
        return parts.joined(separator: " - ")
    }

    private func meta(for item: ClipboardItem, configuration: PanelConfiguration) -> ClipboardItemMeta {
        var parts: [String] = []

        if let content = item.content {
            let words = content.split(separator: " ").count
            parts.append("\(words) words; \(content.count) chars")
        }

        if let date = item.createdAt {
            parts.append("Copied Today \(Self.timeFormatter.string(from: date))")
        }

        let needsPreview = isPreviewNeeded(for: item, configuration: configuration)
        return ClipboardItemMeta(text: parts.joined(separator: "  "), needsPreview: needsPreview)
    }

    private func isPreviewNeeded(for item: ClipboardItem, configuration: PanelConfiguration) -> Bool {
        if item.isImage, item.imageData != nil { return true }

        guard let text = item.content else { return false }
        if text.contains("\n") { return true }

        let font = font(for: configuration.typography)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return width > configuration.layout.availableTextWidth
    }

    private func font(for typography: PanelTypographyConfiguration) -> NSFont {
        if let font = NSFont(name: typography.fontName, size: typography.fontSize) {
            return font
        }
        return .systemFont(ofSize: typography.fontSize, weight: typography.fontWeight)
    }
}
