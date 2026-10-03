# Changelog entry template

New version goes at the top of `CHANGELOG.md`, right after the `# Changelog` title.
Release notes on GitHub mirror the same section.

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New user-visible feature

### Changed
- Change in existing behavior

### Fixed
- Bug fix

### Removed
- Removed feature
```

Rules:
- English only, hyphen `-` only (no em or en dashes).
- Keep only the sections that apply, in the order Added, Changed, Fixed, Removed.
- One line per change, imperative or past tense, written for users first.
- Version matches `CFBundleShortVersionString` in `ClipMoar/Resources/Info.plist`.
- Date is the release day.
- State facts only. Do not claim notarization unless the release zip was notarized by Apple (`xcrun stapler validate` passes).
