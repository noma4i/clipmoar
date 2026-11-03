@testable import ClipMoar
import XCTest

final class SingleInstanceTests: XCTestCase {
    func testSecondCopyTerminates() {
        XCTAssertTrue(SingleInstance.shouldTerminate(runningPids: [10, 20], current: 20))
    }

    func testOnlyCopyContinues() {
        XCTAssertFalse(SingleInstance.shouldTerminate(runningPids: [20], current: 20))
    }
}
