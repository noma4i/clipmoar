@testable import ClipMoar
import XCTest

final class PanelConfigurationTests: XCTestCase {
    func testPanelConfigurationBuildsSingleDerivedSnapshot() throws {
        let suiteName = "PanelConfigurationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let settings = UserDefaultsSettingsStore(defaults: defaults)
        settings.registerDefaults()
        settings.panelTheme = PanelTheme.light.rawValue
        settings.panelFontSize = 18
        settings.panelPaddingV = 6
        settings.panelVisibleRows = 3
        settings.searchFontSize = 20
        settings.previewBgColorHex = "F0F0F0"

        let configuration = settings.panelConfiguration()

        XCTAssertEqual(configuration.theme, .light)
        XCTAssertEqual(configuration.layout.visibleRows, 5)
        XCTAssertEqual(configuration.layout.rowHeight, 38)
        XCTAssertEqual(configuration.layout.searchFieldHeight, 32)
        XCTAssertEqual(configuration.layout.availableTextWidth, 380)

        let previewColor = configuration.preview.backgroundColor.usingColorSpace(.sRGB)
        XCTAssertEqual(previewColor?.redComponent ?? 0, 240.0 / 255.0, accuracy: 0.02)
        XCTAssertEqual(previewColor?.greenComponent ?? 0, 240.0 / 255.0, accuracy: 0.02)
        XCTAssertEqual(previewColor?.blueComponent ?? 0, 240.0 / 255.0, accuracy: 0.02)
    }
}
