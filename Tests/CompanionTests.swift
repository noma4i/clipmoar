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
        let messages: [Message] = [.hello(deviceId: "device"), .image(png: Data(bytes))]
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

    func testPairingHandshake() throws {
        let key = CompanionTLS.pairingKey(pin: "123456")
        try checkHandshake(keys: [("pair", key)], identity: "pair", key: key, accepted: true)
        try checkHandshake(keys: [("pair", key)], identity: "pair", key: CompanionTLS.pairingKey(pin: "000000"), accepted: false)
    }

    func testIdentitySelectsKey() throws {
        let keyA = CompanionTLS.pairingKey(pin: "123456")
        let keyB = CompanionTLS.pairingKey(pin: "654321")
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
