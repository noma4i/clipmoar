# Changelog

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
