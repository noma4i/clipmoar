@testable import ClipMoar
import CompanionKit
import Foundation
import XCTest

final class CompanionServerTests: XCTestCase {
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

    private func makeImages(clipboard: FakeClipboard = FakeClipboard(), history: FakeHistory = FakeHistory()) -> CompanionImageIngest {
        CompanionImageIngest(clipboard: clipboard, history: history) { $0 + Data([9]) }
    }

    private func makeSession(capture: FakeCapture = FakeCapture(), clipboard: FakeClipboard = FakeClipboard(), history: FakeHistory = FakeHistory()) -> CompanionSession {
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
    func writeImage(png: Data, marked: Bool) throws {
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
    func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID {
        let id = UUID()
        items.insert(Item(id: id, data: data, source: sourceAppBundleId, fingerprint: fingerprint), at: 0)
        return id
    }

    func replaceImage(uuid: UUID, data: Data, fingerprint: String) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == uuid }) else { return false }
        items[index].data = data
        items[index].fingerprint = fingerprint
        return true
    }

    func moveToTop(uuid: UUID) {
        guard let index = items.firstIndex(where: { $0.id == uuid }) else { return }
        items.insert(items.remove(at: index), at: 0)
    }
}
