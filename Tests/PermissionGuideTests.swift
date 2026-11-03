@testable import ClipMoar
import XCTest

final class PermissionGuideTests: XCTestCase {
    private let size = PermissionGuideLayout.panelSize
    private let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)

    func testGuideSitsAtSettingsBottomRight() {
        let settings = NSRect(x: 100, y: 100, width: 900, height: 700)
        let origin = PermissionGuideLayout.origin(settings: settings, visible: visible, size: size)
        XCTAssertEqual(origin.x, 100 + 900 - 480 - 16)
        XCTAssertEqual(origin.y, 100 + 16)
    }

    func testGuideClampsToScreenWithMargin() {
        let settings = NSRect(x: 0, y: -50, width: 300, height: 400)
        let origin = PermissionGuideLayout.origin(settings: settings, visible: visible, size: size)
        XCTAssertEqual(origin.x, 8)
        XCTAssertEqual(origin.y, 8)
        let right = NSRect(x: 1200, y: 100, width: 400, height: 700)
        XCTAssertEqual(PermissionGuideLayout.origin(settings: right, visible: visible, size: size).x, 1440 - 480 - 8)
    }

    func testPaneURLs() {
        XCTAssertEqual(
            PermissionDragWindow.Permission.accessibility.settingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        )
        XCTAssertEqual(
            PermissionDragWindow.Permission.screenRecording.settingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
        )
    }

    func testListNamePerMacOSVersion() {
        XCTAssertEqual(PermissionGuideLayout.listName(for: .accessibility, osMajorVersion: 27), "Device Control and Data Access")
        XCTAssertEqual(PermissionGuideLayout.listName(for: .accessibility, osMajorVersion: 15), "Accessibility")
        XCTAssertEqual(PermissionGuideLayout.listName(for: .screenRecording, osMajorVersion: 15), "Screen & System Audio Recording")
    }
}
