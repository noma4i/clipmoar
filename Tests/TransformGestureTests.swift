@testable import ClipMoar
import XCTest

final class TransformGestureTests: XCTestCase {
    func testInitialStateIsIdle() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let presetStore = PresetStore(defaults: defaults)
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: []))
        let settings = MockSettings()
        let service = ClipboardService(
            repository: MockRepository(),
            settings: settings,
            pasteboard: MockPasteboard()
        )
        let overlay = TransformOverlayController(
            ruleEngine: engine,
            settings: settings,
            clipboardService: service,
            presetStore: presetStore
        )
        var instantCalled = false
        let gesture = TransformGestureController(
            overlay: overlay,
            onInstantPaste: { instantCalled = true },
            readModifiers: { [.command, .option] }
        )

        if case .idle = gesture.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Initial state must be idle")
        }
        XCTAssertFalse(instantCalled)
    }

    func testHotkeyPressTransitionsToPending() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let presetStore = PresetStore(defaults: defaults)
        let engine = ClipboardRuleEngine(store: InMemoryRuleStore(rules: []))
        let settings = MockSettings()
        let service = ClipboardService(
            repository: MockRepository(),
            settings: settings,
            pasteboard: MockPasteboard()
        )
        let overlay = TransformOverlayController(
            ruleEngine: engine,
            settings: settings,
            clipboardService: service,
            presetStore: presetStore
        )
        let gesture = TransformGestureController(
            overlay: overlay,
            onInstantPaste: {},
            readModifiers: { [.command, .option] }
        )

        gesture.handleHotkeyPress()

        if case .pending = gesture.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("State must be pending after hotkey press")
        }
    }
}
