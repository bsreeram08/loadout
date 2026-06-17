# Changelog

All notable changes to Loadout are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/). Versions use `MAJOR.MINOR.PATCH.MICRO`.

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