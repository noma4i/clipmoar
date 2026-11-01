@testable import ClipMoar
import CompanionKit
import Foundation
import XCTest

@MainActor final class CompanionServerTests: XCTestCase {
    func testCaptureBeforeHelloIsRejected() async {
        let capture = FakeCapture()
        let session = makeSession(capture: capture)
        let result = await session.receive(.capture(displayId: nil))
        guard case .error = result else { return XCTFail("Expected an error") }
        XCTAssertTrue(session.closed)
        XCTAssertEqual(capture.calls, 0)
    }

    func testHelloThenCaptureUsesCursorDisplay() async {
        let capture = FakeCapture()
        let session = makeSession(capture: capture)
        _ = await session.receive(.hello(deviceId: "device"))
        let result = await session.receive(.capture(displayId: nil))
        XCTAssertEqual(result, .screenshot(png: capture.png, windows: capture.windows))
        XCTAssertEqual(capture.calls, 1)
        XCTAssertNil(capture.displayID)
    }

    func testPasteReplacesSessionAndMovesItToTop() async {
        let clipboard = FakeClipboard()
        let history = FakeHistory()
        let session = makeSession(clipboard: clipboard, history: history)
        _ = await session.receive(.hello(deviceId: "device"))
        for byte: UInt8 in 1 ... 3 {
            let result = await session.receive(.paste(png: Data([byte]), session: "s1"))
            XCTAssertEqual(result, .ok)
        }
        XCTAssertEqual(history.items.map(\.data), [Data([3, 9])])
        XCTAssertEqual(clipboard.png, Data([3]))
        XCTAssertTrue(clipboard.marked)
        let result = await session.receive(.paste(png: Data([4]), session: "s2"))
        XCTAssertEqual(result, .ok)
        XCTAssertEqual(history.items.map(\.data), [Data([4, 9]), Data([3, 9])])
        XCTAssertEqual(history.items.map(\.source), ["com.noma4i.DrawMoar", "com.noma4i.DrawMoar"])
        XCTAssertEqual(clipboard.png, Data([4]))
        XCTAssertTrue(clipboard.marked)
        let updated = await session.receive(.paste(png: Data([5]), session: "s1"))
        XCTAssertEqual(updated, .ok)
        XCTAssertEqual(history.items.map(\.data), [Data([5, 9]), Data([4, 9])])
    }

    func testReplacementPublishesUUIDAfterMovingItem() throws {
        let history = FakeHistory()
        let images = makeImages(history: history)
        try images.paste(png: Data([1]), session: "s1")
        let uuid = try XCTUnwrap(history.items.first?.id)
        var received: UUID?
        var receivedOnMain = false
        let observer = NotificationCenter.default.addObserver(forName: .companionImageReplaced, object: nil, queue: nil) { notification in
            received = notification.object as? UUID
            receivedOnMain = Thread.isMainThread
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        try images.paste(png: Data([2]), session: "s1")
        XCTAssertEqual(received, uuid)
        XCTAssertTrue(receivedOnMain)
        XCTAssertEqual(history.items.first?.data, Data([2, 9]))
    }

    func testReplacementImageAndThumbnailFollowNewData() {
        let context = CoreDataStack.shared.viewContext
        let item = ClipboardItem(context: context)
        defer { context.delete(item) }
        let uuid = UUID()
        let first = Data([1])
        let second = Data([2])
        item.uuid = uuid
        item.contentType = ClipboardItemType.image.rawValue
        item.imageData = first
        item.fingerprint = "first"
        let firstKey = ClipTableCellView.thumbnailKey(item: item, size: 22)
        XCTAssertEqual(firstKey, ClipTableCellView.thumbnailKey(item: item, size: 22))
        item.imageData = second
        item.fingerprint = "second"
        XCTAssertNotEqual(firstKey, ClipTableCellView.thumbnailKey(item: item, size: 22))
        item.fingerprint = ""
        XCTAssertEqual(ClipTableCellView.thumbnailKey(item: item, size: 22), "\(uuid.uuidString)_1_22.0")
        XCTAssertEqual(replacementImage(selectedUUID: uuid, eventUUID: uuid, item: item), second)
        XCTAssertNil(replacementImage(selectedUUID: uuid, eventUUID: UUID(), item: item))
    }

    func testPanelKeepsSelectionAndRefreshesSelectedImage() {
        let context = CoreDataStack.shared.viewContext
        let selected = ClipboardItem(context: context)
        let other = ClipboardItem(context: context)
        defer {
            context.delete(selected)
            context.delete(other)
        }
        selected.uuid = UUID()
        selected.contentType = ClipboardItemType.image.rawValue
        selected.imageData = Data([1])
        other.uuid = UUID()
        other.contentType = ClipboardItemType.image.rawValue
        other.imageData = Data([2])
        let repository = MockRepository()
        repository.fetchedItems = [other, selected]
        let settings = MockSettings()
        let configuration = settings.panelConfiguration()
        let panel = FloatingPanelStateController(repository: repository, actionService: ClipboardActionService(), settings: settings)
        panel.reload(configuration: configuration)
        panel.selectRow(1, configuration: configuration, forcePreview: true)
        selected.imageData = Data([3])
        repository.fetchedItems = [selected, other]
        panel.refreshAfterImageReplacement(configuration: configuration)
        XCTAssertEqual(panel.selectedItem?.uuid, selected.uuid)
        XCTAssertEqual(panel.state.selectedRow, 0)
        guard case let .image(updated) = panel.state.preview.content else { return XCTFail("Expected image preview") }
        XCTAssertEqual(updated, Data([3]))
        other.imageData = Data([4])
        repository.fetchedItems = [other, selected]
        panel.refreshAfterImageReplacement(configuration: configuration)
        XCTAssertEqual(panel.selectedItem?.uuid, selected.uuid)
        guard case let .image(unchanged) = panel.state.preview.content else { return XCTFail("Expected image preview") }
        XCTAssertEqual(unchanged, Data([3]))
    }

    func testDetachedPasteUsesMainThreadForClipboardAndHistory() async {
        let clipboard = FakeClipboard()
        let history = FakeHistory()
        let session = makeSession(clipboard: clipboard, history: history)
        let results = await Task.detached {
            _ = await session.receive(.hello(deviceId: "device"))
            let first = await session.receive(.paste(png: Data([1]), session: "s1"))
            let second = await session.receive(.paste(png: Data([2]), session: "s1"))
            return [first, second]
        }.value
        XCTAssertEqual(results, [.ok, .ok])
        XCTAssertEqual(clipboard.mainThreadCalls, [true, true])
        XCTAssertEqual(history.mainThreadCalls, [true, true, true])
    }

    func testPairingRequiresOpenWindowAndPersistsKey() async throws {
        let store = FakeDevices()
        let window = PairingWindow()
        let closed = CompanionSession(devices: store, pairing: window, capturer: FakeCapture(), images: makeImages())
        let rejected = await closed.receive(.pairRequest(deviceId: "new", deviceName: "iPad"))
        guard case .error = rejected else { return XCTFail("Expected an error") }
        XCTAssertTrue(try store.devices().isEmpty)
        try window.open()
        let open = CompanionSession(devices: store, pairing: window, capturer: FakeCapture(), images: makeImages())
        let granted = await open.receive(.pairRequest(deviceId: "new", deviceName: "iPad"))
        guard case let .pairGranted(key) = granted else { return XCTFail("Expected a key") }
        XCTAssertEqual(key.count, 32)
        XCTAssertEqual(try store.devices(), [CompanionDevice(id: "new", name: "iPad", key: key)])
        XCTAssertFalse(window.isOpen)
    }

    func testFiveHandshakeFailuresClosePairing() async throws {
        let window = PairingWindow()
        try window.open()
        for _ in 0 ..< 5 {
            window.handshakeFailed()
        }
        let store = FakeDevices()
        let session = CompanionSession(devices: store, pairing: window, capturer: FakeCapture(), images: makeImages())
        let result = await session.receive(.pairRequest(deviceId: "new", deviceName: "iPad"))
        guard case .error = result else { return XCTFail("Expected an error") }
        XCTAssertTrue(try store.devices().isEmpty)
    }

    func testPairingWindowPublishesAndRemovesInvite() throws {
        let server = CompanionServer(capturer: FakeCapture(), images: makeImages(), store: FakeDevices())
        server.start()
        server.startPairing()
        XCTAssertEqual(try XCTUnwrap(server.invite).secret.count, 32)
        server.closePairing()
        XCTAssertNil(server.invite)
        server.stop()
    }

    func testClosingPairingAndRevokingCancelConnections() {
        let connections = CompanionConnections()
        let server = CompanionServer(capturer: FakeCapture(), images: makeImages(), store: FakeDevices(), connections: connections)
        var cancellations = 0
        connections.add(UUID()) { cancellations += 1 }
        server.closePairing()
        XCTAssertEqual(cancellations, 1)
        connections.add(UUID()) { cancellations += 1 }
        server.revoke("device")
        XCTAssertEqual(cancellations, 2)
    }

    private func makeImages(clipboard: FakeClipboard? = nil, history: FakeHistory? = nil) -> CompanionImageIngest {
        CompanionImageIngest(clipboard: clipboard ?? FakeClipboard(), history: history ?? FakeHistory()) { $0 + Data([9]) }
    }

    private func makeSession(capture: FakeCapture = FakeCapture(), clipboard: FakeClipboard? = nil, history: FakeHistory? = nil) -> CompanionSession {
        let store = FakeDevices()
        try! store.save(CompanionDevice(id: "device", name: "iPad", key: Data(repeating: 1, count: 32)))
        return CompanionSession(devices: store, pairing: PairingWindow(), capturer: capture, images: makeImages(clipboard: clipboard, history: history))
    }
}

private final class FakeDevices: CompanionDeviceStoring {
    private var stored: [CompanionDevice] = []
    func devices() throws -> [CompanionDevice] {
        stored
    }

    func save(_ device: CompanionDevice) throws {
        stored.removeAll { $0.id == device.id }
        stored.append(device)
    }

    func revoke(_ id: String) throws {
        stored.removeAll { $0.id == id }
    }
}

private final class FakeCapture: ScreenCapturing {
    let png = Data([5, 6, 7])
    let windows = [WindowFrame(x: 1, y: 2, width: 3, height: 4, app: "App", title: "Window")]
    var calls = 0
    var displayID: UInt32?
    func displays() async throws -> [DisplayInfo] {
        []
    }

    func capture(displayId: UInt32?) async throws -> (png: Data, windows: [WindowFrame]) {
        calls += 1
        displayID = displayId
        return (png, windows)
    }
}

private final class FakeClipboard: CompanionImageWriting {
    var png: Data?
    var marked = false
    var mainThreadCalls: [Bool] = []
    func writeImage(png: Data, marked: Bool) throws {
        mainThreadCalls.append(Thread.isMainThread)
        self.png = png
        self.marked = marked
    }
}

private final class FakeHistory: CompanionImageHistory {
    struct Item {
        let id: UUID
        var data: Data
        let source: String?
        var fingerprint: String
    }

    var items: [Item] = []
    var mainThreadCalls: [Bool] = []
    func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        mainThreadCalls.append(Thread.isMainThread)
        let id = UUID()
        items.insert(Item(id: id, data: data, source: sourceAppBundleId, fingerprint: fingerprint), at: 0)
        return id
    }

    func replaceImage(uuid: UUID, data: Data, fingerprint: String) -> Bool {
        mainThreadCalls.append(Thread.isMainThread)
        guard let index = items.firstIndex(where: { $0.id == uuid }) else { return false }
        items[index].data = data
        items[index].fingerprint = fingerprint
        return true
    }

    func moveToTop(uuid: UUID) {
        mainThreadCalls.append(Thread.isMainThread)
        guard let index = items.firstIndex(where: { $0.id == uuid }) else { return }
        items.insert(items.remove(at: index), at: 0)
    }
}
