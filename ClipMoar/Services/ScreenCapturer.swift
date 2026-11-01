import AppKit
import CompanionKit
import ScreenCaptureKit

protocol ScreenCapturing {
    func displays() async throws -> [DisplayInfo]
    func capture(displayId: UInt32?) async throws -> Data
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case displayUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Screen Recording access is required."
        case .displayUnavailable: return "The selected display is unavailable."
        case .encodingFailed: return "Could not encode the screenshot as PNG."
        }
    }
}

struct ScreenCapturer: ScreenCapturing {
    func displays() async throws -> [DisplayInfo] {
        guard CGPreflightScreenCaptureAccess() else { throw ScreenCaptureError.permissionDenied }
        let content = try await SCShareableContent.current
        return content.displays.map { display in
            let screen = NSScreen.screens.first { screenID($0) == display.displayID }
            return DisplayInfo(
                id: display.displayID,
                name: screen?.localizedName ?? "Display",
                width: CGDisplayPixelsWide(display.displayID),
                height: CGDisplayPixelsHigh(display.displayID),
                isMain: display.displayID == CGMainDisplayID()
            )
        }
    }

    func capture(displayId: UInt32?) async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else { throw ScreenCaptureError.permissionDenied }
        let selectedID = displayId ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }.flatMap(screenID)
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == selectedID }) else {
            throw ScreenCaptureError.displayUnavailable
        }
        let config = SCStreamConfiguration()
        config.width = CGDisplayPixelsWide(display.displayID)
        config.height = CGDisplayPixelsHigh(display.displayID)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(display: display, excludingWindows: []),
            configuration: config
        )
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.encodingFailed
        }
        return png
    }

    private func screenID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
