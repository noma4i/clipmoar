# Changelog

## [1.2.1] - 2026-03-29

### Fixed
- High memory usage when capturing screenshots (read PNG instead of TIFF from pasteboard)
- Memory accumulation during image processing (ImageIO instead of NSImage/lockFocus)
- CIContext caching decoded images between calls
- NSEvent monitor leak when opening Edit Look repeatedly
- CoreData faulted-in image data not released after insert
- Unnecessary pasteboard data reads in isEmpty() check
- Thumbnail and app icon decoded on every table scroll (added NSCache)

### Changed
- Image dimensions read via ImageIO (no full decode) in display title and preview info
- CoreData fetchItems uses fetchBatchSize for lazy loading

## [1.2.0] - 2026-03-28

### Added
- Homebrew Cask support (`brew tap noma4i/clipmoar ...`)
- Auto-update disabled for Homebrew installs with "Installed via Homebrew" in About
- GitHub Actions workflow to sync Cask formula on release

### Changed
- Image paste writes both TIFF and PNG representations for broader app compatibility
- Transforms grouped by category in Rules picker

### Fixed
- Image paste via Enter not working (CGEvent delivery, proper PNG/TIFF format)
- Messenger image copy (Telegram etc.) saved as file path instead of image

## [1.1.0] - 2026-03-28

### Added
- Stats dashboard with counters and 14-day area chart
- Auto-update checker with GitHub releases
- Status bar menu with all Settings tabs and SF Symbol icons
- Hover zone highlight in Look Editor (red border on mock panel)
- Line numbers in Transforms playground input/output
- SemanticVersion model for version comparison

### Changed
- ClipboardRuleEngine split into separate files (Shell, Text, Encoding transforms)
- TransformsSettingsView grouped by category (Cleanup, Shell, Text, Encoding, JSON/Markup, URL)
- About tab shows version from Info.plist, update check UI
- Settings views aligned to top-leading

### Fixed
- Base64 decode with whitespace in input
- Window sizing for Settings (fixed 860x700)

## [1.0.0] - 2026-03-25

### Added
- Clipboard history with CoreData persistence
- Text, image and file copy support
- Large Type preview (Tab) - fullscreen preview
- Global hotkey support with recorder
- Per-application transform rules with 28 transforms
- Regex-based clipboard rules
- Image processing filters (resize, convert, strip metadata, sharpen)
- Panel position and screen selection
- Configurable theme with live Look editor
- Ignore apps by bundle ID
- AI tab for integrations
- Search in clipboard history
- Preview panel for items
- Secure Input detector
- History retention settings
- Native macOS experience - pure Swift, no Electron
