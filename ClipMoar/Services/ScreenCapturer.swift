import AppKit
import CompanionKit
import ScreenCaptureKit

protocol ScreenCapturing {
    func displays() async throws -> [DisplayInfo]
    func capture(displayId: UInt32?) async throws -> (png: Data, windows: [WindowFrame])
}

struct CapturedWindow {
    let frame: CGRect
    let app: String
    let title: String
}

func windowFrames(_ windows: [CapturedWindow], display: CGRect, pixelWidth: Int, pixelHeight: Int) -> [WindowFrame] {
    let scaleX = CGFloat(pixelWidth) / display.width
    let scaleY = CGFloat(pixelHeight) / display.height
    return windows.compactMap { window in
        guard window.frame.width >= 40, window.frame.height >= 40 else { return nil }
        let clipped = window.frame.intersection(display)
        guard !clipped.isNull, !clipped.isEmpty else { return nil }
        let left = Int(((clipped.minX - display.minX) * scaleX).rounded())
        let top = Int(((clipped.minY - display.minY) * scaleY).rounded())
        let right = Int(((clipped.maxX - display.minX) * scaleX).rounded())
        let bottom = Int(((clipped.maxY - display.minY) * scaleY).rounded())
        return WindowFrame(x: left, y: top, width: right - left, height: bottom - top, app: window.app, title: window.title)
    }
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
            let mode = CGDisplayCopyDisplayMode(display.displayID)
            return DisplayInfo(
                id: display.displayID,
                name: screen?.localizedName ?? "Display",
                width: mode?.pixelWidth ?? CGDisplayPixelsWide(display.displayID),
                height: mode?.pixelHeight ?? CGDisplayPixelsHigh(display.displayID),
                isMain: display.displayID == CGMainDisplayID()
            )
        }
    }

    func capture(displayId: UInt32?) async throws -> (png: Data, windows: [WindowFrame]) {
        guard CGPreflightScreenCaptureAccess() else { throw ScreenCaptureError.permissionDenied }
        let selectedID = displayId ?? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }.flatMap(screenID)
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == selectedID }) else {
            throw ScreenCaptureError.displayUnavailable
        }
        let config = SCStreamConfiguration()
        let mode = CGDisplayCopyDisplayMode(display.displayID)
        config.width = mode?.pixelWidth ?? CGDisplayPixelsWide(display.displayID)
        config.height = mode?.pixelHeight ?? CGDisplayPixelsHigh(display.displayID)
        let shareableWindows = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
        let ordered = (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []).compactMap { info -> CapturedWindow? in
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let window = shareableWindows[id], window.isOnScreen,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0,
                  let owner = window.owningApplication,
                  owner.processID != ProcessInfo.processInfo.processIdentifier,
                  owner.bundleIdentifier != "com.apple.dock",
                  owner.bundleIdentifier != "com.apple.systemuiserver"
            else { return nil }
            return CapturedWindow(frame: window.frame, app: owner.applicationName, title: window.title ?? "")
        }
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(display: display, excludingWindows: []),
            configuration: config
        )
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.encodingFailed
        }
        return (png, windowFrames(ordered, display: display.frame, pixelWidth: image.width, pixelHeight: image.height))
    }

    private func screenID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
