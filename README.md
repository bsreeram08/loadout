# Loadout

Local-first macOS tool for **per-service environment profiles**. Toggle each service's variant independently (e.g. Worldline → prod, Bambora → test), keep secrets encrypted in the macOS Keychain, and load the active set into new terminal sessions.

**Current version:** `0.2.0.2`

```
Menu bar (compact)          Main window (full catalog)
─────────────────          ──────────────────────────
Loadout                    Services | Export | About
Manage services…           [sidebar: all services]
Settings…                  [detail: variants, variables]
─────────────
aws  prod                  Toggle, edit, add, delete
─────────────
52 services stored, 1 active
```

## Why

If your `~/.zshrc` is a wall of commented/uncommented `export` blocks across dev, beta, and prod, Loadout replaces hand-editing with a menu-bar picker and a dedicated Keychain — no plaintext secrets on disk.

## Features

- **Independent per-service selection** — mix prod and test across services
- **CLI + menu bar app** — `loadout` for scripts/CI; GUI for day-to-day toggling
- **Compact menu bar** — only active services in the dropdown; full list in the main window
- **Main window** — Services, Export preview, and About tabs (Liquid Glass on macOS 26+)
- **Dedicated Keychain** (`~/Library/Keychains/loadout.keychain-db`) — survives rebuilds without ACL repair
- **Import wizard** — one-time migration from `~/.zshrc`
- **Manage UI** — CRUD for services, variants, and variables
- **Opt-in export** — nothing exports until you explicitly select a service
- **67 tests** — unit, integration, and CLI subprocess coverage against real temp keychains

## Requirements

- macOS 14+
- Xcode Command Line Tools / Swift 5.9+
- zsh (for the shell hook)

## Install

### CLI

```bash
git clone https://github.com/bsreeram08/loadout.git
cd loadout
./scripts/install.sh
```

Adds `loadout` to `~/.local/bin` (release build by default). Ensure that directory is on your `PATH`.

### Menu bar app

```bash
./scripts/build-app.sh
cp -R dist/Loadout.app /Applications/
open /Applications/Loadout.app
```

The app bundles the CLI and installs it to `~/.local/bin` on first launch if missing or older.

### Shell hook

Add once to `~/.zshrc` (see `scripts/zshrc-hook.snippet`):

```zsh
if command -v loadout >/dev/null 2>&1; then
  eval "$(loadout export 2>/dev/null)"
  reloadenv() { eval "$(loadout export 2>/dev/null)"; }
fi
```

New terminals pick up the current selection. Already-open terminals need `reloadenv`.

## Quick start

```bash
# Import from existing .zshrc (interactive)
loadout import --from ~/.zshrc

# Or set variables manually
loadout set worldline prod API_KEY "secret"

# Select what exports (opt-in)
loadout select worldline prod
loadout select bambora test

# See what would export
loadout export

# Check state
loadout status
```

### Menu bar app

Click the menu-bar icon for a short status menu:

- **Manage services…** — open the main window (full service list, CRUD)
- **Settings…** — general preferences and storage paths
- **Active services only** — quick variant toggle for what's exporting
- Summary line when nothing is active, e.g. `52 services stored, none active`

Use **Manage services…** to turn services on/off when you have many stored profiles.

## CLI reference

| Command | Description |
|---------|-------------|
| `loadout export` | Emit `export` lines for the current selection |
| `loadout select [service] [variant]` | Select a variant (interactive with no args) |
| `loadout deselect <service>` | Remove a service from the active selection |
| `loadout set <svc> <var> <name> <value>` | Store a secret in Keychain |
| `loadout unset <svc> <var> <name>` | Delete one variable |
| `loadout unset <svc> <var> --all-vars` | Delete a variant |
| `loadout unset <svc> --all` | Delete an entire service |
| `loadout import --from <file>` | Import from `.zshrc` / `.env` |
| `loadout migrate-keychain` | Move secrets to dedicated keychain (one-time) |
| `loadout order <svc>…` | Set collision precedence |
| `loadout status` | Show selection and registry |
| `loadout list` | List services/variants in Keychain |
| `loadout reload` | Hint for refreshing open terminals |

## Storage

| Path | Purpose |
|------|---------|
| `~/.config/loadout/state.json` | Selection and collision order |
| `~/Library/Keychains/loadout.keychain-db` | Encrypted secrets |
| `~/.local/bin/loadout` | CLI binary |

## Development

```bash
swift test                    # 67 tests (unit + integration + CLI)
swift build                   # CLI only
./scripts/build-app.sh        # Loadout.app → dist/
BUILD_CONFIG=debug ./scripts/install.sh
```

Integration tests use a dedicated temp keychain via `LOADOUT_KEYCHAIN_PATH`. CI builds the CLI first so subprocess tests can exercise the real binary.

## Architecture

- **LoadoutCore** — Keychain, KeychainCatalog, state, export engine, import parser
- **loadout** — CLI ([swift-argument-parser](https://github.com/apple/swift-argument-parser))
- **LoadoutApp** — SwiftUI menu-bar app (MenuBarExtra + main window + Settings)

See [CONTEXT.md](CONTEXT.md) for domain language, [SPEC-macos.md](SPEC-macos.md) for the full spec, and [docs/adr/](docs/adr/) for architecture decisions.

## Roadmap

| Milestone | Status |
|-----------|--------|
| M1 — CLI core | Done |
| M2 — Menu bar app | Done |
| M2.1 — Compact menu + main window | Done (v0.2.0.2) |
| M3 — Touch-ID editor + import GUI | Planned |
| M4 — Collision UI polish, prod cues | Planned |

## License

MIT — see [LICENSE](LICENSE).