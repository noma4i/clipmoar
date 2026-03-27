@testable import ClipMoar
import Foundation
import XCTest

final class SemanticVersionTests: XCTestCase {
    func testParsesValidVersion() {
        let v = SemanticVersion(string: "1.2.3")
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.major, 1)
        XCTAssertEqual(v?.minor, 2)
        XCTAssertEqual(v?.patch, 3)
    }

    func testParsesVersionWithVPrefix() {
        let v = SemanticVersion(string: "v2.0.1")
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.major, 2)
        XCTAssertEqual(v?.minor, 0)
        XCTAssertEqual(v?.patch, 1)
    }

    func testRejectsInvalidVersions() {
        XCTAssertNil(SemanticVersion(string: "1.2"))
        XCTAssertNil(SemanticVersion(string: "abc"))
        XCTAssertNil(SemanticVersion(string: ""))
        XCTAssertNil(SemanticVersion(string: "1.2.3.4"))
    }

    func testComparison() throws {
        let v100 = try XCTUnwrap(SemanticVersion(string: "1.0.0"))
        let v101 = try XCTUnwrap(SemanticVersion(string: "1.0.1"))
        let v110 = try XCTUnwrap(SemanticVersion(string: "1.1.0"))
        let v200 = try XCTUnwrap(SemanticVersion(string: "2.0.0"))

        XCTAssertTrue(v100 < v101)
        XCTAssertTrue(v101 < v110)
        XCTAssertTrue(v110 < v200)
        XCTAssertFalse(v200 < v100)
        XCTAssertEqual(v100, SemanticVersion(string: "1.0.0"))
    }

    func testDescription() throws {
        let v = try XCTUnwrap(SemanticVersion(string: "v3.2.1"))
        XCTAssertEqual(v.description, "3.2.1")
    }
}

final class GitHubReleaseTests: XCTestCase {
    func testDecodesRelease() throws {
        let json = """
        {
            "tag_name": "v1.2.0",
            "body": "Bug fixes",
            "assets": [
                {
                    "name": "ClipMoar.app.zip",
                    "browser_download_url": "https://example.com/ClipMoar.app.zip",
                    "size": 5000000
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v1.2.0")
        XCTAssertEqual(release.body, "Bug fixes")
        XCTAssertEqual(release.assets.count, 1)
        XCTAssertEqual(release.assets[0].name, "ClipMoar.app.zip")
        XCTAssertEqual(release.assets[0].browserDownloadUrl, "https://example.com/ClipMoar.app.zip")
        XCTAssertEqual(release.assets[0].size, 5_000_000)
    }

    func testDecodesReleaseWithNullBody() throws {
        let json = """
        {
            "tag_name": "v1.0.0",
            "body": null,
            "assets": []
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertNil(release.body)
        XCTAssertTrue(release.assets.isEmpty)
    }
}

final class UpdateServiceTests: XCTestCase {
    func testCheckFindsNewVersion() {
        let json = """
        {
            "tag_name": "v2.0.0",
            "body": "New release",
            "assets": [{"name": "ClipMoar.app.zip", "browser_download_url": "https://example.com/dl.zip", "size": 1000}]
        }
        """.data(using: .utf8)!

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(url: URL(string: "https://api.github.com")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let settings = TestUpdateSettings()
        let service = UpdateService(settings: settings, session: session, currentVersion: "1.0.0")
        service.checkForUpdates()

        let exp = expectation(description: "state updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if case let .available(version, notes, _) = service.state {
                XCTAssertEqual(version, "2.0.0")
                XCTAssertEqual(notes, "New release")
            } else {
                XCTFail("Expected .available, got \(service.state)")
            }
            XCTAssertNotNil(settings.lastUpdateCheck)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
    }

    func testCheckReportsUpToDate() {
        let json = """
        {
            "tag_name": "v1.0.0",
            "body": null,
            "assets": []
        }
        """.data(using: .utf8)!

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(url: URL(string: "https://api.github.com")!,
                                           statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }

        let settings = TestUpdateSettings()
        let service = UpdateService(settings: settings, session: session, currentVersion: "1.0.0")
        service.checkForUpdates()

        let exp = expectation(description: "state updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertEqual(service.state, .upToDate)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
    }

    func testCheckReportsError() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let settings = TestUpdateSettings()
        let service = UpdateService(settings: settings, session: session, currentVersion: "1.0.0")
        service.checkForUpdates()

        let exp = expectation(description: "state updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if case .error = service.state {
                // ok
            } else {
                XCTFail("Expected .error, got \(service.state)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
    }

    func testAutoCheckSkipsWhenRecentlyChecked() {
        let settings = TestUpdateSettings()
        settings.lastUpdateCheck = Date()
        settings.autoCheckUpdates = true

        let service = UpdateService(settings: settings, currentVersion: "1.0.0")
        service.scheduleAutomaticCheck()

        XCTAssertEqual(service.state, .idle)
    }

    func testAutoCheckSkipsWhenDisabled() {
        let settings = TestUpdateSettings()
        settings.autoCheckUpdates = false

        let service = UpdateService(settings: settings, currentVersion: "1.0.0")
        service.scheduleAutomaticCheck()

        XCTAssertEqual(service.state, .idle)
    }
}

private final class TestUpdateSettings: SettingsStore {
    var showInDock = true
    var showInMenuBar = true
    var maxHistorySize = 500
    var hotkeyKeyCode = 0
    var hotkeyModifiers: UInt32 = 0
    var storeText = true
    var storeImages = true
    var textRetentionHours = 0
    var imageRetentionHours = 0
    var panelPositionX: Double = 0.5
    var panelPositionY: Double = 0.65
    var panelScreenMode = 0
    var largeTypeEnabled = true
    var panelFontSize = 15
    var panelTheme = 0
    var panelAccentColor = 0
    var panelFontName = ""
    var panelAccentHex = "2672B5"
    var panelCornerRadius = 0
    var panelPaddingH = 12
    var panelPaddingV = 4
    var panelMargin = 0
    var panelFontWeight = 0
    var panelIconSize = 22
    var panelVisibleRows = 9
    var panelTextColorHex = "E6E6E6"
    var previewFontName = ""
    var previewFontSize = 11
    var previewPadding = 10
    var previewTextColorHex = "D9D9D9"
    var previewBgColorHex = "1A1A1A"
    var searchFontName = ""
    var searchFontSize = 16
    var searchTextColorHex = "E6E6E6"
    var searchPlaceholderColorHex = "666666"
    var metaFontSize = 10
    var largeTypeFontSize = 48
    var compressImages = false
    var imageMaxWidth = 0
    var imageMaxHeight = 0
    var imageQuality = 80
    var imageRemoveBackground = false
    var imageConvertToPNG = false
    var imageConvertToJPEG = false
    var imageStripMetadata = false
    var imageAutoEnhance = false
    var imageGrayscale = false
    var imageAutoRotate = false
    var imageTrimWhitespace = false
    var imageSharpen = false
    var imageReduceNoise = false
    var ignoredAppBundleIds: [String] = []
    var autoCheckUpdates = true
    var lastUpdateCheck: Date?
    func registerDefaults() {}
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
