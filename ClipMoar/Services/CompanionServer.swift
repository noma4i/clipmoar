import CompanionKit
import CryptoKit
import Foundation
import Network
import Observation
import Security

struct CompanionDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let key: Data
}

protocol CompanionDeviceStoring {
    func devices() throws -> [CompanionDevice]
    func save(_ device: CompanionDevice) throws
    func revoke(_ id: String) throws
}

struct KeychainCompanionDevices: CompanionDeviceStoring {
    private let service: String

    init(service: String = "com.noma4i.ClipMoar.companion") {
        self.service = service
    }

    func devices() throws -> [CompanionDevice] {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecReturnAttributes as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitAll]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw keychainError(status) }
        guard let items = result as? [[String: Any]] else { throw keychainError(errSecDecode) }
        return try items.map { item in
            guard let id = item[kSecAttrAccount as String] as? String,
                  let name = item[kSecAttrLabel as String] as? String else { throw keychainError(errSecDecode) }
            let dataQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                            kSecAttrService as String: service, kSecAttrAccount as String: id,
                                            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            var dataResult: CFTypeRef?
            let dataStatus = SecItemCopyMatching(dataQuery as CFDictionary, &dataResult)
            guard dataStatus == errSecSuccess else { throw keychainError(dataStatus) }
            guard let key = dataResult as? Data else { throw keychainError(errSecDecode) }
            return CompanionDevice(id: id, name: name, key: key)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func save(_ device: CompanionDevice) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: device.id]
        let values: [String: Any] = [kSecAttrLabel as String: device.name, kSecValueData as String: device.key]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            let addStatus = SecItemAdd(query.merging(values) { _, new in new } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw keychainError(addStatus) }
        } else if status != errSecSuccess {
            throw keychainError(status)
        }
    }

    func revoke(_ id: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: id]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(status) }
    }

    private func keychainError(_ status: OSStatus) -> Error {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}

final class PairingWindow {
    private(set) var invite: PairingInvite?
    private(set) var expiresAt: Date?
    private var failures = 0
    var isOpen: Bool {
        invite != nil && (expiresAt ?? .distantPast) > Date()
    }

    func open() throws {
        var secret = Data(count: 32)
        let status = secret.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        let name = Host.current().localizedName.flatMap { $0.isEmpty ? nil : $0 } ?? "Mac"
        invite = PairingInvite(macName: name, secret: secret)
        expiresAt = Date().addingTimeInterval(120)
        failures = 0
    }

    func close() {
        invite = nil
        expiresAt = nil
        failures = 0
    }

    func handshakeFailed() {
        guard isOpen else { return }
        failures += 1
        if failures >= 5 { close() }
    }
}

@MainActor protocol CompanionImageWriting {
    func writeImage(png: Data, marked: Bool) throws
}

extension ClipboardActionService: CompanionImageWriting {}

@MainActor protocol CompanionImageHistory: AnyObject {
    func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID
    func replaceImage(uuid: UUID, data: Data, fingerprint: String) -> Bool
    func moveToTop(uuid: UUID)
}

extension CoreDataClipboardRepository: CompanionImageHistory {}

@MainActor final class CompanionImageIngest {
    private let clipboard: CompanionImageWriting
    private let history: CompanionImageHistory
    private let prepare: (Data) -> Data
    private var sessions: [String: UUID] = [:]

    init(clipboard: CompanionImageWriting, history: CompanionImageHistory, prepare: @escaping (Data) -> Data) {
        self.clipboard = clipboard
        self.history = history
        self.prepare = prepare
    }

    func paste(png: Data, session: String) throws {
        try clipboard.writeImage(png: png, marked: true)
        let data = prepare(png)
        let fingerprint = ContentFingerprint.hash(data: png)
        if let uuid = sessions[session], history.replaceImage(uuid: uuid, data: data, fingerprint: fingerprint) {
            history.moveToTop(uuid: uuid)
        } else {
            sessions[session] = history.insertImage(data, sourceAppBundleId: "com.noma4i.DrawMoar", fingerprint: fingerprint)
        }
    }
}

@MainActor final class CompanionSession {
    private let devices: CompanionDeviceStoring
    private let pairing: PairingWindow
    private let capturer: ScreenCapturing
    private let images: CompanionImageIngest
    private var authenticated = false
    private(set) var closed = false

    init(devices: CompanionDeviceStoring, pairing: PairingWindow, capturer: ScreenCapturing, images: CompanionImageIngest) {
        self.devices = devices
        self.pairing = pairing
        self.capturer = capturer
        self.images = images
    }

    func receive(_ message: Message) async -> Message? {
        do {
            if !authenticated {
                switch message {
                case let .hello(id):
                    guard try devices.devices().contains(where: { $0.id == id }) else { return reject("Unknown device.") }
                    authenticated = true
                    return nil
                case let .pairRequest(id, name):
                    guard pairing.isOpen else { return reject("Pairing is closed.") }
                    guard !id.isEmpty, id != "pair", !name.isEmpty else { return reject("Invalid device.") }
                    var key = Data(count: 32)
                    let status = key.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
                    guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
                    try devices.save(CompanionDevice(id: id, name: name, key: key))
                    pairing.close()
                    closed = true
                    return .pairGranted(key: key)
                default: return reject("Send hello or pair request first.")
                }
            }
            switch message {
            case .listDisplays: return try await .displays(capturer.displays())
            case let .capture(id):
                let result = try await capturer.capture(displayId: id)
                return .screenshot(png: result.png, windows: result.windows)
            case let .paste(png, session):
                try images.paste(png: png, session: session)
                return .ok
            default: return reject("Unexpected message.")
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func reject(_ text: String) -> Message {
        closed = true
        return .error(text)
    }
}

final class CompanionConnections {
    private var cancellations: [UUID: () -> Void] = [:]

    func add(_ id: UUID, cancel: @escaping () -> Void) {
        cancellations[id] = cancel
    }

    func remove(_ id: UUID) {
        cancellations.removeValue(forKey: id)
    }

    func cancelAll(except retainedID: UUID? = nil) {
        let pending = cancellations.filter { $0.key != retainedID }.map(\.value)
        cancellations = cancellations.filter { $0.key == retainedID }
        pending.forEach { $0() }
    }
}

@Observable
final class CompanionServer {
    private(set) var invite: PairingInvite?
    private(set) var secondsRemaining = 0
    private(set) var devices: [CompanionDevice] = []
    private(set) var error: String?
    private let store: CompanionDeviceStoring
    private let capturer: ScreenCapturing
    private let images: CompanionImageIngest
    private let pairing = PairingWindow()
    private let connections: CompanionConnections
    private var listener: NWListener?
    private var timer: Timer?
    private var enabled = false

    var isRunning: Bool {
        enabled
    }

    init(capturer: ScreenCapturing, images: CompanionImageIngest, store: CompanionDeviceStoring, connections: CompanionConnections = CompanionConnections()) {
        self.capturer = capturer
        self.images = images
        self.store = store
        self.connections = connections
        do { devices = try store.devices() } catch { self.error = error.localizedDescription }
    }

    func start() {
        enabled = true
        refreshListener()
    }

    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        if value { start() } else { stop() }
    }

    func stop() {
        enabled = false
        pairing.close()
        updatePairingState()
        timer?.invalidate()
        timer = nil
        listener?.cancel()
        listener = nil
        connections.cancelAll()
    }

    func startPairing() {
        guard enabled else { return }
        do {
            try pairing.open()
            updatePairingState()
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
            refreshListener()
        } catch { self.error = error.localizedDescription }
    }

    func closePairing() {
        pairing.close()
        timer?.invalidate()
        timer = nil
        updatePairingState()
        refreshListener()
    }

    func revoke(_ id: String) {
        do {
            try store.revoke(id)
            refreshListener()
        } catch { self.error = error.localizedDescription }
    }

    private func tick() {
        if !pairing.isOpen { closePairing() } else { updatePairingState() }
    }

    private func updatePairingState() {
        invite = pairing.invite
        secondsRemaining = max(0, Int(ceil(pairing.expiresAt?.timeIntervalSinceNow ?? 0)))
    }

    private func refreshListener() {
        listener?.cancel()
        listener = nil
        connections.cancelAll()
        guard enabled else { return }
        do {
            devices = try store.devices()
            var keys = devices.map { (identity: $0.id, key: SymmetricKey(data: $0.key)) }
            if pairing.isOpen, let invite = pairing.invite {
                keys.append((identity: "pair", key: CompanionTLS.pairingKey(secret: invite.secret)))
            }
            guard !keys.isEmpty else { return }
            let listener = try NWListener(using: CompanionTLS.serverParameters(keys: keys))
            listener.service = NWListener.Service(name: Host.current().localizedName ?? "Mac", type: bonjourServiceType)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case let .failed(error) = state {
                    self?.error = error.localizedDescription
                    NSLog("[ClipMoar] companion listener: %@", error.localizedDescription)
                }
            }
            self.listener = listener
            listener.start(queue: .main)
        } catch {
            self.error = error.localizedDescription
            NSLog("[ClipMoar] companion listener: %@", error.localizedDescription)
        }
    }

    @MainActor private func accept(_ connection: NWConnection) {
        guard invite == nil || pairing.isOpen else { connection.cancel(); return }
        let id = UUID()
        let session = CompanionSession(devices: store, pairing: pairing, capturer: capturer, images: images)
        let peer = CompanionPeer(connection: connection, session: session)
        connections.add(id) { peer.cancel() }
        peer.onEnd = { [weak self] ready in
            guard let self else { return }
            self.connections.remove(id)
            if !ready, self.pairing.isOpen {
                self.pairing.handshakeFailed()
                if !self.pairing.isOpen { self.closePairing() }
            }
        }
        peer.onPaired = { [weak self] in self?.closePairing() }
        peer.onPairingGranted = { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
            self?.connections.cancelAll(except: id)
            self?.updatePairingState()
        }
        peer.start()
    }
}

private final class CompanionPeer {
    private let connection: NWConnection
    private let session: CompanionSession
    private var decoder = FrameDecoder()
    private var ready = false
    private var ended = false
    var onEnd: ((Bool) -> Void)?
    var onPaired: (() -> Void)?
    var onPairingGranted: (() -> Void)?

    init(connection: NWConnection, session: CompanionSession) {
        self.connection = connection
        self.session = session
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.ready = true
                self.receive()
            case .failed, .cancelled: self.finish()
            default: break
            }
        }
        connection.start(queue: .main)
    }

    func cancel() {
        if !ended {
            ended = true
            onEnd?(true)
        }
        connection.cancel()
    }

    private func finish() {
        guard !ended else { return }
        ended = true
        onEnd?(ready)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { return }
            do {
                let messages = try data.map { try self.decoder.append($0).map(Message.init(frame:)) } ?? []
                Task { @MainActor in
                    for message in messages {
                        guard let reply = await self.session.receive(message) else { continue }
                        if case .pairGranted = reply { self.onPairingGranted?() }
                        do {
                            try await self.send(reply)
                        } catch {
                            if case .pairGranted = reply { self.onPaired?() }
                            self.cancel()
                            return
                        }
                        if case .pairGranted = reply {
                            self.onPaired?()
                            return
                        }
                        if self.session.closed { self.cancel(); return }
                    }
                    if complete || error != nil { self.cancel() } else { self.receive() }
                }
            } catch { self.cancel() }
        }
    }

    private func send(_ message: Message) async throws {
        let data = try message.encode()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }
}
