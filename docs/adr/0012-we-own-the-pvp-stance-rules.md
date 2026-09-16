# ADR-0012: We write the PvP stance and corpse-access rules ourselves

The run wants two PvP rules no published mod implements: a stance a player may change only at a boss
runestone or inside their own clan's ward, and corpse access decided by the dead player's stance
rather than the looter's. A survey of the whole Thunderstore Valheim catalogue on 2026-09-16 — 11,269
packages — found neither behaviour anywhere, while the pinned PvPBiomeDominions evaluates its
tombstone rules per acting player, which is what lets a flagged player loot an unflagged grave and
makes the flag a button rather than a stance. We will implement both checks as our own plugin (#67),
taking the clan-aware tombstone authorisation pattern from `sighsorry/FearNoSpear` and the
toggle-suppression pattern from `VentureValheim/Venture_Multiplayer_Tweaks` as reference rather than
as dependencies.

## Relationship to earlier decisions

This is a deliberate exception to **ADR-0003**, which says wanting different behaviour is not a
reason to own someone else's code, and to **ADR-0010**, which says adopt upstream progression
instead of writing our own plugins. Both stand for the cases they were written about: replacing a
mod that already does the job, or reimplementing progression that upstream ships. Neither applies
here, because the behaviour does not exist upstream to adopt. Nothing about this reopens the
adoption rule for the mods already pinned.

## Consequences

We own the maintenance of two patched game surfaces across game updates, which ADR-0007's frozen
version limits but does not eliminate. The refusal messaging is client-side, so the plugin forces a
client Pack reissue. And the plugin depends on Clan for membership and Ward for the claim, which
keeps ADR-0008 intact: membership is asked of Clan, never inferred by comparing identifiers.
