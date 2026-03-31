# Changelog

## [1.5.0] - 2026-03-31

### Added
- Transform overlay (Alt+Tab style) - hold modifier keys to browse presets with live preview, release to paste
- Tap vs Hold gesture for transform hotkey - quick tap does instant paste, holding shows preset overlay
- 18 new transforms inspired by Boop: UPPERCASE, lowercase, camelCase to snake_case, snake_case to camelCase, kebab-case, Reverse lines, Markdown quote, Count stats, Number lines, HTML encode/decode, Add/Remove slashes, MD5 hash, SHA256 hash, JSON to query string, Query string to JSON, ROT13
- Quick presets - mark presets for use in the transform overlay
- Custom icons for presets (16 SF Symbols to choose from)
- Drag to reorder presets
- Apply Preset button in Rules - adds all preset transforms to a rule in one click
- Auto-paste on return setting - toggle whether Return in panel pastes or just copies
- Move to top on use setting - used items move to the top of clipboard history
- Configurable transform timing: hold delay, paste delay, restore delay (ms inputs with steppers)
- Scrollable hotkey settings page for better layout

### Changed
- Transform list in playground is now scrollable
- Preset overlay shows floating hint pill with shortcut and instructions
- If no quick presets exist, overlay is skipped entirely (instant paste only)

## [1.4.0] - 2026-03-31

### Added
- Transform presets system with 5 built-in presets (Clean Terminal Output, Claude Code, Clean URL, Code Snippet, Plain Text Cleanup)
- Presets settings tab for managing transform presets
- Preset picker in Rules - assign a preset to a rule instead of adding transforms manually
- Smart join lines transform - joins soft-wrapped text while preserving code blocks, lists, tables, and headings
- Global hotkey for paste transformed text - applies transform rules and pastes the result while keeping original in clipboard
- Transform paste info banner in Rules settings when hotkey is enabled

### Changed
- Rules now support preset reference (preset transforms run before rule transforms)
- Hotkey system supports multiple independent global hotkeys via shared Carbon registry

## [1.3.2] - 2026-03-30

### Fixed
- Corner radius now works on all 4 corners when preview is open
- Panel padding works as inner content inset instead of moving the window
- Shadow no longer renders as border artifact

### Changed
- Renamed "Margin" to "Padding" in Look editor (inner content inset)

## [1.3.1] - 2026-03-30

### Fixed
- Removed unintended window transparency from NSVisualEffectView
- Cleaned up unused shadow customization settings

## [1.3.0] - 2026-03-30

### Added
- Panel shadow toggle in Look editor
- Panel border color and width settings in Look editor
- Meta text font, color, and background color settings in Look editor
- Detailed accessibility permission instructions (remove and re-add steps)

### Changed
- Accessibility banner text now explains remove & re-add process

## [1.2.2] - 2026-03-29

### Fixed
- Auto-update download failing with "file couldn't be opened" (temp file deleted before copy)
- Accessibility permissions alert showing before download instead of after install
- Release notes displayed as raw markdown in About tab

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
