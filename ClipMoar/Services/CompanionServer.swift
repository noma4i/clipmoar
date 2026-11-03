import CompanionKit
import CryptoKit
import Darwin
import Foundation
import Network
import Observation
import Security
import SystemConfiguration

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
    func writeNote(text: String, png: Data?) throws
}

extension ClipboardActionService: CompanionImageWriting {}

@MainActor protocol CompanionImageHistory: AnyObject {
    func insertImage(_ data: Data, sourceAppBundleId: String?, fingerprint: String) -> UUID
    func replaceImage(uuid: UUID, data: Data, fingerprint: String) -> Bool
    func insertText(_ text: String, sourceAppBundleId: String?, fingerprint: String, appliedRule: String?) -> UUID
    func replaceText(uuid: UUID, text: String, fingerprint: String) -> Bool
    func moveToTop(uuid: UUID)
}

extension CoreDataClipboardRepository: CompanionImageHistory {}

extension Notification.Name {
    static let companionImageReplaced = Notification.Name("companionImageReplaced")
}

@MainActor final class CompanionImageIngest {
    private let clipboard: CompanionImageWriting
    private let history: CompanionImageHistory
    private let prepare: (Data) -> Data
    private var sessions: [String: UUID] = [:]
    private var textSessions = Set<String>()
    nonisolated let bundles: NoteBundle

    init(clipboard: CompanionImageWriting, history: CompanionImageHistory, bundles: NoteBundle = NoteBundle(), prepare: @escaping (Data) -> Data) {
        self.clipboard = clipboard
        self.history = history
        self.prepare = prepare
        self.bundles = bundles
    }

    func paste(png: Data, session: String) throws {
        try clipboard.writeImage(png: png, marked: true)
        guard !textSessions.contains(session) else { return }
        let data = prepare(png)
        let fingerprint = ContentFingerprint.hash(data: png)
        if let uuid = sessions[session], history.replaceImage(uuid: uuid, data: data, fingerprint: fingerprint) {
            history.moveToTop(uuid: uuid)
            NotificationCenter.default.post(name: .companionImageReplaced, object: uuid)
        } else {
            sessions[session] = history.insertImage(data, sourceAppBundleId: "com.noma4i.DrawMoar", fingerprint: fingerprint)
        }
    }

    func note(annotated: Data, screenshot: Data, note: Note, session: String) throws {
        let text = try bundles.write(annotated: annotated, screenshot: screenshot, note: note, session: session)
        try clipboard.writeNote(text: text, png: annotated.isEmpty ? nil : annotated)
        let fingerprint = ContentFingerprint.hash(text: text)
        if let uuid = sessions[session], history.replaceText(uuid: uuid, text: text, fingerprint: fingerprint) {
            history.moveToTop(uuid: uuid)
        } else {
            sessions[session] = history.insertText(text, sourceAppBundleId: "com.noma4i.DrawMoar", fingerprint: fingerprint, appliedRule: nil)
        }
        textSessions.insert(session)
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
            case let .note(annotated, screenshot, note, session):
                try images.note(annotated: annotated, screenshot: screenshot, note: note, session: session)
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
    private(set) var listeningPort: UInt16?
    private(set) var hosts: [String] = []
    private let store: CompanionDeviceStoring
    private let capturer: ScreenCapturing
    private let images: CompanionImageIngest
    private let pairing = PairingWindow()
    private let connections: CompanionConnections
    private let preferredPort: UInt16
    private let addressSource: () -> ([String], String?)
    private var listener: NWListener?
    private var timer: Timer?
    private var enabled = false

    var isRunning: Bool {
        enabled
    }

    init(capturer: ScreenCapturing, images: CompanionImageIngest, store: CompanionDeviceStoring, connections: CompanionConnections = CompanionConnections(), preferredPort: UInt16 = CompanionTLS.port, addressSource: @escaping () -> ([String], String?) = companionAddresses) {
        self.capturer = capturer
        self.images = images
        self.store = store
        self.connections = connections
        self.preferredPort = preferredPort
        self.addressSource = addressSource
        do { devices = try store.devices() } catch { self.error = error.localizedDescription }
    }

    func start() {
        do { try images.bundles.removeExpired() } catch { self.error = error.localizedDescription }
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
        listeningPort = nil
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
        if let source = pairing.invite, let listeningPort {
            invite = PairingInvite(macName: source.macName, secret: source.secret, port: listeningPort, hosts: hosts)
        } else {
            invite = nil
        }
        secondsRemaining = max(0, Int(ceil(pairing.expiresAt?.timeIntervalSinceNow ?? 0)))
    }

    private func refreshListener() {
        listener?.cancel()
        listener = nil
        listeningPort = nil
        updatePairingState()
        connections.cancelAll()
        guard enabled else { return }
        do {
            devices = try store.devices()
            var keys = devices.map { (identity: $0.id, key: SymmetricKey(data: $0.key)) }
            if pairing.isOpen, let invite = pairing.invite {
                keys.append((identity: "pair", key: CompanionTLS.pairingKey(secret: invite.secret)))
            }
            guard !keys.isEmpty else { return }
            let (addresses, localName) = addressSource()
            let localHosts = localName.map { [$0 + ".local"] } ?? []
            hosts = Array(addresses.prefix(8 - localHosts.count)) + localHosts
            try startListener(keys: keys)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func startListener(keys: [(identity: String, key: SymmetricKey)]) throws {
        let parameters = CompanionTLS.serverParameters(keys: keys)
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: preferredPort)!)
        } catch {
            self.error = "Port \(preferredPort) is unavailable."
            return
        }
        listener.service = NWListener.Service(name: Host.current().localizedName ?? "Mac", type: bonjourServiceType)
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener, self.listener === listener else { return }
            switch state {
            case .ready:
                self.error = nil
                self.listeningPort = listener.port?.rawValue
                self.updatePairingState()
            case .failed:
                listener.cancel()
                self.listener = nil
                self.listeningPort = nil
                self.error = "Port \(self.preferredPort) is unavailable."
                self.updatePairingState()
            default: break
            }
        }
        self.listener = listener
        listener.start(queue: .main)
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

private func companionAddresses() -> ([String], String?) {
    var first: UnsafeMutablePointer<ifaddrs>?
    var addresses: [String] = []
    if getifaddrs(&first) == 0 {
        defer { freeifaddrs(first) }
        var current = first
        while let interface = current {
            let item = interface.pointee
            if item.ifa_flags & UInt32(IFF_UP) != 0, let address = item.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) {
                let ipv4 = UnsafeRawPointer(address).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
                let value = UInt32(bigEndian: ipv4.s_addr)
                if value & 0xFFC0_0000 == 0x6440_0000 {
                    var ip = ipv4
                    var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    if inet_ntop(AF_INET, &ip, &buffer, socklen_t(buffer.count)) != nil {
                        addresses.append(String(cString: buffer))
                    }
                }
            }
            current = item.ifa_next
        }
    }
    return (addresses, SCDynamicStoreCopyLocalHostName(nil) as String?)
}
