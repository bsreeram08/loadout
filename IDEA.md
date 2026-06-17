# Loadout — project idea

> A local-first macOS menu-bar app for managing and toggling
> per-service environment-variable profiles, feeding terminal sessions.
> (Name locked 2026-06-15; was "EnvBar".)

- **Status:** idea / not started
- **Created:** 2026-06-15
- **Owner:** Sreeram (bsreeram08@gmail.com)

---

## 1. Problem

Today all dev/test/prod secrets live in plaintext in `~/.zshrc` (~1300 lines,
~280 exported vars, `chmod 644`). This causes real pain:

- **Plaintext secrets in a dotfile** — payment/PCI key material (DUKPT BDKs, HSM
  ARNs, gateway secrets) sitting unencrypted, world-readable, copied across machines.
- **Last-write-wins shadowing** — the same var is exported many times (dev/beta/prod
  blocks commented in and out). Easy to ship the wrong value silently
  (e.g. `WORLDPAY_*` getting clobbered by empty strings, `PORT` 8080→8091).
- **No clean way to switch a single service's environment.** Switching "Worldline"
  to prod means hand-editing the dotfile and commenting/uncommenting blocks.
- **Manual, per-terminal, error-prone.** No persistent or global notion of
  "what env am I currently on."

## 2. Vision

A small menu-bar app where you open a dropdown, pick **"Worldline → prod"**
(while leaving Bambora on test), and every terminal you open afterwards has the
right variables — encrypted at rest, never written to disk in plaintext, free,
and entirely local.

## 3. Requirements

### Must-have
1. **Local & encrypted at rest** — secrets encrypted on-device, never plaintext.
2. **No plaintext file babysitting** — no `.env` files to manage / gitignore.
3. **Free** — no subscription, minimal third-party trust.
4. **Organized by service** — Worldline, Bambora, Swish, Klarna, NETS, Fiserv, etc.
5. **Multiple variants per service** — dev / beta / prod versions of each service's vars.
6. **Independent per-service toggling** — Worldline=prod while Bambora=test.
   (This is the key differentiator — no existing tool does this.)
7. **Loaded on demand** — not always live in every process.
8. **Global & persistent** — set once; all *newly opened* terminals reflect it.
9. **Auto-load at login** — selected defaults already in effect after login.
10. **Menu-bar / top-of-screen GUI** — open, click, toggle. Not CLI-driven.

### Nice-to-have
- Quick "current state" glance (which variant each service is on).
- Search/filter services.
- Import wizard from an existing `.zshrc` / `.env`.
- Per-service "diff" view (what changes between dev and prod).
- Touch ID gate to reveal/edit values.

## 4. Non-goals / known physical limits

- **Already-open terminals don't retro-change.** Env can't be injected into running
  processes; a toggle applies to terminals opened *after* it (or after a manual reload).
- **System-wide GUI-app env at login is not cleanly supported on modern macOS.**
  (`~/.MacOSX/environment.plist` is gone; `launchctl setenv` is fragile.) Scope is
  **terminals/shells**; GUI-app env is best-effort at most.
- Not a team secrets manager (no sharing, no cross-machine sync in v1).
- Not a cloud product.

## 5. Market scan — why build (build vs buy, 2026-06)

No off-the-shelf product hits the full combo. The two requirements nothing
satisfies are **independent per-service toggling** and a **menu-bar UI** — every
commercial tool treats an "environment" as one monolithic all-or-nothing profile.

| Tool | Local+enc | Free | Per-service variants | Independent toggle | New-terminal global | Menu-bar GUI |
|---|---|---|---|---|---|---|
| **envio** | ✅ | ✅ | ⚠️ profiles | ❌ one at a time | ❌ per-shell | ❌ CLI |
| **EnvKey** | ⚠️ E2E cloud-synced | ❌ paid | ✅ | ❌ | ⚠️ | ❌ full-window app |
| **Infisical** (self-host) | ⚠️ if self-hosted | ✅ | ✅ environments | ❌ | ⚠️ | ❌ web UI |
| **Doppler** | ❌ cloud | ❌ paid | ✅ | ❌ | ⚠️ | ❌ web UI |
| **Raycast + ShiftPlus** | ✅ | ✅ | ❌ | ❌ | ❌ | ⚠️ launcher |
| **Loadout (this idea)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Closest existing: **envio** (local/free/encrypted CLI, no GUI, single profile) and
**EnvKey** (GUI + shell loading, but paid/cloud/account, full-window not menu-bar).

## 6. Architecture (resolved 2026-06-17 — see `CONTEXT.md`)

| Layer | Tool | Job |
|---|---|---|
| Encrypted storage | **macOS Keychain** (Security framework) | One item per `loadout:<service>:<variant>` / account = var name |
| State | `~/.config/loadout/state.json` | Opt-in per-service selection + collision `order` |
| Brain | **`loadout` Swift CLI** | `export`, `select`, `import`, `set`, `order`, … |
| Shell wiring | `~/.zshrc` hook | `eval "$(loadout export)"` on new terminals |
| Menu-bar UI | **Deferred (M2)** | Native Swift `NSStatusItem` app when CLI friction proves annoying |

**Data flow:** `loadout select` / `import` → write `state.json` → new terminal's
`.zshrc` hook → `loadout export` → Keychain → active set in shell.

**Reload story:** `reloadenv` shell function re-runs export in an open terminal.

### Deferred (M2+)
- Native Swift menu-bar app over the same state file + Keychain.
- Touch-ID-gated secret editor (M3).
- Optional encrypted export for backup.

## 7. Resolved decisions (2026-06-17)

- [x] **Name:** Loadout (`~/.local/bin/loadout`, `~/.config/loadout/`).
- [x] **Storage:** Keychain direct — not envchain, not SOPS files (`docs/adr/0001-*`).
- [x] **Quoting:** `export KEY=$'...'` (zsh C-strings).
- [x] **Import:** `loadout import --from ~/.zshrc` — snapshot active blocks, confirm prod.
- [x] **GUI-app env:** Out of scope — terminals only (`docs/adr/0003-*`).
- [x] **v1:** M1 Swift CLI only; menu bar deferred (`docs/adr/0002-*`).

## 8. Prerequisite (independent of this project)

The secrets currently in `~/.zshrc` should be treated as **compromised** (plaintext,
644, copied across machines, paths into iCloud-synced `~/Documents`). **Rotate** before
importing into any manager — encrypting already-leaked keys buys nothing. Priority:
DUKPT BDKs + HSM/AWS-Payment-Cryptography keys → Slack webhooks → API tokens →
gateway secrets → the reused `sreeram123` Postgres password.

## 9. Related artifacts

- `~/.zshrc.cleaned` — deduped, secret-free zshrc draft (machine-global only).
- Original `~/.zshrc` audit (duplicate report, classification, extracted secrets by service)
  — produced 2026-06-15; re-runnable.

## 10. Decision (2026-06-15)

**Scope: personal tool only.** Not a product, not enterprise. Rationale: "local +
menu bar + no cloud" is the opposite of what enterprise secret management needs
(centralized server, RBAC, audit, rotation, SSO, compliance), and that market is
saturated (Vault, Doppler, Infisical, CyberArk, 1Password Business). The value is
"solves my own zshrc pain" — and that's enough.

**Build plan (effort ladder, do in order):**
- **M0 — Clean zshrc + rotate secrets.** Do first, regardless. `~/.zshrc.cleaned` drafted.
- **M1 — `loadout` Swift CLI + zshrc hook.** **In progress / implemented.** Keychain,
  opt-in selection, import, export, collision order. Hits 9/10 requirements headlessly.
- **M2 — Native menu-bar GUI.** Deferred until CLI friction is proven.
- **M3 — Editor + Touch ID.** Deferred.

Assume per-service switching is infrequent; M2 is polish, not core value.
