@testable import ClipMoar
import XCTest

final class LookEditorLayoutTests: XCTestCase {
    func testTallContentFitsVisibleScreen() {
        let visible = NSRect(x: 100, y: 40, width: 2560, height: 1400)
        let mock = NSRect(x: 2400, y: 1200, width: 200, height: 200)
        let frame = lookEditorFrame(fitting: NSSize(width: 500, height: 1800), visibleFrame: visible, mockFrame: mock)

        XCTAssertEqual(frame.height, visible.height - 24)
        XCTAssertTrue(visible.contains(frame))
        XCTAssertEqual(frame.minY, visible.minY + 12)
        XCTAssertEqual(frame.maxY, visible.maxY - 12)
    }

    func testShortContentKeepsHeightAndCentersOnMock() {
        let visible = NSRect(x: 0, y: 0, width: 2560, height: 1400)
        let mock = NSRect(x: 400, y: 500, width: 400, height: 400)
        let frame = lookEditorFrame(fitting: NSSize(width: 500, height: 600), visibleFrame: visible, mockFrame: mock)

        XCTAssertEqual(frame.height, 600)
        XCTAssertEqual(frame.midY, mock.midY)
        XCTAssertTrue(visible.contains(frame))
    }
}
