# Domain docs

Loadout uses a single-context domain layout.

## Required reads before domain work

Before changing product behavior, terminology, architecture, or tests that encode domain rules, read:

1. `CONTEXT.md` — canonical domain language and resolved decisions.
2. `docs/adr/` — architectural decision records.

## Current layout

- `CONTEXT.md` at repo root: canonical terms like Service, Variant, Selection, Active set, Registry, Export, Reload, Import, and Order.
- `docs/adr/0001-keychain-direct-storage.md`: Keychain direct storage.
- `docs/adr/0002-swift-cli-core.md`: Swift CLI/core choice.
- `docs/adr/0003-terminals-only-scope.md`: terminals-only environment scope.
- `docs/adr/0004-non-sandboxed-distribution.md`: non-sandboxed distribution.

## Consumer rules

- Use the exact domain terms from `CONTEXT.md` in user-facing copy and issue text.
- Do not use banned legacy terms like EnvBar/envbar/envuse.
- Treat Export as lazy: read Selection, fetch only selected Service/Variant pairs, and print shell-eval-able lines.
- Treat Registry as metadata-only: enumerate Keychain item attributes, never secret values.
- If a change reverses an ADR or resolved decision, call that out explicitly and update the docs in the same PR.
