import Cocoa

protocol ClipboardActionServicing: AnyObject {
    func writeToPasteboard(item: ClipboardItem)
    func pasteFromPasteboard(item: ClipboardItem)
}

final class ClipboardActionService: ClipboardActionServicing {
    func writeToPasteboard(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.isImage, let data = item.imageData {
            pasteboard.setData(data, forType: .tiff)
            return
        }

        if let content = item.content {
            pasteboard.setString(content, forType: .string)
        }
    }

    func pasteFromPasteboard(item: ClipboardItem) {
        writeToPasteboard(item: item)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
