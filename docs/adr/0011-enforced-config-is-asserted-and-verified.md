# ADR-0011: The enforced config is asserted on every boot and verified against the live server

Applying the enforced config by hand once, at deploy time, lost ten of forty-six pinned keys: on
2026-09-16 the live server was found running mod defaults for the difficulty tier, five progression
locks, the skill manager, EpicLoot's drop gating, clan friendly fire and death retention ownership,
and a full evening of play — including the run's first boss kill — had happened under them. Nothing
in the repository compared the live configuration to `config/enforced/`, so the revert was silent.
We therefore re-apply the enforced config on every container start and ship a verification command
that compares the live configuration to the overlay and exits non-zero on any difference, wired into
the deploy path and run alongside the backup timer.

## Consequences

The launch path now depends on that machinery, which is why this is recorded rather than left as an
operator habit. Two failure modes remain, and the verification is what surfaces them: a key an
upstream mod renames stops matching and is reported as drift rather than silently reverting, and a
mod whose configuration is not server-synced — AdminQoL was the case that taught us — cannot be
enforced from the server at all and must be handled in the client Pack instead.

## Considered options

Verification alone was rejected because it turns a silent revert into a loud one but still needs a
human to look. Assertion alone was rejected because a renamed key would fail silently again and
nothing would report what changed. Staying manual was rejected because it had already failed once,
during the run, on the rules the run exists to enforce.
