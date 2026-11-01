import CryptoKit
import Foundation
import Network
import Security

public struct PairingInvite: Equatable {
    public let macName: String
    public let secret: Data
    public let port: UInt16?
    public let hosts: [String]

    public init(macName: String, secret: Data, port: UInt16? = nil, hosts: [String] = []) {
        precondition(!macName.isEmpty && secret.count == 32)
        self.macName = macName
        precondition(port != 0 && hosts.count <= 8 && hosts.allSatisfy { !$0.isEmpty && $0.count <= 253 })
        self.secret = secret
        self.port = port
        self.hosts = hosts
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "drawmoar"
        components.host = "pair"
        let key = secret.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        components.queryItems = [URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "name", value: macName), URLQueryItem(name: "key", value: key)]
        if let port { components.queryItems?.append(URLQueryItem(name: "port", value: String(port))) }
        components.queryItems?.append(contentsOf: hosts.map { URLQueryItem(name: "host", value: $0) })
        return components.url!
    }

    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "drawmoar", components.host == "pair", components.path.isEmpty,
              let items = components.queryItems,
              items.filter({ $0.name == "v" }).count == 1, items.first(where: { $0.name == "v" })?.value == "1",
              items.filter({ $0.name == "name" }).count == 1, let name = items.first(where: { $0.name == "name" })?.value, !name.isEmpty,
              items.filter({ $0.name == "key" }).count == 1, let key = items.first(where: { $0.name == "key" })?.value,
              key.count == 43, key.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_").contains($0) }),
              let secret = Data(base64Encoded: key.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "="), secret.count == 32 else { return nil }
        let ports = items.filter { $0.name == "port" }
        let hostItems = items.filter { $0.name == "host" }
        guard ports.count <= 1, hostItems.count <= 8 else { return nil }
        var parsedPort: UInt16?
        if let item = ports.first {
            guard let value = item.value, !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }), let number = UInt16(value), number > 0 else { return nil }
            parsedPort = number
        }
        let parsedHosts = hostItems.compactMap(\.value)
        guard parsedHosts.count == hostItems.count, parsedHosts.allSatisfy({ !$0.isEmpty && $0.count <= 253 }) else { return nil }
        macName = name
        self.secret = secret
        port = parsedPort
        hosts = parsedHosts
    }
}

public enum CompanionTLS {
    public static let port: UInt16 = 47823

    public static func pairingKey(secret: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: secret), salt: Data("clipmoar-pair-v1".utf8), outputByteCount: 32)
    }

    public static func clientParameters(identity: String, key: SymmetricKey) -> NWParameters {
        parameters(keys: [(identity, key)])
    }

    public static func serverParameters(keys: [(identity: String, key: SymmetricKey)]) -> NWParameters {
        parameters(keys: keys)
    }

    private static func parameters(keys: [(identity: String, key: SymmetricKey)]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let options = tls.securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(options, .TLSv12)
        sec_protocol_options_add_tls_ciphersuite(options, SSLCipherSuite(TLS_PSK_WITH_AES_128_GCM_SHA256))
        for (identity, key) in keys {
            let keyData = key.withUnsafeBytes { DispatchData(bytes: $0) }
            let identityData = Data(identity.utf8).withUnsafeBytes { DispatchData(bytes: $0) }
            sec_protocol_options_add_pre_shared_key(options, keyData._bridgeToObjectiveC(), identityData._bridgeToObjectiveC())
        }
        return NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    }
}
