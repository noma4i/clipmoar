import Cocoa
import CoreData

protocol PasteboardReadable {
    var changeCount: Int { get }
    var frontmostBundleId: String? { get }
    func stringValue() -> String?
    func imageData() -> Data?
    func isEmpty() -> Bool
}

final class NSPasteboardGateway: PasteboardReadable {
    var changeCount: Int { NSPasteboard.general.changeCount }

    var frontmostBundleId: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func stringValue() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func imageData() -> Data? {
        NSPasteboard.general.data(forType: .tiff) ?? NSPasteboard.general.data(forType: .png)
    }

    func isEmpty() -> Bool {
        guard let items = NSPasteboard.general.pasteboardItems, !items.isEmpty else { return true }
        return stringValue() == nil && imageData() == nil
    }
}

final class ClipboardService {
    private let repository: ClipboardRepository
    private let settings: SettingsStore
    private let pasteboard: PasteboardReadable
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let monitorInterval: TimeInterval
    private var skipNextChange = false

    init(
        repository: ClipboardRepository = CoreDataClipboardRepository(),
        settings: SettingsStore = UserDefaultsSettingsStore(),
        pasteboard: PasteboardReadable = NSPasteboardGateway(),
        monitorInterval: TimeInterval = 0.5
    ) {
        self.repository = repository
        self.settings = settings
        self.pasteboard = pasteboard
        self.monitorInterval = monitorInterval
    }

    func startMonitoring() {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: monitorInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func skipNext() {
        skipNextChange = true
    }

    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if skipNextChange {
            skipNextChange = false
            return
        }

        if pasteboard.isEmpty() {
            repository.removeLastUnpinnedItem()
            return
        }

        let sourceAppBundleId = pasteboard.frontmostBundleId

        if let string = pasteboard.stringValue(), !string.isEmpty {
            if let existing = repository.duplicateTextItem(string) {
                repository.updateCreatedAt(for: existing, date: Date())
            } else {
                repository.insertText(string, sourceAppBundleId: sourceAppBundleId)
            }
        } else if settings.storeImages, let imageData = pasteboard.imageData() {
            repository.insertImage(imageData, sourceAppBundleId: sourceAppBundleId)
        }

        repository.trimHistory(maxSize: max(settings.maxHistorySize, 1))
    }
}
