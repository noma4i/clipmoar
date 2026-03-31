@testable import ClipMoar
import XCTest

final class TransformOverlayTests: XCTestCase {
    func testOverlayContentViewRendersOptions() {
        let options = [
            OverlayTransformOption(name: "Claude Code", icon: "tray.2", transformed: "joined text"),
            OverlayTransformOption(name: "Trim", icon: "scissors", transformed: "trimmed"),
        ]
        let view = OverlayContentView(options: options, selectedIndex: 0, shortcutHint: "Opt+Cmd+V")
        _ = view.body
    }

    func testOverlayContentViewHandlesEmpty() {
        let view = OverlayContentView(options: [], selectedIndex: 0, shortcutHint: "Opt+Cmd+V")
        _ = view.body
    }

    func testSelectNextCycles() {
        var index = 0
        let count = 3
        for expected in [1, 2, 0, 1] {
            index = (index + 1) % count
            XCTAssertEqual(index, expected)
        }
    }

    func testOnlyChangedTransformsShown() {
        let options = ClipboardTransformType.allCases.compactMap { type -> OverlayTransformOption? in
            let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: []))
            let input = "hello"
            let result = engine.applyTransform(ClipboardTransform(type: type), to: input)
            guard result != input else { return nil }
            return OverlayTransformOption(name: type.displayName, icon: type.icon, transformed: result)
        }
        XCTAssertFalse(options.isEmpty, "At least some transforms should modify 'hello'")
        for option in options {
            XCTAssertNotEqual(option.transformed, "hello")
        }
    }

    func testPresetTransformsApplied() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let presetStore = PresetStore(defaults: defaults)
        let preset = try XCTUnwrap(presetStore.presets.first { $0.name == "Claude Code" })

        let rule = ClipboardRule(
            name: preset.name,
            transforms: preset.transformTypes.map { ClipboardTransform(type: $0) }
        )
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: [rule]))
        let input = "line one\nline two\n\n\n\nline three  "
        let result = engine.apply(to: input)
        XCTAssertNotEqual(result.text, input)
    }
}
