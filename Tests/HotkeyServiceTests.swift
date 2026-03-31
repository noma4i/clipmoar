@testable import ClipMoar
import XCTest

final class MockCarbonBackend: CarbonHotkeyBackend {
    var isHotkeyRegistered = false
    var isHandlerInstalled = false

    var installHandlerCalls = 0
    var registerHotkeyCalls: [(keyCode: UInt32, modifiers: UInt32)] = []
    var unregisterHotkeyCalls = 0
    var removeHandlerCalls = 0

    func installHandler(service _: HotkeyService) {
        installHandlerCalls += 1
        isHandlerInstalled = true
    }

    func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        registerHotkeyCalls.append((keyCode, modifiers))
        isHotkeyRegistered = true
    }

    func unregisterHotkey() {
        unregisterHotkeyCalls += 1
        isHotkeyRegistered = false
    }

    func removeHandler() {
        removeHandlerCalls += 1
        isHandlerInstalled = false
    }
}

final class HotkeyServiceTests: XCTestCase {
    private func makeSUT() -> (HotkeyService, MockCarbonBackend, MockSettings) {
        let backend = MockCarbonBackend()
        let settings = MockSettings()
        let service = HotkeyService(settings: settings, backend: backend)
        return (service, backend, settings)
    }

    func testRegisterSetsCallback() {
        let (service, backend, _) = makeSUT()
        var triggered = false

        service.register { triggered = true }
        service.fireTrigger()

        XCTAssertTrue(triggered)
        XCTAssertEqual(backend.installHandlerCalls, 1)
        XCTAssertEqual(backend.registerHotkeyCalls.count, 1)
    }

    func testReregisterPreservesCallback() {
        let (service, _, _) = makeSUT()
        var count = 0

        service.register { count += 1 }
        service.reregister()
        service.fireTrigger()

        XCTAssertEqual(count, 1, "Callback must survive reregister")
    }

    func testReregisterCallsBackendCorrectly() {
        let (service, backend, _) = makeSUT()

        service.register {}
        XCTAssertEqual(backend.registerHotkeyCalls.count, 1)
        XCTAssertEqual(backend.installHandlerCalls, 1)

        service.reregister()

        XCTAssertEqual(backend.unregisterHotkeyCalls, 1)
        XCTAssertEqual(backend.removeHandlerCalls, 1)
        XCTAssertEqual(backend.registerHotkeyCalls.count, 2)
        XCTAssertEqual(backend.installHandlerCalls, 2)
    }

    func testUnregisterClearsCallback() {
        let (service, _, _) = makeSUT()
        var triggered = false

        service.register { triggered = true }
        service.unregister()
        service.fireTrigger()

        XCTAssertFalse(triggered, "Callback must be nil after unregister")
    }

    func testUnregisterCleansUpBackend() {
        let (service, backend, _) = makeSUT()

        service.register {}
        service.unregister()

        XCTAssertEqual(backend.unregisterHotkeyCalls, 1)
        XCTAssertEqual(backend.removeHandlerCalls, 1)
        XCTAssertFalse(backend.isHotkeyRegistered)
        XCTAssertFalse(backend.isHandlerInstalled)
    }

    func testSuspendKeepsCallback() {
        let (service, backend, _) = makeSUT()
        var triggered = false

        service.register { triggered = true }
        service.suspend()

        XCTAssertEqual(backend.unregisterHotkeyCalls, 1)
        XCTAssertEqual(backend.removeHandlerCalls, 0, "suspend must not remove handler")

        service.fireTrigger()
        XCTAssertTrue(triggered, "Callback must survive suspend")
    }

    func testResumeAfterSuspend() {
        let (service, backend, _) = makeSUT()

        service.register {}
        service.suspend()
        service.resume()

        XCTAssertEqual(backend.registerHotkeyCalls.count, 2)
        XCTAssertTrue(backend.isHotkeyRegistered)
    }

    func testResumeWithoutRegisterIsNoop() {
        let (service, backend, _) = makeSUT()

        service.resume()

        XCTAssertEqual(backend.registerHotkeyCalls.count, 0)
        XCTAssertEqual(backend.installHandlerCalls, 0)
    }

    func testReregisterUsesCurrentSettings() {
        let (service, backend, settings) = makeSUT()

        settings.hotkeyKeyCode = 10
        settings.hotkeyModifiers = 256 // Cmd
        service.register {}

        settings.hotkeyKeyCode = 20
        settings.hotkeyModifiers = 512 // Shift
        service.reregister()

        let lastCall = backend.registerHotkeyCalls.last
        XCTAssertEqual(lastCall?.keyCode, 20)
    }

    // MARK: - Multiple hotkeys

    func testTwoServicesFireIndependently() {
        let backend1 = MockCarbonBackend()
        let backend2 = MockCarbonBackend()
        let settings = MockSettings()

        let svc1 = HotkeyService(settings: settings, backend: backend1)
        let svc2 = HotkeyService(
            settings: settings,
            backend: backend2,
            keyCode: { $0.transformHotkeyKeyCode },
            modifiers: { $0.transformHotkeyModifiers }
        )

        var triggered1 = false
        var triggered2 = false
        svc1.register { triggered1 = true }
        svc2.register { triggered2 = true }

        svc1.fireTrigger()
        XCTAssertTrue(triggered1)
        XCTAssertFalse(triggered2, "Second service must not fire when first triggers")

        triggered1 = false
        svc2.fireTrigger()
        XCTAssertFalse(triggered1, "First service must not fire when second triggers")
        XCTAssertTrue(triggered2)
    }

    func testTwoServicesReadDifferentSettings() {
        let backend1 = MockCarbonBackend()
        let backend2 = MockCarbonBackend()
        let settings = MockSettings()
        settings.hotkeyKeyCode = 10
        settings.hotkeyModifiers = 256
        settings.transformHotkeyKeyCode = 20
        settings.transformHotkeyModifiers = 512

        let svc1 = HotkeyService(settings: settings, backend: backend1)
        let svc2 = HotkeyService(
            settings: settings,
            backend: backend2,
            keyCode: { $0.transformHotkeyKeyCode },
            modifiers: { $0.transformHotkeyModifiers }
        )

        svc1.register {}
        svc2.register {}

        XCTAssertEqual(backend1.registerHotkeyCalls.last?.keyCode, 10)
        XCTAssertEqual(backend2.registerHotkeyCalls.last?.keyCode, 20)
    }

    func testUnregisterOneDoesNotAffectOther() {
        let backend1 = MockCarbonBackend()
        let backend2 = MockCarbonBackend()
        let settings = MockSettings()

        let svc1 = HotkeyService(settings: settings, backend: backend1)
        let svc2 = HotkeyService(settings: settings, backend: backend2)

        var triggered2 = false
        svc1.register {}
        svc2.register { triggered2 = true }

        svc1.unregister()
        svc2.fireTrigger()

        XCTAssertTrue(triggered2, "Second service must survive first unregister")
        XCTAssertTrue(backend2.isHotkeyRegistered)
    }

    func testSuspendOneDoesNotAffectOther() {
        let backend1 = MockCarbonBackend()
        let backend2 = MockCarbonBackend()
        let settings = MockSettings()

        let svc1 = HotkeyService(settings: settings, backend: backend1)
        let svc2 = HotkeyService(settings: settings, backend: backend2)

        var triggered2 = false
        svc1.register {}
        svc2.register { triggered2 = true }

        svc1.suspend()

        XCTAssertTrue(backend2.isHotkeyRegistered, "Second backend must stay registered")
        svc2.fireTrigger()
        XCTAssertTrue(triggered2)
    }
}
