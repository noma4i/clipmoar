@testable import ClipMoar
import CompanionKit
import XCTest

final class WindowFramesTests: XCTestCase {
    func testFramesAreClippedScaledAndOrdered() {
        let windows = [
            CapturedWindow(frame: CGRect(x: 100, y: 50, width: 800, height: 600), app: "First", title: "A"),
            CapturedWindow(frame: CGRect(x: -50, y: 1400, width: 100, height: 100), app: "Second", title: "B"),
            CapturedWindow(frame: CGRect(x: 1, y: 1, width: 39, height: 100), app: "Small", title: ""),
            CapturedWindow(frame: CGRect(x: 2600, y: 0, width: 100, height: 100), app: "Other", title: ""),
        ]
        XCTAssertEqual(windowFrames(windows, display: CGRect(x: 0, y: 0, width: 2560, height: 1440), pixelWidth: 5120, pixelHeight: 2880), [
            WindowFrame(x: 200, y: 100, width: 1600, height: 1200, app: "First", title: "A"),
            WindowFrame(x: 0, y: 2800, width: 100, height: 80, app: "Second", title: "B"),
        ])
        XCTAssertEqual(windowFrames(windows, display: CGRect(x: 2560, y: 0, width: 2560, height: 1440), pixelWidth: 5120, pixelHeight: 2880), [
            WindowFrame(x: 80, y: 0, width: 200, height: 200, app: "Other", title: ""),
        ])
    }
}
