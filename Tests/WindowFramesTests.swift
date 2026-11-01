@testable import ClipMoar
import CompanionKit
import XCTest

final class WindowFramesTests: XCTestCase {
    func testPartsFilteringAndLimits() {
        func node(_ size: CGFloat, _ children: [WindowPartNode] = [], role: String = "AXGroup") -> WindowPartNode {
            WindowPartNode(role: role, title: "", rect: CGRect(x: 0, y: 0, width: size, height: size), children: children)
        }
        let leaf = node(120)
        let nested = node(700, [node(600, [node(500, [node(400, [node(300)])])])])
        let cases: [(String, [WindowPartNode], [WindowFrame])] = [
            ("small", [node(119)], []),
            ("transparent", [node(985, [leaf])], [WindowFrame(x: 0, y: 0, width: 120, height: 120, app: "App", title: "AXGroup")]),
            ("non-container", [node(800, [leaf], role: "AXButton")], [WindowFrame(x: 0, y: 0, width: 120, height: 120, app: "App", title: "AXGroup")]),
            ("depth", [nested], [WindowFrame(x: 0, y: 0, width: 700, height: 700, app: "App", title: "AXGroup", children: [
                WindowFrame(x: 0, y: 0, width: 600, height: 600, app: "App", title: "AXGroup", children: [
                    WindowFrame(x: 0, y: 0, width: 500, height: 500, app: "App", title: "AXGroup", children: [
                        WindowFrame(x: 0, y: 0, width: 400, height: 400, app: "App", title: "AXGroup"),
                    ]),
                ]),
            ])]),
            ("count", Array(repeating: leaf, count: 41), Array(repeating: WindowFrame(x: 0, y: 0, width: 120, height: 120, app: "App", title: "AXGroup"), count: 40)),
        ]
        for (name, input, expected) in cases {
            XCTAssertEqual(windowParts(input, parent: CGRect(x: 0, y: 0, width: 1000, height: 1000), app: "App"), expected, name)
        }
    }

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
