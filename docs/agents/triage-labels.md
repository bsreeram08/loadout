# Triage labels

Use the default five-label vocabulary for issue triage.

| Triage role | GitHub label |
|---|---|
| Maintainer needs to evaluate | `needs-triage` |
| Waiting on reporter | `needs-info` |
| Fully specified, AFK-agent-ready | `ready-for-agent` |
| Needs human implementation | `ready-for-human` |
| Will not be actioned | `wontfix` |

If a label is missing, create it before applying it rather than inventing a near-duplicate.

Recommended command shape:

```bash
gh label create needs-triage --repo bsreeram08/loadout --description "Maintainer needs to evaluate" || true
```

Keep these strings stable so `triage`, `to-issues`, `to-prd`, and `qa` can move issues through the same state machine.
