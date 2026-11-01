import CompanionKit
import CryptoKit
import Foundation
import Network
import Security
import XCTest

final class CompanionTests: XCTestCase {
    func testFragmentedFrames() throws {
        var bytes = [UInt8](repeating: 0, count: 300 * 1024)
        XCTAssertEqual(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes), errSecSuccess)
        let messages: [Message] = [.hello(deviceId: "device"), .image(png: Data(bytes)), .paste(png: Data(bytes), session: "session")]
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
        let invite = PairingInvite(macName: "Mac \u{1F4BB} Caf\u{E9}", secret: Data(0 ..< 32))
        XCTAssertEqual(PairingInvite(url: invite.url), invite)
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
