import Cocoa

protocol ClipboardActionServicing: AnyObject {
    func writeToPasteboard(item: ClipboardItem)
    func pasteFromPasteboard(item: ClipboardItem, previousApp: NSRunningApplication?)
}

final class ClipboardActionService: ClipboardActionServicing {
    static let markerType = NSPasteboard.PasteboardType("com.clipmoar.marker")

    func writeToPasteboard(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.isFile, let urls = item.fileURLs {
            pasteboard.writeObjects(urls as [NSURL])
        } else if item.isImage, let data = item.imageData {
            pasteboard.setData(data, forType: .png)
        } else if let content = item.content {
            pasteboard.setString(content, forType: .string)
        }

        pasteboard.setData(Data(), forType: Self.markerType)
    }

    func pasteFromPasteboard(item: ClipboardItem, previousApp: NSRunningApplication? = nil) {
        writeToPasteboard(item: item)

        previousApp?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else { return }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
