import Cocoa
import CryptoKit

protocol PasteboardReadable {
    var changeCount: Int { get }
    var frontmostBundleId: String? { get }
    func stringValue() -> String?
    func imageData() -> Data?
    func isEmpty() -> Bool
    func hasMarkerType() -> Bool
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

    func hasMarkerType() -> Bool {
        NSPasteboard.general.data(forType: ClipboardActionService.markerType) != nil
    }
}

enum ContentFingerprint {
    static func hash(text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }

    static func hash(data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}

final class ClipboardService {
    private let repository: ClipboardRepository
    private let settings: SettingsStore
    private let pasteboard: PasteboardReadable
    private let ruleEngine: ClipboardRuleEngine
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let monitorInterval: TimeInterval
    private var lastInsertedUUID: UUID?

    init(
        repository: ClipboardRepository = CoreDataClipboardRepository(),
        settings: SettingsStore = UserDefaultsSettingsStore(),
        pasteboard: PasteboardReadable = NSPasteboardGateway(),
        ruleEngine: ClipboardRuleEngine = ClipboardRuleEngine(),
        monitorInterval: TimeInterval = 0.5
    ) {
        self.repository = repository
        self.settings = settings
        self.pasteboard = pasteboard
        self.ruleEngine = ruleEngine
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

    func checkForChanges() {
        let newCount = pasteboard.changeCount
        guard newCount != lastChangeCount else { return }
        let gap = newCount - lastChangeCount
        lastChangeCount = newCount

        if pasteboard.hasMarkerType() { return }

        if pasteboard.isEmpty() {
            if let uuid = lastInsertedUUID {
                repository.removeItem(uuid: uuid)
                lastInsertedUUID = nil
            }
            return
        }

        let sourceAppBundleId = pasteboard.frontmostBundleId

        if let string = pasteboard.stringValue(), !string.isEmpty {
            let processed = ruleEngine.apply(to: string)
            let fingerprint = ContentFingerprint.hash(text: processed)

            if repository.isDuplicate(fingerprint: fingerprint) {
                if gap > 1, let uuid = lastInsertedUUID {
                    repository.removeItem(uuid: uuid)
                    lastInsertedUUID = nil
                }
                return
            }

            let uuid = repository.insertText(processed, sourceAppBundleId: sourceAppBundleId, fingerprint: fingerprint)
            lastInsertedUUID = uuid

        } else if settings.storeImages, let imageData = pasteboard.imageData() {
            let fingerprint = ContentFingerprint.hash(data: imageData)

            if repository.isDuplicate(fingerprint: fingerprint) {
                if gap > 1, let uuid = lastInsertedUUID {
                    repository.removeItem(uuid: uuid)
                    lastInsertedUUID = nil
                }
                return
            }

            let uuid = repository.insertImage(imageData, sourceAppBundleId: sourceAppBundleId, fingerprint: fingerprint)
            lastInsertedUUID = uuid
        }

        repository.trimHistory(maxSize: max(settings.maxHistorySize, 1))
    }
}
