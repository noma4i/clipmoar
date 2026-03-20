@testable import ClipMoar
import XCTest

final class MockPasteboard: PasteboardReadable {
    var _changeCount = 0
    var _string: String?
    var _imageData: Data?
    var _fileURLs: [URL]?
    var _hasMarker = false
    var _hasIgnoredSystemType = false
    var frontmostBundleIdValue = "com.test.app"

    var changeCount: Int {
        _changeCount
    }

    var frontmostBundleId: String? {
        frontmostBundleIdValue
    }

    func stringValue() -> String? {
        _string
    }

    func imageData() -> Data? {
        _imageData
    }

    func fileURLs() -> [URL]? {
        _fileURLs
    }

    func isEmpty() -> Bool {
        _string == nil && _imageData == nil && _fileURLs == nil
    }

    func hasMarkerType() -> Bool {
        _hasMarker
    }

    func hasIgnoredSystemType() -> Bool {
        _hasIgnoredSystemType
    }

    func simulateCopy(text: String) {
        _changeCount += 1
        _string = text
        _imageData = nil
        _fileURLs = nil
        _hasMarker = false
        _hasIgnoredSystemType = false
    }

    func simulateTransientCopy(text: String) {
        _changeCount += 1
        _string = text
        _imageData = nil
        _fileURLs = nil
        _hasMarker = false
        _hasIgnoredSystemType = true
    }

    func simulateCopy(imageData: Data) {
        _changeCount += 1
        _string = nil
        _imageData = imageData
        _fileURLs = nil
        _hasMarker = false
        _hasIgnoredSystemType = false
    }

    func simulateCopy(fileURLs: [URL]) {
        _changeCount += 1
        _string = nil
        _imageData = nil
        _fileURLs = fileURLs
        _hasMarker = false
        _hasIgnoredSystemType = false
    }

    func simulateClear() {
        _changeCount += 1
        _string = nil
        _imageData = nil
        _fileURLs = nil
        _hasMarker = false
        _hasIgnoredSystemType = false
    }

    func simulateMarkerWrite(text: String) {
        _changeCount += 1
        _string = text
        _imageData = nil
        _fileURLs = nil
        _hasMarker = true
        _hasIgnoredSystemType = false
    }

    func simulateExternalDeleteAndSetNext(text: String) {
        _changeCount += 2
        _string = text
        _imageData = nil
        _fileURLs = nil
        _hasMarker = false
        _hasIgnoredSystemType = false
    }
}

final class MockRepository: ClipboardRepository {
    var items: [(uuid: UUID, content: String?, contentType: String, fingerprint: String)] = []

    func fetchItems(filter _: String) -> [ClipboardItem] {
        []
    }

    func isDuplicate(fingerprint: String) -> Bool {
        fingerprints.contains(fingerprint)
    }

    // Simplified for testing - track inserts/removes
    var insertedTexts: [(text: String, fingerprint: String, uuid: UUID)] = []
    var insertedImages: [(dataCount: Int, fingerprint: String, uuid: UUID)] = []
    var insertedFiles: [(paths: String, fingerprint: String, uuid: UUID)] = []
    var removedUUIDs: [UUID] = []
    var fingerprints: Set<String> = []
    var trimHistoryCalls = 0
    var removeOlderThanCalls: [(hours: Int, contentType: String?)] = []

    @discardableResult
    func insertText(_ text: String, sourceAppBundleId _: String?, fingerprint: String, appliedRule _: String? = nil) -> UUID {
        let id = UUID()
        insertedTexts.append((text, fingerprint, id))
        fingerprints.insert(fingerprint)
        return id
    }

    @discardableResult
    func insertImage(_ data: Data, sourceAppBundleId _: String?, fingerprint: String) -> UUID {
        let id = UUID()
        insertedImages.append((data.count, fingerprint, id))
        fingerprints.insert(fingerprint)
        return id
    }

    @discardableResult
    func insertFile(_ paths: String, sourceAppBundleId _: String?, fingerprint: String) -> UUID {
        let id = UUID()
        insertedFiles.append((paths, fingerprint, id))
        fingerprints.insert(fingerprint)
        return id
    }

    func removeItem(uuid: UUID) {
        removedUUIDs.append(uuid)
        insertedTexts.removeAll { $0.uuid == uuid }
        insertedImages.removeAll { $0.uuid == uuid }
    }

    func trimHistory(maxSize _: Int) {
        trimHistoryCalls += 1
    }

    func removeOlderThan(hours: Int, contentType: String?) {
        removeOlderThanCalls.append((hours, contentType))
    }

    func storageStats() -> StorageStats {
        StorageStats()
    }

    func clearAll(contentType _: String?) {}

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
    var storeText = true
    var storeImages = true
    var textRetentionHours: Int = 0
    var imageRetentionHours: Int = 0
    var panelPositionX: Double = 0.5
    var panelPositionY: Double = 0.65
    var panelScreenMode: Int = 0
    var largeTypeEnabled: Bool = true
    var panelFontSize: Int = 15
    var panelTheme: Int = 0
    var panelAccentColor: Int = 0
    var panelFontName: String = ""
    var panelAccentHex: String = "2672B5"
    var panelCornerRadius: Int = 0
    var panelPaddingH: Int = 12
    var panelPaddingV: Int = 4
    var panelMargin: Int = 0
    var panelFontWeight: Int = 0
    var panelIconSize: Int = 22
    var panelVisibleRows: Int = 9
    var panelTextColorHex: String = "E6E6E6"
    var previewFontName: String = ""
    var previewFontSize: Int = 11
    var previewPadding: Int = 10
    var previewTextColorHex: String = "D9D9D9"
    var previewBgColorHex: String = "1A1A1A"
    var searchFontName: String = ""
    var searchFontSize: Int = 16
    var searchTextColorHex: String = "E6E6E6"
    var searchPlaceholderColorHex: String = "666666"
    var metaFontSize: Int = 10
    var largeTypeFontSize: Int = 48
    var compressImages: Bool = false
    var imageMaxWidth: Int = 0
    var imageMaxHeight: Int = 0
    var imageQuality: Int = 80
    var imageRemoveBackground: Bool = false
    var imageConvertToPNG: Bool = false
    var imageConvertToJPEG: Bool = false
    var imageStripMetadata: Bool = false
    var imageAutoEnhance: Bool = false
    var imageGrayscale: Bool = false
    var imageAutoRotate: Bool = false
    var imageTrimWhitespace: Bool = false
    var imageSharpen: Bool = false
    var imageReduceNoise: Bool = false
    var ignoredAppBundleIds: [String] = []
    func registerDefaults() {}
}

struct SilentClipboardLogger: ClipboardLogger {
    func log(_: StaticString, _: CVarArg...) {}
}

final class ClipboardServiceTests: XCTestCase {
    func testNewTextIsInserted() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = makeService(repository: repo, pasteboard: pasteboard)
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
        let service = makeService(repository: repo, pasteboard: pasteboard)
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
        let service = makeService(repository: repo, pasteboard: pasteboard)
        service.startMonitoring()

        pasteboard.simulateMarkerWrite(text: "From ClipMoar")
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 0, "Marker writes should be skipped")
    }

    func testEmptyClipboardRemovesLastItem() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = makeService(repository: repo, pasteboard: pasteboard)
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
        let service = makeService(repository: repo, pasteboard: pasteboard)
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
        let service = makeService(repository: repo, pasteboard: pasteboard)
        service.startMonitoring()

        pasteboard.simulateCopy(imageData: Data([0xFF, 0xD8, 0xFF, 0xE0]))
        triggerCheck(service)

        XCTAssertEqual(repo.insertedImages.count, 1)
    }

    func testDuplicateImageIsNotInserted() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = makeService(repository: repo, pasteboard: pasteboard)
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
        let service = makeService(repository: repo, pasteboard: pasteboard)
        service.startMonitoring()

        pasteboard.simulateTransientCopy(text: "Transient text")
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 0, "Transient writes should be skipped")
    }

    func testTransientDoesNotAffectLastInsertedUUID() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = makeService(repository: repo, pasteboard: pasteboard)
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

    func testFileCopyIsInserted() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = makeService(repository: repo, pasteboard: pasteboard)
        service.startMonitoring()

        pasteboard.simulateCopy(fileURLs: [
            URL(fileURLWithPath: "/tmp/one.txt"),
            URL(fileURLWithPath: "/tmp/two.txt"),
        ])
        triggerCheck(service)

        XCTAssertEqual(repo.insertedFiles.count, 1)
        XCTAssertEqual(repo.insertedFiles.first?.paths, "/tmp/one.txt\n/tmp/two.txt")
    }

    func testMaintenanceRunsOnConfiguredInterval() {
        let pasteboard = MockPasteboard()
        let repo = MockRepository()
        let service = makeService(repository: repo, pasteboard: pasteboard, maintenanceInterval: 2)
        service.startMonitoring()

        pasteboard.simulateCopy(text: "First")
        triggerCheck(service)
        XCTAssertEqual(repo.trimHistoryCalls, 0)
        XCTAssertTrue(repo.removeOlderThanCalls.isEmpty)

        pasteboard.simulateCopy(text: "Second")
        triggerCheck(service)

        XCTAssertEqual(repo.trimHistoryCalls, 1)
        XCTAssertEqual(repo.removeOlderThanCalls.count, 3)
    }

    func testXcodeClipboardIsIgnoredOnlyUnderTestHarness() {
        let pasteboard = MockPasteboard()
        pasteboard.frontmostBundleIdValue = "com.apple.dt.Xcode"
        let repo = MockRepository()
        let service = makeService(
            repository: repo,
            pasteboard: pasteboard,
            isRunningUnderTestHarness: { true }
        )
        service.startMonitoring()

        pasteboard.simulateCopy(text: "Copied from Xcode")
        triggerCheck(service)

        XCTAssertTrue(repo.insertedTexts.isEmpty)
    }

    func testXcodeClipboardStillWorksOutsideTestHarness() {
        let pasteboard = MockPasteboard()
        pasteboard.frontmostBundleIdValue = "com.apple.dt.Xcode"
        let repo = MockRepository()
        let service = makeService(
            repository: repo,
            pasteboard: pasteboard,
            isRunningUnderTestHarness: { false }
        )
        service.startMonitoring()

        pasteboard.simulateCopy(text: "Copied from Xcode")
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 1)
        XCTAssertEqual(repo.insertedTexts.first?.text, "Copied from Xcode")
    }

    private func triggerCheck(_ service: ClipboardService) {
        service.checkForChanges()
    }

    func testIgnoredAppIsSkipped() {
        let pasteboard = MockPasteboard()
        pasteboard.frontmostBundleIdValue = "com.ignored.app"
        let repo = MockRepository()
        let settings = MockSettings()
        settings.ignoredAppBundleIds = ["com.ignored.app"]
        let service = makeService(repository: repo, pasteboard: pasteboard, settings: settings)
        service.startMonitoring()

        pasteboard.simulateCopy(text: "Should be ignored")
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 0)
    }

    func testNonIgnoredAppIsNotSkipped() {
        let pasteboard = MockPasteboard()
        pasteboard.frontmostBundleIdValue = "com.normal.app"
        let repo = MockRepository()
        let settings = MockSettings()
        settings.ignoredAppBundleIds = ["com.ignored.app"]
        let service = makeService(repository: repo, pasteboard: pasteboard, settings: settings)
        service.startMonitoring()

        pasteboard.simulateCopy(text: "Should be saved")
        triggerCheck(service)

        XCTAssertEqual(repo.insertedTexts.count, 1)
    }

    private func makeService(
        repository: MockRepository,
        pasteboard: MockPasteboard,
        maintenanceInterval: Int = 20,
        settings: MockSettings = MockSettings(),
        isRunningUnderTestHarness: @escaping () -> Bool = { false }
    ) -> ClipboardService {
        ClipboardService(
            repository: repository,
            settings: settings,
            pasteboard: pasteboard,
            maintenanceInterval: maintenanceInterval,
            logger: SilentClipboardLogger(),
            isRunningUnderTestHarness: isRunningUnderTestHarness
        )
    }
}
