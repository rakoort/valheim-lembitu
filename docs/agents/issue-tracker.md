# Issue tracker: GitHub

Issues and specs live in the [rakoort/valheim-lembitu tracker](https://github.com/rakoort/valheim-lembitu/issues).
Use the gh CLI with an explicit repository selector; do not assume a remote name.

- Create: `gh issue create --repo rakoort/valheim-lembitu --title "..." --body "..."`.
- Read: `gh issue view NUMBER --repo rakoort/valheim-lembitu --comments`.
- List: `gh issue list --repo rakoort/valheim-lembitu --state open`.
- Label: `gh issue edit NUMBER --repo rakoort/valheim-lembitu --add-label LABEL`.
- Check readiness: `nt check NUMBER --repo rakoort/valheim-lembitu` before applying ready-for-agent.
- Publish an approved change set: `nt specify apply FILE --repo rakoort/valheim-lembitu`.
  Use the [versioned change-set schema](https://github.com/rakoort/newtype/blob/main/docs/agents/issue-tracker.md#approved-change-sets);
  retain the per-entry report and reconcile partial writes before preparing another file.
- Publish Handbacks, parking, and evidence with the scanned transport:
  `nt post NUMBER FILE --repo rakoort/valheim-lembitu`. Redact secrets before posting;
  scan separately published evidence with `nt scan FILE`.
- Accept Ticket changes through `nt merge NUMBER --repo rakoort/valheim-lembitu`,
  not a direct merge that bypasses Review.

Declare the repository check as Git config field `check.command` in
`docs/agents/check.conf`. Initialization creates an empty declaration only when
absent and preserves existing declarations, including with --yes. The pre-commit
hook reads it with `git config --file docs/agents/check.conf --get check.command`
and runs that string with `sh -c`. Missing or blank commands refuse the check.
The command owns dependency installation and all setup needed in a fresh checkout.

Milestone acceptance runs this same declared check locally at the exact
Validation-attested SHA. It fetches from `git@github.com:rakoort/valheim-lembitu.git` into
an isolated temporary bare Git repository and creates a detached disposable
worktree. It reads the declaration from that worktree and runs there before merge.
Failure leaves the PR and Milestone open. Temporary repository, worktree, generated
files, and command TMPDIR are removed on success or failure; caller refs, stash,
and working tree are untouched. This is not an OS sandbox: the command owns cleanup
of external resources and files written outside these temporary directories.

Use the [canonical labels](triage-labels.md) and keep durable knowledge in the
[repository wiki](../wiki/index.md). Check gh auth status before tracker writes.
