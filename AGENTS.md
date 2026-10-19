# valheim-lembitu

Modded Valheim server for a private group: server configuration, custom BepInEx plugins, and
1.0-native forks of third-party mods.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `rakoort/valheim-lembitu`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` plus `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Branches

- **`dev`** is the integration branch and the GitHub default. Branch from `dev`, open the PR against `dev`, and merge it yourself once reviewed: `gh pr merge <n> --merge`.
- **`staging` and `master`** take only promotion PRs, `dev → staging` then `staging → master`. Open the promotion PR, then wait for ra's explicit go in this session; merge only after it.
- **Merge commits only.** Squash and rebase merges are off, and so is auto-delete of head branches (it would delete `staging` when a `staging → master` PR merges). Merge commits keep the three branches on one history, so promotions need no sync PRs.
- **Break-glass** belongs to ra alone: a commit straight to `master` to store or rotate a Secret value, or to fix an outage that stops every team. `master` is then merged back into `dev` at once through a reviewed PR.
- **`master` is the live server's branch.** astral-bicep's checkout at `~/code/valheim-lembitu` tracks `origin/master`; a deploy fast-forwards it, and the hourly backup's drift check and the maintenance restart read it (`docs/wiki/operations.md`). It keeps the name `master` until that checkout is repointed.
