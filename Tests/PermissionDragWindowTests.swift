@testable import ClipMoar
import XCTest

final class PermissionDragWindowTests: XCTestCase {
    func testEachPermissionResetsOnce() {
        let previousReset = PermissionDragWindow.resetCommand
        let previousServices = PermissionDragWindow.resetServices
        defer {
            PermissionDragWindow.resetCommand = previousReset
            PermissionDragWindow.resetServices = previousServices
        }
        PermissionDragWindow.resetServices = []
        var resets: [String] = []
        PermissionDragWindow.resetCommand = { resets.append($0.service) }

        PermissionDragWindow.resetOnce(.screenRecording)
        PermissionDragWindow.resetOnce(.screenRecording)
        PermissionDragWindow.resetOnce(.accessibility)

        XCTAssertEqual(resets, ["ScreenCapture", "Accessibility"])
    }
}
