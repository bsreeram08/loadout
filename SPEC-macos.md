# Loadout — macOS app spec

> Name: **Loadout** (locked 2026-06-15; earlier candidates: Switchboard,
> Quartermaster, Vane). A local-first macOS menu-bar app for managing and
> toggling per-service environment-variable profiles, feeding terminal sessions.

- **Status:** spec / build later
- **Created:** 2026-06-15
- **Scope decision:** personal tool, not a product (see `IDEA.md` §10)
- **Companion docs:** `IDEA.md` (problem, market scan, decision), `~/.zshrc.cleaned`

---

## 1. Purpose

Replace hand-editing `~/.zshrc` (commenting prod/dev blocks in and out) with a
menu-bar control that toggles each service's environment variant independently,
keeps secrets encrypted in the macOS Keychain, and makes the selected set
available to every newly opened terminal.

## 2. Goals / non-goals

**Goals**
- Encrypted-at-rest secrets, local only (macOS Keychain). No cloud, no account.
- Organize vars **by service** (Worldline, Bambora, Swish, …), each with multiple
  **variants** (dev / beta / prod / …).
- **Independent per-service toggling** (Worldline=prod while Bambora=test).
- Menu-bar GUI to view current selection and switch variants.
- Selection is **global + persistent**: applies to all newly opened terminals.
- Auto-load selected defaults at login.
- One-time **import** from existing `~/.zshrc` / `.env`.

**Non-goals**
- Not a team/enterprise secrets manager (no RBAC, audit, rotation policy, SSO).
- No cloud sync, no account, no server.
- Not a general credential manager (use 1Password/Keychain for passwords).

## 3. Target user

One developer (the author) on one Mac, terminal-native, juggling many
payment-service env profiles across dev/beta/prod. Values local-only and zero
plaintext on disk.

## 4. Vocabulary

| Term | Meaning |
|---|---|
| **Service** | A named group of related vars, e.g. `worldline`, `bambora`, `swish`. |
| **Variant** | A version of a service's vars, e.g. `dev`, `beta`, `prod`. |
| **Selection** | The current variant chosen per service: `{worldline: prod, bambora: test}`. |
| **Active set** | The flattened `KEY=value` map produced by the current selection. |
| **Default** | A variant *name* only — not a fallback. Selection is opt-in (see `CONTEXT.md`). |

## 5. Functional requirements

| # | Requirement | Notes |
|---|---|---|
| F1 | Store secrets encrypted in macOS Keychain | One Keychain item per `service/variant/VAR`. |
| F2 | CRUD services, variants, and vars | Via GUI; bulk via import. |
| F3 | Per-service variant selection, independent | Selection persisted to a state file. |
| F4 | Produce the active set on demand | `loadout export` emits shell-eval-able output. |
| F5 | New terminals load the active set automatically | `.zshrc` hook calls `loadout export`. |
| F6 | Persist selection across reboots | State file + Keychain survive restart. |
| F7 | Launch app at login | `SMAppService`. |
| F8 | Reload active set in an open terminal | `reloadenv` shell function / `loadout reload`. |
| F9 | Import from `~/.zshrc` / `.env` | Heuristic service grouping, manual confirm. |
| F10 | Reveal/edit a secret value requires Touch ID | LocalAuthentication gate in GUI only. |

## 6. UX / menu-bar spec

Menu-bar icon (e.g. a toggle/slider glyph). Click opens:

```
Loadout
────────────────────────────
Worldline      prod  ▸   dev | beta | ✓ prod
Bambora        test  ▸   ✓ test | prod
Swish          prod  ▸   ✓ prod | test
Klarna         —     ▸   (not selected — opt-in)
────────────────────────────
Active vars: 187 across 9 services
Reload open terminals…        ⌥⌘R
Import from .zshrc…
Edit secrets…   (Touch ID)
Launch at login            ✓
Quit
```

- Each service is a row showing its **current variant**; submenu lists variants,
  current one checked. Selecting a variant updates state immediately.
- Header/footer shows a quick summary (count of vars, services on non-default).
- "Reload open terminals" triggers F8 guidance (can't force-inject; see §10).
- "Edit secrets" opens an editor window (Touch-ID gated) for CRUD (F2).
- Visual cue when any service is on `prod` (e.g. red dot) to avoid accidents.

States: empty (no services yet → prompt to import), normal, error (Keychain
locked → prompt to unlock).

## 7. Architecture

```
┌── Loadout.app (SwiftUI menu bar) ──┐      ┌── loadout CLI (bundled helper) ──┐
│  NSStatusItem + NSMenu             │      │  loadout export   (emits exports) │
│  Editor window (CRUD, Touch ID)    │      │  loadout reload   (hint/no-op)    │
│  SMAppService login item           │      │  loadout import   (one-time)      │
└───────────────┬────────────────────┘      └───────────────┬───────────────────┘
                │ writes                                      │ reads
        ~/.config/loadout/state.json  ◄──────────────────────┘
                │                                              │ reads
        macOS Keychain (Security framework) ◄──────────────────┘
                ▲
   new terminal → .zshrc hook → `eval "$(loadout export)"` → active set in shell
```

- **App**: Swift 5.9+, SwiftUI. Menu bar via `NSStatusItem` + `NSMenu` (chosen over
  `MenuBarExtra` for dynamic nested submenus per service). Login item via
  `SMAppService.mainApp` (macOS 13+).
- **Storage**: Keychain directly via Security framework (`kSecClassGenericPassword`).
  Item key = `service` (the Keychain service attr) `loadout:<service>:<variant>`,
  account = `VAR_NAME`, value = the secret. Accessibility
  `kSecAttrAccessibleWhenUnlocked` (no per-read biometry → no Touch-ID prompt on
  every new terminal; login-keychain being unlocked is enough). Touch ID is
  applied only to the GUI reveal/edit path (F10) via a separate flow.
- **State file**: `~/.config/loadout/state.json` — selection only, no secrets.
  Plain JSON so the shell helper reads it trivially.
- **CLI helper** `loadout`: bundled in the app, symlinked to `/usr/local/bin` (or
  `~/.local/bin`) on first run. `loadout export` reads state + Keychain → prints
  `export KEY=$'...'` lines with correct quoting (use C-style `$'...'` or `printf %q`).

## 8. Shell integration

`.zshrc` hook (added once, idempotent):

```zsh
# Loadout — load active env profile
command -v loadout >/dev/null 2>&1 && eval "$(loadout export 2>/dev/null)"
```

- Every new terminal runs this → gets the current active set.
- `reloadenv` function re-runs it in an already-open terminal.
- Collisions: if two selected services define the same VAR, precedence is
  user-orderable (default: alphabetical by service); `loadout export` warns on
  stderr. Document and surface collisions in the editor UI.

## 9. Data model

`state.json`:
```json
{
  "version": 1,
  "selection": { "worldline": "prod", "bambora": "test" },
  "order": ["worldline", "bambora", "swish"],
  "updatedAt": "2026-06-15T00:00:00Z"
}
```

Service/variant registry is derived from Keychain items (enumerate by
`loadout:*` service prefix) so there's a single source of truth and no second
plaintext index.

## 10. Known limits (must be in the UI copy)

- **Already-open terminals don't retro-change.** Toggling updates new terminals;
  open ones need `reloadenv`. Env can't be pushed into running processes.
- **GUI apps at login: not cleanly supported on modern macOS.** Best-effort
  `launchctl setenv` per active var is possible but fragile; out of scope for v1.
  Scope is terminals/shells.
- **`AccessibleWhenUnlocked` means any process running as you can read the
  secrets** (same threat model as envchain/most local secret tools). Acceptable
  for a local dev tool; documented, not hidden.

## 11. Import (one-time)

`loadout import --from ~/.zshrc`:
1. Parse `export VAR=value` lines (handle `export const` typo, stray-token
   malformations, quoting).
2. Heuristic-group by comment headers / prefix (e.g. `WORLDPAY_*`, `SWISH_*`).
3. Detect commented prod/dev/beta blocks → propose as variants.
4. Show a confirm screen; user assigns ambiguous vars to services/variants.
5. Write to Keychain. Never echo secrets to stdout/history.

## 12. Security prerequisites

- **Rotate first.** Secrets currently in `~/.zshrc` are compromised (plaintext,
  644, copied across machines, paths into iCloud-synced `~/Documents`). Encrypting
  already-leaked keys buys nothing. Priority: DUKPT BDKs + HSM/AWS-Payment-Crypto
  keys → Slack webhooks → API tokens → gateway secrets → reused Postgres password.
- App stores nothing in plaintext on disk; secrets only in Keychain.

## 13. Milestones (build later)

- **M0 — Cleanup (prereq, not the app):** apply `~/.zshrc.cleaned`, rotate secrets.
- **M1 — CLI core:** `loadout` helper (Keychain CRUD, `export`, state.json) + zshrc
  hook. This alone delivers 9/10 requirements headlessly.
- **M2 — Menu bar app:** NSStatusItem UI, per-service submenus, login item.
- **M3 — Editor + import:** Touch-ID-gated CRUD window, `.zshrc` import wizard.
- **M4 — Polish:** prod-warning cues, collision UI, reload UX.

> The CLI core (M1) is the engine; the app (M2+) is a front-end over the same
> state file + Keychain. Build M1 first; M2 is purely additive.

## 14. Resolved decisions (2026-06-17 — canonical: `CONTEXT.md`)

- [x] **Name:** Loadout.
- [x] **CLI install:** `~/.local/bin/loadout` via `scripts/install.sh`; M2 app symlinks on first launch.
- [x] **App Sandbox:** Non-sandboxed, not App Store (`docs/adr/0004-*`).
- [x] **Collision precedence:** `loadout order` + first-wins; stderr warning on export.
- [x] **Export caching:** Always fresh Keychain reads; lazy to selected pairs only.
- [x] **M2 trigger:** Build menu bar only if CLI toggle friction is proven; switching assumed infrequent.

## 15. Out of scope

Enterprise/team features, cloud sync, audit logs, rotation automation, non-macOS
platforms, GUI-app env injection, secret sharing.
