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
            if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
                if let bitmap = NSBitmapImageRep(data: tiff),
                   let png = bitmap.representation(using: .png, properties: [:])
                {
                    pasteboard.setData(png, forType: .png)
                }
                NSLog("[ClipMoar] paste image: tiff=%d png=%d bytes", tiff.count, data.count)
            } else {
                pasteboard.setData(data, forType: .png)
                NSLog("[ClipMoar] paste image: raw data=%d bytes (no NSImage)", data.count)
            }
        } else if let content = item.content {
            pasteboard.setString(content, forType: .string)
        }

        pasteboard.setData(Data(), forType: Self.markerType)
    }

    func pasteFromPasteboard(item: ClipboardItem, previousApp: NSRunningApplication? = nil) {
        writeToPasteboard(item: item)

        NSLog("[ClipMoar] paste: type=%@ imageData=%d previousApp=%@ pid=%d",
              item.contentType ?? "nil",
              item.imageData?.count ?? -1,
              previousApp?.localizedName ?? "nil",
              previousApp?.processIdentifier ?? -1)

        previousApp?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let source = CGEventSource(stateID: .hidSystemState),
                  let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            else {
                NSLog("[ClipMoar] paste: failed to create CGEvent")
                return
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            NSLog("[ClipMoar] paste: CGEvent posted")
        }
    }
}
