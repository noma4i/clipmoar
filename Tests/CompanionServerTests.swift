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
        XCTAssertEqual(result, .image(png: capture.png))
        XCTAssertEqual(capture.calls, 1)
        XCTAssertNil(capture.displayID)
    }

    func testPasteWritesOriginalPNG() async {
        let clipboard = FakeClipboard()
        let session = makeSession(clipboard: clipboard)
        _ = await session.receive(.hello(deviceId: "device"))
        let png = Data([1, 2, 3])
        let result = await session.receive(.paste(png: png))
        XCTAssertEqual(result, .ok)
        XCTAssertEqual(clipboard.png, png)
    }

    func testPairingRequiresOpenWindowAndPersistsKey() async throws {
        let store = FakeDevices()
        let window = PairingWindow()
        let closed = CompanionSession(devices: store, pairing: window, capturer: FakeCapture(), clipboard: FakeClipboard())
        let rejected = await closed.receive(.pairRequest(deviceId: "new", deviceName: "iPad"))
        guard case .error = rejected else { return XCTFail("Expected an error") }
        XCTAssertTrue(try store.devices().isEmpty)
        try window.open()
        let open = CompanionSession(devices: store, pairing: window, capturer: FakeCapture(), clipboard: FakeClipboard())
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
        let session = CompanionSession(devices: store, pairing: window, capturer: FakeCapture(), clipboard: FakeClipboard())
        let result = await session.receive(.pairRequest(deviceId: "new", deviceName: "iPad"))
        guard case .error = result else { return XCTFail("Expected an error") }
        XCTAssertTrue(try store.devices().isEmpty)
    }

    func testClosingPairingAndRevokingCancelConnections() {
        let connections = CompanionConnections()
        let server = CompanionServer(capturer: FakeCapture(), clipboard: FakeClipboard(), store: FakeDevices(), connections: connections)
        var cancellations = 0
        connections.add(UUID()) { cancellations += 1 }
        server.closePairing()
        XCTAssertEqual(cancellations, 1)
        connections.add(UUID()) { cancellations += 1 }
        server.revoke("device")
        XCTAssertEqual(cancellations, 2)
    }

    private func makeSession(capture: FakeCapture = FakeCapture(), clipboard: FakeClipboard = FakeClipboard()) -> CompanionSession {
        let store = FakeDevices()
        try! store.save(CompanionDevice(id: "device", name: "iPad", key: Data(repeating: 1, count: 32)))
        return CompanionSession(devices: store, pairing: PairingWindow(), capturer: capture, clipboard: clipboard)
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
    var calls = 0
    var displayID: UInt32?
    func displays() async throws -> [DisplayInfo] {
        []
    }

    func capture(displayId: UInt32?) async throws -> Data {
        calls += 1
        displayID = displayId
        return png
    }
}

private final class FakeClipboard: CompanionImageWriting {
    var png: Data?
    func writeImage(png: Data) throws {
        self.png = png
    }
}
