# Wiki curation

Durable knowledge for [rakoort/valheim-lembitu](https://github.com/rakoort/valheim-lembitu) lives in
[the repository wiki](../wiki/index.md).

## Knowledge-bearing directories

These repository-relative directories were selected from the repository layout.
Review this list as the layout changes. Each item is one literal directory, not a glob;
descendants count, similarly named siblings do not. An empty layout starts with src/.

- `config/`
- `lib/`
- `scripts/`
- `src/`
- `test/`

## Push gates

The pre-push hook runs `nt wiki curate "$1"` before `nt wiki validate`.
Keep nt on PATH when pushing. Curate consumes Git's ref-update lines from stdin
and checks each pushed range independently. A declared directory change needs
a Markdown wiki page change in the same range; otherwise it prints STALE / NEW /
PRUNE and refuses the push. Unknown ranges warn and fail open; no objects are fetched.

Update stale claims, record new knowledge, and prune obsolete knowledge before retrying.
Humans can set NT_WIKI_BYPASS=1. Runs with THURBOX_SESSION also need a nonblank,
single-line NT_WIKI_ATTESTATION. Curation prints the attestation for the Handback.
Bypass skips only curation, never validation; failed validation blocks the push.
