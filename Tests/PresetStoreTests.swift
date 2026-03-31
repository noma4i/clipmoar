@testable import ClipMoar
import XCTest

final class PresetStoreTests: XCTestCase {
    private func makeStore() -> PresetStore {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        return PresetStore(defaults: defaults)
    }

    func testFirstLaunchSeedsBuiltInPresets() {
        let store = makeStore()
        XCTAssertEqual(store.presets.count, 5)
        XCTAssertTrue(store.presets.allSatisfy(\.isBuiltIn))
    }

    func testBuiltInPresetNames() {
        let store = makeStore()
        let names = store.presets.map(\.name)
        XCTAssertTrue(names.contains("Clean Terminal Output"))
        XCTAssertTrue(names.contains("Claude Code"))
        XCTAssertTrue(names.contains("Clean URL"))
        XCTAssertTrue(names.contains("Code Snippet"))
        XCTAssertTrue(names.contains("Plain Text Cleanup"))
    }

    func testAddCustomPreset() throws {
        let store = makeStore()
        store.add()
        XCTAssertEqual(store.presets.count, 6)
        XCTAssertFalse(try XCTUnwrap(store.presets.last?.isBuiltIn))
        XCTAssertEqual(store.presets.last?.name, "New Preset")
    }

    func testCannotRemoveBuiltInPreset() throws {
        let store = makeStore()
        let builtInId = try XCTUnwrap(store.presets.first?.id)
        _ = store.remove(id: builtInId)
        XCTAssertEqual(store.presets.count, 5)
    }

    func testRemoveCustomPreset() throws {
        let store = makeStore()
        store.add()
        let customId = try XCTUnwrap(store.presets.last?.id)
        _ = store.remove(id: customId)
        XCTAssertEqual(store.presets.count, 5)
        XCTAssertTrue(store.presets.allSatisfy(\.isBuiltIn))
    }

    func testResetToDefault() {
        let store = makeStore()
        guard let idx = store.presets.firstIndex(where: { $0.name == "Claude Code" }) else {
            XCTFail("Claude Code preset not found")
            return
        }
        let originalTypes = store.presets[idx].transformTypes
        store.presets[idx].transformTypes = [.trimWhitespace]
        store.save()
        store.resetToDefault(id: store.presets[idx].id)
        XCTAssertEqual(store.presets[idx].transformTypes, originalTypes)
    }

    func testPersistenceRoundTrip() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store1 = PresetStore(defaults: defaults)
        store1.add()
        let count = store1.presets.count
        let store2 = PresetStore(defaults: defaults)
        XCTAssertEqual(store2.presets.count, count)
    }

    func testApplyPresetAddsTransforms() throws {
        let store = makeStore()
        let preset = try XCTUnwrap(store.presets.first { $0.name == "Claude Code" })
        var rule = ClipboardRule(name: "Test")
        rule.transforms = [ClipboardTransform(type: .trimWhitespace)]
        let originalCount = rule.transforms.count
        for type in preset.transformTypes {
            rule.transforms.append(ClipboardTransform(type: type))
        }
        XCTAssertEqual(rule.transforms.count, originalCount + preset.transformTypes.count)
        XCTAssertEqual(rule.transforms.first?.type, .trimWhitespace)
    }
}
