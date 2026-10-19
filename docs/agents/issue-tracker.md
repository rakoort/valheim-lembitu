# Issue tracker: GitHub

Issues and specs live in the [rakoort/valheim-lembitu tracker](https://github.com/rakoort/valheim-lembitu/issues).
Use the gh CLI with an explicit repository selector; do not assume a remote name.

- Create: `gh issue create --repo rakoort/valheim-lembitu --title "..." --body "..."`.
- Read: `gh issue view NUMBER --repo rakoort/valheim-lembitu --comments`.
- List: `gh issue list --repo rakoort/valheim-lembitu --state open`.
- Label: `gh issue edit NUMBER --repo rakoort/valheim-lembitu --add-label LABEL`.
- Comment: `gh issue comment NUMBER --repo rakoort/valheim-lembitu --body-file FILE`. Redact secrets first.

The repository check is Git config field `check.command` in `docs/agents/check.conf`. The
pre-commit hook reads it with `git config --file docs/agents/check.conf --get check.command` and
runs that string with `sh -c`. Missing or blank commands refuse the commit.

Use the [canonical labels](triage-labels.md) and keep durable knowledge in the
[repository wiki](../wiki/index.md). Check gh auth status before tracker writes.
