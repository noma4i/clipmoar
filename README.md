<p align="center">
  <img src="assets/header.png" alt="ClipMoar" width="400">
</p>

# ClipMoar

Clipboard manager for macOS. Built with Swift, AppKit and SwiftUI.

## Features

- Clipboard history with CoreData persistence
- Text, image and file copy support
- Large Type preview (Tab) - Alfred-style fullscreen preview
- Per-application transform rules
- Panel position and screen selection
- History retention settings
- Global hotkey support
- Configurable visibility: dock and menu bar
- Native macOS experience - pure Swift, no Electron

## Requirements

- macOS 14.0+
- Swift 5.9+
- Xcode 26+
- Ruby gem `xcodeproj` for regenerating `ClipMoar.xcodeproj`

## Build

```bash
./scripts/build.sh
```

## Run

```bash
make run
```

## Xcode Project

Generate or refresh the checked-in Xcode project:

```bash
ruby scripts/generate_xcodeproj.rb
```

Then open `ClipMoar.xcodeproj` in Xcode.

## License

MIT
