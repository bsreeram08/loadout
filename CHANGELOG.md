# Changelog

All notable changes to Loadout are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/). Versions use `MAJOR.MINOR.PATCH.MICRO`.

## [0.2.0.3] - 2026-06-19

### Added

- **GitHub Release assets** — each tag ships CLI tarball (`loadout-*-macos-*.tar.gz`) and menu bar app zip (`Loadout-*-macos-*.zip`) for arm64 and x86_64
- **Release workflow** — `.github/workflows/release.yml` builds, signs, notarizes (when secrets configured), and publishes both binaries
- **`scripts/package-release.sh`** — local release packaging; supports `SIGN_IDENTITY` + `NOTARIZE=1` for Developer ID builds

### Changed

- **Unified window chrome** — shared header, brand mark, and segmented navigation on every tab
- **Settings in main window** — General and Storage tabs live inside Loadout (no separate preferences window)
- CLI installer preserves Developer ID signatures from the app bundle instead of re-signing ad-hoc

### Fixed

- Menu bar stuck on **Loading…** when keychain scan was cancelled on each menu open
- Tab picker renders native segmented buttons instead of plain text labels
- Consistent empty-state layout across Services, Export, About, and Settings

## [0.2.0.2] - 2026-06-19

### Added

- **67-test suite** — CLI subprocess, Keychain integration, catalog dump, paths, state store, and name validator coverage
- **KeychainCatalog** — single keychain scan indexed for registry and per-variant lookups
- **Main window** — Services / Export / About tabs with Liquid Glass styling on macOS 26+
- **Compact menu bar** — only active services shown; full catalog via Manage services…

### Changed

- Menu bar dropdown no longer lists every stored service when inactive
- `install.sh` defaults to release builds and resolves arch-specific binary paths
- `build-app.sh` reads version from `VERSION` file

### Fixed

- Keychain writes use real `security add-generic-password -w` path (empty-password bug)
- Integration tests use dedicated temp keychain via `LOADOUT_KEYCHAIN_PATH`

## [0.2.0.1] - 2026-06-17

### Fixed

- Settings opens via `openWindow` instead of `openSettings` so LoadoutApp compiles on macOS 14 CI runners
- Deprecated `onChange` usages updated for macOS 14 SDK

## [0.2.0.0] - 2026-06-17

### Added

- **CLI** (`loadout`) — export, select, deselect, set, unset, import, migrate-keychain, order, status, list, and interactive select wizard
- **LoadoutCore** — dedicated Keychain partition, state persistence, zshrc import, collision-aware export engine
- **Menu bar app** — per-service variant submenus, launch-at-login, reload hint
- **Manage window** — CRUD for services, variants, and variables with confirmation dialogs
- **Settings window** — general, paths, export preview, and about tabs
- **B&W app and menu bar icons** — generated via `scripts/RenderIcons.swift`
- **27 unit tests** covering export ordering, import parsing, Keychain CRUD, and selection summary
- **Documentation** — README, CONTEXT, SPEC, ADRs, and implementation plans

### Changed

- Minimum deployment target set to macOS 14 for menu-bar settings integration

### Fixed

- Keychain store uses delete-then-add instead of `-U` to avoid hangs on the dedicated keychain
- App no longer quits when Manage or Settings windows are closed
- Menu bar icon and settings entry restored after window lifecycle fixes