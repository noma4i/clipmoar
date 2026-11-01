import AppKit
import ApplicationServices
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
    var processID: pid_t? = nil
    var parts: [WindowPartNode] = []
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
        let parent = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        return WindowFrame(x: left, y: top, width: right - left, height: bottom - top, app: window.app, title: window.title, children: windowParts(window.parts, parent: parent, app: window.app))
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
            return CapturedWindow(frame: window.frame, app: owner.applicationName, title: window.title ?? "", processID: owner.processID)
        }
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(display: display, excludingWindows: []),
            configuration: config
        )
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.encodingFailed
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.15
        let windows = ordered.map { window in
            var window = window
            if AXIsProcessTrusted(), let pid = window.processID, ProcessInfo.processInfo.systemUptime < deadline {
                window.parts = accessibilityParts(pid: pid, frame: window.frame, display: display.frame, pixelWidth: image.width, pixelHeight: image.height, deadline: deadline)
            }
            return window
        }
        return (png, windowFrames(windows, display: display.frame, pixelWidth: image.width, pixelHeight: image.height))
    }

    private func screenID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

private func accessibilityParts(pid: pid_t, frame: CGRect, display: CGRect, pixelWidth: Int, pixelHeight: Int, deadline: TimeInterval) -> [WindowPartNode] {
    let application = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(application, 0.02)
    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        guard ProcessInfo.processInfo.systemUptime < deadline else { return nil }
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    func rect(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
    guard let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement],
          let window = windows.first(where: { element in
              guard let bounds = rect(element) else { return false }
              return abs(bounds.minX - frame.minX) <= 2 && abs(bounds.minY - frame.minY) <= 2 && abs(bounds.width - frame.width) <= 2 && abs(bounds.height - frame.height) <= 2
          }) else { return [] }
    var visited = 0
    func read(_ element: AXUIElement, depth: Int) -> WindowPartNode? {
        guard depth <= 64, visited < 2000, ProcessInfo.processInfo.systemUptime < deadline else { return nil }
        visited += 1
        AXUIElementSetMessagingTimeout(element, 0.02)
        var role = attribute(element, kAXRoleAttribute) as? String ?? ""
        let title = attribute(element, kAXTitleAttribute) as? String ?? ""
        let nodeRect = rect(element)
        if nodeRect == nil { role = "" }
        let bounds = nodeRect ?? frame
        let children = (attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []).compactMap { read($0, depth: depth + 1) }
        let x1 = ((bounds.minX - display.minX) * CGFloat(pixelWidth) / display.width).rounded()
        let y1 = ((bounds.minY - display.minY) * CGFloat(pixelHeight) / display.height).rounded()
        let x2 = ((bounds.maxX - display.minX) * CGFloat(pixelWidth) / display.width).rounded()
        let y2 = ((bounds.maxY - display.minY) * CGFloat(pixelHeight) / display.height).rounded()
        return WindowPartNode(role: role, title: title, rect: CGRect(x: x1, y: y1, width: x2 - x1, height: y2 - y1), children: children)
    }
    return (attribute(window, kAXChildrenAttribute) as? [AXUIElement] ?? []).compactMap { read($0, depth: 1) }
}
