# Loadout

A local-first macOS tool for managing per-service environment-variable
profiles. Each **Service** can independently select a **Variant**; the
resulting **Active set** is exported to newly opened terminal sessions.
Secrets are encrypted at rest in the macOS Keychain.

## Language

**Service**:
A named group of related environment variables, e.g. `worldline`, `bambora`, `swish`.
_Avoid_: Profile, environment, namespace (in user-facing copy)

**Variant**:
A version of a service's variables, e.g. `dev`, `beta`, `prod`, `test`.
_Avoid_: Environment, profile, mode

**Selection**:
The current variant chosen per service, persisted in `state.json`.
Example: `{worldline: prod, bambora: test}`.
_Avoid_: Active profile, current env

**Active set**:
The flattened `KEY=value` map produced by applying the current selection
across all services.
_Avoid_: Export, dump, env block

**Default**:
A variant name only (e.g. a variant literally called `default`) — not a
fallback mechanism. With opt-in **Selection**, unlisted services contribute
nothing to the **Active set**.
_Avoid_: Fallback, implicit, unset (as a pseudo-variant)

**Export**:
The CLI operation that reads **Selection**, fetches only the selected
service/variant pairs from Keychain (no full enumeration), merges per
**Order**, and prints shell-eval-able `export` lines. Always reads Keychain
fresh — no on-disk cache of secret values.
_Avoid_: Dump, printenv

**Reload**:
Re-running **Export** inside an already-open terminal via the `reloadenv`
shell function. Does not affect other running processes.
_Avoid_: Refresh, sync

**Registry**:
The set of known services and variants, derived by enumerating Keychain items
with service attr prefix `loadout:`. No separate plaintext index file.
_Avoid_: Catalog, manifest

**Order**:
Service precedence list in `state.json`. When two selected services define the
same var, the earlier service in **Order** wins; shadowed values are warned on
stderr. Default: alphabetical by service name.
_Avoid_: Priority, rank

**Import**:
One-time migration from `~/.zshrc` or `.env` into Keychain. Seeds initial
**Selection** from whichever variant blocks are currently active (uncommented
exports) in the source file. Requires explicit confirmation before seeding any
`prod` variant.
_Avoid_: Sync, backup

**Loadout**:
The project and CLI binary name. Replaces earlier working names (`EnvBar`, `envbar`, `envuse`).
_Avoid_: EnvBar, envbar, envuse (legacy references in `IDEA.md` §6)

## Relationships

- A **Service** has one or more **Variants**, discoverable via the **Registry**
- A **Selection** maps only explicitly listed **Services** to a **Variant**; omitted services contribute nothing (opt-in)
- The **Active set** is derived from **Selection** + Keychain secrets for each selected service/variant pair
- Cross-service var collisions resolve by **Order** (first wins); stderr warns on shadowed vars
- **Export** produces the **Active set**; **Reload** re-applies it in the current shell
- **Import** populates Keychain and seeds **Selection** from the source file's active blocks

## Example dialogue

> **Dev:** "If Worldline is on `prod` and Bambora on `test`, what's in the shell?"
> **Domain expert:** "The **Active set** — all vars from Worldline's `prod` **Variant** plus all vars from Bambora's `test` **Variant**, merged per **Order**."

> **Dev:** "User hasn't picked a variant for Klarna yet — what exports?"
> **Domain expert:** "Nothing from Klarna. **Selection** is opt-in; until Klarna is explicitly set to a **Variant**, it doesn't appear in the **Active set** — even if a variant happens to be named `default`."

> **Dev:** "Worldline is selected as `prod` but someone deleted those Keychain items. What happens?"
> **Domain expert:** "**Export** skips Worldline, warns on stderr, and still exports everything else. No silent fallback to another **Variant**."

## Resolved decisions

| Topic | Decision |
|---|---|
| Name / paths | **Loadout**; `~/.config/loadout/state.json`; CLI at `~/.local/bin/loadout` |
| v1 scope | **M1 CLI only** — Swift `loadout` + `.zshrc` hook. Menu bar (M2), editor/Touch ID (M3) deferred |
| Secret storage | **Keychain direct** — `loadout:<service>:<variant>` / account = var name ([ADR 0001](docs/adr/0001-keychain-direct-storage.md)) |
| CLI language | **Swift** — shared with future app ([ADR 0002](docs/adr/0002-swift-cli-core.md)) |
| Selection model | **Opt-in** — unlisted services export nothing |
| Import selection | **Snapshot** active `.zshrc` blocks; **confirm** before seeding `prod` |
| Var collisions | **First wins** per **Order**; alphabetical default; stderr warning |
| Export perf | **Always fresh** Keychain reads; **lazy** — only selected service/variant pairs |
| Export quoting | zsh-safe `export KEY=$'...'` lines |
| Missing variant | **Skip service + stderr warning** |
| Login persistence | M1: `.zshrc` hook on new terminals. M2: `SMAppService` login item (deferred) |
| GUI-app env | **Out of scope** — terminals only ([ADR 0003](docs/adr/0003-terminals-only-scope.md)) |
| Distribution | **Non-sandboxed**, not App Store ([ADR 0004](docs/adr/0004-non-sandboxed-distribution.md)) |
| M0 prerequisite | Rotate compromised secrets **before** import |
| M2 trigger | Build only if M1 CLI toggle friction is proven — assume switching is infrequent |

## Doc drift (IDEA.md / SPEC-macos.md)

These source docs predate grilling and should be aligned before implementation:

- `IDEA.md` §6 envchain/SwiftBar/`envbar` paths → superseded by Keychain-direct Swift CLI
- `IDEA.md` §7 open name question → **Loadout** (locked)
- `SPEC-macos.md` §6 Klarna `✓ default` menu → revise for opt-in selection at M2
- `SPEC-macos.md` §14 open questions → largely resolved in table above