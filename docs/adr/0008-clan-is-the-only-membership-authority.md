# ADR-0008: Clan is the only membership authority

Date: 2026-09-10
Status: Accepted
Issues: #3, #22

## Context

Several mods can answer "which players are allied": Clan, Smoothbrain's Groups, and the Guilds mod
that STU_Ward and PortalRules also integrate with. Valheim itself has none of this beyond PvP flags.

The question is asked constantly and by different consumers: clan chat delivery, friendly-fire
checks, ward access, portal access modes, shared map positions, the clan HUD, and — once #16 exists
— who may fill whose contract. Every one of those must get the same answer, including in the
awkward case: a player with a primary membership *and* an active guest connection to another clan,
where the guest clan is the one that counts for chat, pings, positions and friendly fire.

Groups is attractive because it exposes an API for other mods and is cheap to install. That is
exactly the problem: a second system that other mods might start believing.

## Decision

- **Clan owns membership.** Its roles, guest connections and friendly-fire rule are the single
  answer, and every integration reads it.
- **Groups is not installed.** Not as a fallback, not as a library for its API.
- **Guilds is not installed either**, even though STU_Ward and PortalRules support it, so their
  integrations resolve against Clan alone.
- **Clan Friendly Fire is off**, server-locked, so clanmates cannot damage each other even with PvP
  flags on — the one rule that makes clan identity mechanically visible.

## Consequences

- Anything that needs to know about allies goes through Clan, including our own plugins. If Clan is
  down or its registry fails to load, allied status is unavailable rather than wrong — its
  fail-open-to-empty-registry behaviour is a known risk tracked in #3.
- Guest connections are part of the model, not an edge case: code that asks "is X my clanmate" must
  ask Clan, which resolves primary versus guest, rather than comparing stored clan ids.
- A future mod that ships its own group system is either configured to defer to Clan or not adopted.
- Clan is therefore load-bearing for the whole run, which is why it is pinned and verified like
  infrastructure rather than a social feature.
