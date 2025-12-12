import XCTest
@testable import ClipMoar

final class MockPasteboard: PasteboardReadable {
    var _changeCount = 0
    var _string: String?
    var _imageData: Data?
    var _hasMarker = false
    var _hasIgnoredSystemType = false

    var changeCount: Int { _changeCount }
    var frontmostBundleId: String? { "com.test.app" }

    func stringValue() -> String? { _string }
    func imageData() -> Data? { _imageData }
    func isEmpty() -> Bool { _string == nil && _imageData == nil }
    func hasMarkerType() -> Bool { _hasMarker }
    func hasIgnoredSystemType() -> Bool { _hasIgnoredSystemType }

    func simulateCopy(text: String) {
        _changeCount += 1
        _string = text
        _imageData = nil
        _hasMarker = false
        _hasIgnoredSystemType = false
    }

    func simulateTransientCopy(text: String) {
        _changeCount += 1
        _string = text
        _imageData = nil
        _hasMarker = false
        _hasIgnoredSystemType = true
    }

    func simulateCopy(imageData: Data) {
        _changeCount += 1
        _string = nil
        _imageData = imageData
        _hasMarker = false
        _hasIgnoredSystemType = false
    }

    func simulateClear() {
        _changeCount += 1
        _string = nil
        _imageData = nil
        _hasMarker = false
        _hasIgnoredSystemType = false
    }

    func simulateMarkerWrite(text: String) {
        _changeCount += 1
        _string = text
        _imageData = nil
        _hasMarker = true
        _hasIgnoredSystemType = false
    }

    func simulateExternalDeleteAndSetNext(text: String) {
        _changeCount += 2
        _string = text
        _imageData = nil
        _hasMarker = false
        _hasIgnoredSystemType = false
    }
}

final class MockRepository: ClipboardRepository {
    var items: [(uuid: UUID, content: String?, contentType: String, fingerprint: String)] = []

    func fetchItems(filter: String) -> [ClipboardItem] { [] }

    func isDuplicate(fingerprint: String) -> Bool {
        fingerprints.contains(fingerprint)
    }

    // Simplified for testing - track inserts/removes
    var insertedTexts: [(text: String, fingerprint: String, uuid: UUID)] = []
    var insertedImages: [(dataCount: Int, fingerprint: String, uuid: UUID)] = []
    var removedUUIDs: [UUID] = []
    var fingerprints: Set<String> = []

    @discardableResult
    func insertText(_ text: String, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        let id = UUID()
        insertedTexts.append((text, fingerprint, id))
        fingerprints.insert(fingerprint)
        return id
    }

    @discardableResult
    func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        let id = UUID()
        insertedImages.append((data.count, fingerprint, id))
        fingerprints.insert(fingerprint)
        return id
    }

    func removeItem(uuid: UUID) {
        removedUUIDs.append(uuid)
        insertedTexts.removeAll { $0.uuid == uuid }
        insertedImages.removeAll { $0.uuid == uuid }
    }

    func trimHistory(maxSize: Int) {}

    func hasDuplicate(_ fingerprint: String) -> Bool {
        fingerprints.contains(fingerprint)
    }
}

final class MockSettings: SettingsStore {
    var showInDock = true
    var showInMenuBar = true
    var maxHistorySize = 500
    var hotkeyKeyCode = 0
    var hotkeyModifiers: UInt32 = 0
    var storeImages = true
    func registerDefaults() {}
}

final class ClipboardServiceTests: XCTestCase {

    func testNewTextIsInserted() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        pasteboard.simulateCopy(text: "Hello World")
        // Manually trigger since timer won't fire in tests
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 1)
        XCTAssertEqual(repo.insertedTexts.first?.text, "Hello World")
    }

    func testDuplicateTextIsNotInserted() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        pasteboard.simulateCopy(text: "Hello")
        triggerCheck(service)
        XCTAssertEqual(repo.insertedTexts.count, 1)

        pasteboard.simulateCopy(text: "Hello")
        triggerCheck(service)
        XCTAssertEqual(repo.insertedTexts.count, 1, "Duplicate should not be inserted")
    }

    func testMarkerTypeIsSkipped() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        pasteboard.simulateMarkerWrite(text: "From ClipMoar")
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 0, "Marker writes should be skipped")
    }

    func testEmptyClipboardRemovesLastItem() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        pasteboard.simulateCopy(text: "To be deleted")
        triggerCheck(service)
        XCTAssertEqual(repo.insertedTexts.count, 1)

        pasteboard.simulateClear()
        triggerCheck(service)

        XCTAssertEqual(repo.removedUUIDs.count, 1, "Empty clipboard should remove last inserted item")
    }

    func testGapDuplicateRemovesPreviousItem() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        // Insert "A" then "B"
        pasteboard.simulateCopy(text: "A")
        triggerCheck(service)
        pasteboard.simulateCopy(text: "B")
        triggerCheck(service)
        XCTAssertEqual(repo.insertedTexts.count, 2)

        // External delete: clear + set "A" (gap = 2)
        pasteboard.simulateExternalDeleteAndSetNext(text: "A")
        triggerCheck(service)

        XCTAssertEqual(repo.removedUUIDs.count, 1, "Gap > 1 with duplicate should remove previous item")
    }

    func testNewImageIsInserted() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        pasteboard.simulateCopy(imageData: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        triggerCheck(service)

        XCTAssertEqual(repo.insertedImages.count, 1)
    }

    func testDuplicateImageIsNotInserted() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        pasteboard.simulateCopy(imageData: imageData)
        triggerCheck(service)
        XCTAssertEqual(repo.insertedImages.count, 1)

        pasteboard.simulateCopy(imageData: imageData)
        triggerCheck(service)
        XCTAssertEqual(repo.insertedImages.count, 1, "Duplicate image should not be inserted")
    }

    func testTransientTypeIsSkipped() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        pasteboard.simulateTransientCopy(text: "Transient text")
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 0, "Transient writes should be skipped")
    }

    func testTransientDoesNotAffectLastInsertedUUID() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = ClipboardService(
            repository: repo,
            settings: MockSettings(),
            pasteboard: pasteboard
        )
        service.startMonitoring()

        pasteboard.simulateCopy(text: "Real text")
        triggerCheck(service)
        XCTAssertEqual(repo.insertedTexts.count, 1)

        pasteboard.simulateTransientCopy(text: "Transient")
        triggerCheck(service)

        pasteboard.simulateClear()
        triggerCheck(service)
        XCTAssertEqual(repo.removedUUIDs.count, 1, "Should remove real item, not be confused by transient")
    }

    private func triggerCheck(_ service: ClipboardService) {
        service.checkForChanges()
    }
}
