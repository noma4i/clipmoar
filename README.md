# ClipMoar

Clipboard manager for macOS. Built with Swift and AppKit.

## Features

- Clipboard history with CoreData persistence
- Lives in both the main window and the menu bar
- Configurable visibility: show/hide dock icon and menu bar icon independently
- Native macOS experience - pure AppKit, no Electron

## Requirements

- macOS 14.0+
- Xcode 15+
- Swift 5.9+

## Build

```bash
xcodebuild -project ClipMoar.xcodeproj -scheme ClipMoar build
```

## License

MIT
