# Plan: M2 — Menu Bar App

> Source: `SPEC-macos.md` §6–7, `CONTEXT.md`, ADRs 0002/0004. M1 CLI + `LoadoutCore` is complete.

## Goal

Deliver the **menu-bar control** from the spec: click the icon, see each **Service**, pick a **Variant** from a submenu, persist **Selection** to `state.json`. New terminals pick it up via the existing `.zshrc` hook — no new shell magic in M2.

M2 is a **front-end over the same engine** as M1. It does not reimplement Keychain, export, or import.

## Out of scope for M2 (later milestones)

| Item | Milestone | Notes |
|---|---|---|
| Touch-ID secret editor (F10) | **M3** | CLI `set` + `import` suffice until then |
| Import wizard GUI | **M3** | Menu item can stub → “use `loadout import`” |
| Collision reorder UI | **M4** | `loadout order` works headlessly |
| Prod red-dot / accident cues | **M4** | Nice polish, not blocking toggle UX |
| Force-inject into open terminals | **Never** | `reloadenv` hint only (F8) |

## Architectural decisions

- **UI toolkit**: `NSStatusItem` + `NSMenu` with nested submenus per service — **not** `MenuBarExtra` (SPEC §7: dynamic nested menus).
- **App style**: Agent app (`LSUIElement = true`) — menu bar only, no Dock icon, no main window in M2.
- **Shared core**: `LoadoutCore` for `StateStore`, `KeychainStore.registry()`, `select` / `deselect`. App target links the library; zero duplicated domain logic.
- **Storage paths**: Unchanged — `~/.config/loadout/state.json`, dedicated Keychain `loadout.keychain-db`.
- **Distribution**: Non-sandboxed, direct install / `brew install --cask` (ADR 0004). Ad-hoc or Developer ID sign.
- **CLI packaging**: Bundle `loadout` inside `Loadout.app/Contents/MacOS/` (or `Resources/`). On first launch, copy/symlink to `~/.local/bin/loadout` if missing or older — same contract as `scripts/install.sh`.
- **Selection model**: Opt-in unchanged. Services with no selected variant show as “off” in the menu; picking a variant calls `StateStore.select`; “Turn off” calls `deselect`.
- **Keychain reads in menu**: Metadata only (`registry()`) — no secret values in the menu. No Touch ID on toggle.
- **Project layout**: Add `LoadoutApp` macOS app target (Xcode project recommended for Info.plist, icon, SMAppService). Keep `LoadoutCore` + `loadout` CLI in the existing Swift package; app links the package.

## Menu structure (M2 target)

```
Loadout
────────────────────────────
Worldline      prod  ▸   dev | ✓ prod
Bambora        test  ▸   ✓ test | prod
Swish          (off) ▸   prod | test
────────────────────────────
3 services selected · 4 vars
Reload hint…              (opens nothing — copies hint / shows alert)
Launch at login        ✓
Quit
```

- Checkmark (`✓`) on the active **Variant** per service.
- Submenu item “Turn off” when service is selected (maps to `deselect`).
- Footer: selected service count + approximate var count from registry metadata (not live export).
- **Empty registry**: single item “Import secrets…” → alert with `loadout import --from ~/.zshrc` (M3 replaces with wizard).

## Phases (tracer bullets)

---

## Phase 1: App shell + empty menu

**User stories**: F3 (view selection), F6 (persist), menu-bar presence.

### What to build

Minimal `Loadout.app`: status item (SF Symbol e.g. `slider.horizontal.3`), click opens `NSMenu` with title, “Quit”, and `NSApplication` lifecycle. Loads `state.json` + `registry()` on open; shows “No services yet” when registry empty. No variant toggling yet.

### Acceptance criteria

- [ ] App launches, appears in menu bar only (no Dock).
- [ ] `loadout status` and app show the same selection after manual CLI change.
- [ ] Quit terminates cleanly.
- [ ] `swift test` / existing CLI unaffected.

---

## Phase 2: Per-service variant submenus

**User stories**: F3 (independent per-service toggling), F6.

### What to build

Build menu dynamically from `registry()`: one top-level row per **Service**, submenu lists **Variants** from Keychain metadata. Selecting a variant → `StateStore.select` → menu rebuilds with checkmark. “Turn off” → `deselect`. Changes visible to `loadout export` / new terminals without app restart.

### Acceptance criteria

- [ ] Toggle `worldline` prod ↔ dev from menu; `loadout status` matches.
- [ ] Opt-in: deselected service exports nothing (`loadout export` skips it).
- [ ] Menu reflects CLI `loadout select` changes on next open (or via lightweight refresh on open).
- [ ] Invalid state (variant deleted from Keychain) shows graceful row, no crash.

---

## Phase 3: Bundle CLI + install helper

**User stories**: F4, F5 (hook continues to call bundled binary).

### What to build

Embed release `loadout` in the app bundle. First-launch (or “Install CLI…” menu action) copies to `~/.local/bin/loadout`, ad-hoc signs, ensures PATH hint if needed. Version stamp so reinstall only when app bundle is newer.

### Acceptance criteria

- [ ] Fresh Mac: open app → CLI available at `~/.local/bin/loadout`.
- [ ] `loadout export` uses same Keychain + state as app.
- [ ] `scripts/install.sh` still works for devs who only want CLI.

---

## Phase 4: Launch at login

**User stories**: F7.

### What to build

`SMAppService.mainApp` toggle in menu (“Launch at login”). Persist preference; register/unregister on toggle. No login-item if user disables.

### Acceptance criteria

- [ ] Toggle on → app relaunches after logout/login (or reboot).
- [ ] Toggle off → removes login item.
- [ ] Works non-sandboxed with correct entitlement (`com.apple.security.app-sandbox` absent; use ServiceManagement API).

---

## Phase 5: Footer, states, and reload hint

**User stories**: F8 (guidance only), spec §6 summary line.

### What to build

Footer shows `N services selected · M vars` (M = sum of `variableCounts` for selected pairs). “Reload open terminals…” menu item shows alert: run `reloadenv` in each open terminal (link to `loadout reload` text). Keychain/IO errors → menu shows “Unlock Keychain” / error row instead of empty crash.

### Acceptance criteria

- [ ] Footer counts match `loadout status` + registry for current selection.
- [ ] Reload item does not claim to update other terminals automatically.
- [ ] With Keychain unreachable, menu shows error state (not blank).

---

## Phase 6 (optional M2.5): Prod cue

**User stories**: Spec §6 accident avoidance.

### What to build

Status item shows a small indicator (e.g. orange/red dot) when any selected variant name is `prod`. Defer if timeboxed — fits M4 equally.

### Acceptance criteria

- [ ] `bambora → prod` selected → indicator visible.
- [ ] All non-prod → no indicator.

---

## Verification matrix (end of M2)

| Check | How |
|---|---|
| Toggle from menu | Menu → variant → new terminal → `echo $VAR` |
| Toggle from CLI | `loadout select` → menu shows checkmark on reopen |
| Persistence | Reboot → selection retained |
| Login item | Reboot → app in menu bar |
| CLI coexistence | `loadout export` identical whether installed via app or `install.sh` |

## Open choices (decide before Phase 1)

1. **Xcode project vs pure SPM** — Recommendation: **Xcode app target** wrapping the Swift package (icons, SMAppService, signing). CLI/package stays SPM.
2. **Menu refresh** — Rebuild menu on every open vs observe `state.json` — Recommendation: rebuild on open (simple); FSEvents optional later.
3. **Icon** — SF Symbol `slider.horizontal.3` or `switch.2` for v1; custom asset later.
4. **M2.5 prod dot** — In M2 or slip to M4?

## Effort estimate

| Phase | Rough size |
|---|---|
| 1 Shell | 0.5–1 day |
| 2 Submenus | 1–2 days |
| 3 CLI bundle | 0.5–1 day |
| 4 Login item | 0.5 day |
| 5 Footer/errors | 0.5 day |
| 6 Prod cue (opt) | 0.25 day |

**Total M2**: ~3–5 days focused work for a personal dogfood build.

## After M2

**M3**: Touch-ID editor window + GUI import. **M4**: collision drag-reorder, richer prod warnings, export preview in app.