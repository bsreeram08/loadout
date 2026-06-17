# Loadout

Local-first macOS tool for **per-service environment profiles**. Toggle each service's variant independently (e.g. Worldline → prod, Bambora → test), keep secrets encrypted in the macOS Keychain, and load the active set into new terminal sessions.

```
Worldline  prod  ▸  dev | ✓ prod
Bambora    test  ▸  ✓ test | prod
Swish      (off) ▸  prod | test
```

## Why

If your `~/.zshrc` is a wall of commented/uncommented `export` blocks across dev, beta, and prod, Loadout replaces hand-editing with a menu-bar picker and a dedicated Keychain — no plaintext secrets on disk.

## Features

- **Independent per-service selection** — mix prod and test across services
- **CLI + menu bar app** — `loadout` for scripts/CI; GUI for day-to-day toggling
- **Dedicated Keychain** (`~/Library/Keychains/loadout.keychain-db`) — survives rebuilds without ACL repair
- **Import wizard** — one-time migration from `~/.zshrc`
- **Manage UI** — CRUD for services, variants, and variables
- **Opt-in export** — nothing exports until you explicitly select a service

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

Adds `loadout` to `~/.local/bin`. Ensure that directory is on your `PATH`.

### Menu bar app

```bash
./scripts/build-app.sh
cp -R dist/Loadout.app /Applications/
open /Applications/Loadout.app
```

The app bundles the CLI and installs it to `~/.local/bin` on first launch if missing.

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

Click the menu-bar icon to toggle variants, open **Manage…** for CRUD, or **Settings…** for paths, collision order, and export preview.

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
swift test                    # 27 unit tests
swift build                   # CLI only
./scripts/build-app.sh        # Loadout.app → dist/
BUILD_CONFIG=debug ./scripts/install.sh
```

## Architecture

- **LoadoutCore** — Keychain, state, export engine, import parser
- **loadout** — CLI ([swift-argument-parser](https://github.com/apple/swift-argument-parser))
- **LoadoutApp** — SwiftUI menu-bar app (MenuBarExtra + Manage/Settings windows)

See [CONTEXT.md](CONTEXT.md) for domain language, [SPEC-macos.md](SPEC-macos.md) for the full spec, and [docs/adr/](docs/adr/) for architecture decisions.

## Roadmap

| Milestone | Status |
|-----------|--------|
| M1 — CLI core | Done |
| M2 — Menu bar app | Done |
| M3 — Touch-ID editor + import GUI | Planned |
| M4 — Collision UI polish, prod cues | Planned |

## License

MIT — see [LICENSE](LICENSE).