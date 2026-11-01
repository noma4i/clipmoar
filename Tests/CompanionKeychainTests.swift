@testable import ClipMoar
import Foundation
import Security
import XCTest

final class CompanionKeychainTests: XCTestCase {
    private let service = "com.noma4i.ClipMoar.companion.test.\(UUID().uuidString)"

    override func tearDownWithError() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        let status = SecItemDelete(query as CFDictionary)
        XCTAssertTrue(status == errSecSuccess || status == errSecItemNotFound)
        try super.tearDownWithError()
    }

    func testDeviceLifecycleInKeychain() throws {
        let store = KeychainCompanionDevices(service: service)
        let first = CompanionDevice(id: "first", name: "iPad", key: Data([1, 2, 3]))
        let second = CompanionDevice(id: "second", name: "iPhone", key: Data([4, 5, 6]))

        XCTAssertEqual(try store.devices(), [])
        try store.save(first)
        try store.save(second)
        XCTAssertEqual(try store.devices(), [first, second])
        try store.revoke(first.id)
        XCTAssertEqual(try store.devices(), [second])
    }
}
