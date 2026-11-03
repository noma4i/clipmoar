import CompanionKit
import CryptoKit
import Foundation
import Network
import Security
import XCTest

final class CompanionTests: XCTestCase {
    func testNoteFramesRoundTrip() throws {
        let note = Note(displayName: "Display", width: 100, height: 200, duration: 12, marks: [], phrases: [NotePhrase(start: 0, end: 1, text: "Hello", marks: [])])
        for images in [(Data([1, 2]), Data([3, 4])), (Data(), Data())] {
            let message = Message.note(annotated: images.0, screenshot: images.1, note: note, session: "session")
            var decoder = FrameDecoder()
            let frames = try decoder.append(message.encode())
            XCTAssertEqual(try frames.map { try Message(frame: $0) }, [message])
        }
    }

    func testFragmentedFrames() throws {
        var bytes = [UInt8](repeating: 0, count: 300 * 1024)
        XCTAssertEqual(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes), errSecSuccess)
        let windows = [
            WindowFrame(x: 1, y: 2, width: 300, height: 400, app: "App", title: "Caf\u{E9}", children: [
                WindowFrame(x: 10, y: 20, width: 200, height: 250, app: "App", title: "AXGroup", children: [
                    WindowFrame(x: 20, y: 30, width: 120, height: 130, app: "App", title: "AXList"),
                ]),
            ]),
            WindowFrame(x: 5, y: 6, width: 700, height: 800, app: "Other", title: "Window"),
        ]
        let messages: [Message] = [.hello(deviceId: "device"), .screenshot(png: Data(bytes), windows: windows), .paste(png: Data(bytes), session: "session")]
        let wire = try messages.reduce(into: Data()) { result, message in
            try result.append(message.encode())
        }
        var decoder = FrameDecoder()
        var received = [Message]()
        for byte in wire {
            try received.append(contentsOf: decoder.append(Data([byte])).map { try Message(frame: $0) })
        }
        XCTAssertEqual(received, messages)
    }

    func testInvalidScreenshotPayloads() {
        for payload in [Data(), Data([0, 0, 0]), Data([0, 0, 0, 2, 91]), Data([0, 0, 0, 2, 91, 93]), Data([0, 0, 0, 1, 123, 1]), Data([0, 16, 0, 1, 1])] {
            XCTAssertThrowsError(try Message(frame: Frame(type: 1, payload: payload)))
        }
    }

    func testOversizedFrame() {
        var decoder = FrameDecoder()
        XCTAssertThrowsError(try decoder.append(Data([4, 0, 0, 1])))
    }

    func testInvalidPastePayloads() {
        for payload in [Data(), Data([0]), Data([0, 2, 65]), Data([0, 1, 65]), Data([0, 0, 1]), Data([0, 129, 1])] {
            XCTAssertThrowsError(try Message(frame: Frame(type: 2, payload: payload)))
        }
        XCTAssertThrowsError(try Message.paste(png: Data([1]), session: "").encode())
        XCTAssertThrowsError(try Message.paste(png: Data([1]), session: String(repeating: "a", count: 129)).encode())
    }

    func testPairingInviteURL() throws {
        let invite = PairingInvite(macName: "Mac \u{1F4BB} Caf\u{E9}", secret: Data(0 ..< 32), port: 47823, hosts: ["100.64.1.2", "mac.local"])
        XCTAssertEqual(PairingInvite(url: invite.url), invite)
        let old = PairingInvite(macName: "Mac", secret: Data(0 ..< 32))
        let parsedOld = try XCTUnwrap(PairingInvite(url: old.url))
        XCTAssertNil(parsedOld.port)
        XCTAssertEqual(parsedOld.hosts, [])
        var components = try XCTUnwrap(URLComponents(url: invite.url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "key" })?.value?.count, 43)
        components.scheme = "https"
        XCTAssertNil(try PairingInvite(url: XCTUnwrap(components.url)))
        components.scheme = "drawmoar"
        components.host = "other"
        XCTAssertNil(try PairingInvite(url: XCTUnwrap(components.url)))
        components.host = "pair"
        components.queryItems = [URLQueryItem(name: "v", value: "2"), URLQueryItem(name: "name", value: "Mac"), URLQueryItem(name: "key", value: String(repeating: "A", count: 43))]
        XCTAssertNil(try PairingInvite(url: XCTUnwrap(components.url)))
        components.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "name", value: "Mac"), URLQueryItem(name: "key", value: Data(repeating: 0, count: 31).base64EncodedString().replacingOccurrences(of: "=", with: ""))]
        XCTAssertNil(try PairingInvite(url: XCTUnwrap(components.url)))
        components.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "key", value: String(repeating: "A", count: 43))]
        XCTAssertNil(try PairingInvite(url: XCTUnwrap(components.url)))
    }

    func testConnectionWaitsForDelayedListener() async throws {
        let reservation = try NWListener(using: .tcp, on: .any)
        let reserved = expectation(description: "port reserved")
        let released = expectation(description: "port released")
        reservation.stateUpdateHandler = { state in
            if case .ready = state { reserved.fulfill() }
            if case .cancelled = state { released.fulfill() }
        }
        reservation.newConnectionHandler = { $0.cancel() }
        reservation.start(queue: .global())
        await fulfillment(of: [reserved], timeout: 5)
        let port = try XCTUnwrap(reservation.port)
        reservation.cancel()
        await fulfillment(of: [released], timeout: 5)

        let connection = CompanionConnection(NWConnection(host: .ipv4(.loopback), port: port, using: .tcp))
        defer { connection.connection.cancel() }
        let clock = ContinuousClock()
        let start = clock.now
        let readiness = Task { try await connection.ready(timeout: .seconds(3)) }
        try await Task.sleep(for: .milliseconds(300))
        let listener = try NWListener(using: .tcp, on: port)
        defer { listener.cancel() }
        listener.newConnectionHandler = { _ in }
        listener.start(queue: .global())
        do {
            try await readiness.value
        } catch CompanionConnectionError.timedOut {
            XCTAssertNotNil(connection.lastWaitingError)
            XCTAssertGreaterThanOrEqual(start.duration(to: clock.now), .milliseconds(2800))
        }
    }

    func testUnreachableConnectionFailsWithinTimeout() async throws {
        let listener = try NWListener(using: .tcp, on: .any)
        let listening = expectation(description: "listener ready")
        listener.stateUpdateHandler = { state in if case .ready = state { listening.fulfill() } }
        listener.newConnectionHandler = { $0.cancel() }
        listener.start(queue: .global())
        await fulfillment(of: [listening], timeout: 5)
        let port = try XCTUnwrap(listener.port)
        listener.cancel()
        let connection = CompanionConnection(NWConnection(host: .ipv4(.loopback), port: port, using: .tcp))
        let clock = ContinuousClock()
        let start = clock.now
        do {
            try await connection.ready(timeout: .seconds(2))
            XCTFail("Expected connection failure")
        } catch {}
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(3))
        connection.connection.cancel()
    }

    func testPairingHandshake() throws {
        let invite = PairingInvite(macName: "Mac", secret: Data(repeating: 1, count: 32))
        let key = CompanionTLS.pairingKey(secret: invite.secret)
        try checkHandshake(keys: [("pair", key)], identity: "pair", key: key, accepted: true)
        try checkHandshake(keys: [("pair", key)], identity: "pair", key: CompanionTLS.pairingKey(secret: Data(repeating: 2, count: 32)), accepted: false)
    }

    func testIdentitySelectsKey() throws {
        let keyA = CompanionTLS.pairingKey(secret: Data(repeating: 1, count: 32))
        let keyB = CompanionTLS.pairingKey(secret: Data(repeating: 2, count: 32))
        let keys = [("devA", keyA), ("devB", keyB)]
        try checkHandshake(keys: keys, identity: "devB", key: keyB, accepted: true)
        try checkHandshake(keys: keys, identity: "devB", key: keyA, accepted: false)
    }

    private func checkHandshake(keys: [(identity: String, key: SymmetricKey)], identity: String, key: SymmetricKey, accepted: Bool) throws {
        let listener = try NWListener(using: CompanionTLS.serverParameters(keys: keys), on: .any)
        let listening = expectation(description: "listener ready")
        let received = expectation(description: "hello received")
        received.isInverted = !accepted
        let queue = DispatchQueue(label: "CompanionTests")
        var server: CompanionConnection?
        var receiveTask: Task<Void, Never>?
        listener.stateUpdateHandler = { state in
            if case .ready = state { listening.fulfill() }
        }
        listener.newConnectionHandler = { connection in
            let wrapper = CompanionConnection(connection)
            server = wrapper
            receiveTask = Task {
                do {
                    for try await message in wrapper.messages {
                        if message == .hello(deviceId: "device") { received.fulfill() }
                    }
                } catch {}
            }
        }
        listener.start(queue: queue)
        wait(for: [listening], timeout: 5)
        let port = try XCTUnwrap(listener.port)
        let client = CompanionConnection(NWConnection(host: .ipv4(.loopback), port: port, using: CompanionTLS.clientParameters(identity: identity, key: key)))
        let sendTask = Task { try? await client.send(.hello(deviceId: "device")) }
        wait(for: [received], timeout: 5)
        sendTask.cancel()
        receiveTask?.cancel()
        client.connection.cancel()
        server?.connection.cancel()
        listener.cancel()
    }
}
