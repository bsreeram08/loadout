# Issue tracker

This repo tracks work in GitHub Issues for `bsreeram08/loadout`.

## Tooling

- Use the `gh` CLI for issue operations.
- Repository: `https://github.com/bsreeram08/loadout`
- Default base branch: `main`

## Create issues

Use GitHub Issues for bugs, implementation tickets, triage output, PRD follow-up, and AFK-agent work packets.

Recommended command shape:

```bash
gh issue create --repo bsreeram08/loadout --title "<title>" --body-file <body.md> --label <label>
```

Prefer `--body-file` for multi-line Markdown so shell backticks and code blocks are not interpreted.

## Read issues

Use:

```bash
gh issue list --repo bsreeram08/loadout --state all
gh issue view <number> --repo bsreeram08/loadout
```

## Local notes

Do not use `.scratch/` as the source of truth for tracked work in this repo unless the user explicitly asks for a local-only draft.
