import CryptoKit
import Foundation
import Network
import Security

public enum CompanionTLS {
    public static func pairingKey(pin: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(pin.utf8)), salt: Data("clipmoar-pair-v1".utf8), outputByteCount: 32)
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
