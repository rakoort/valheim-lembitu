# ADR-0030: The Calling choice is balanced by time saved, within a band

Date: 2026-10-06
Status: Accepted; implemented 2026-10-06 in `Lembitu.Callings` 0.5.0 and the enforced overlays
Amends: ADR-0021 (where the steep curve starts), ADR-0024 (Wood Cutting, Fishing and Hauling perks;
smith and herbalist XP)

## Context

The owner set the balancing goal for professions: choosing a Calling should be hard from an
efficiency standpoint (2026-10-06). An assessment against that goal found it only partly met. The
Craft choice was a real role choice, but Mining had three switch-on perks while Wood Cutting, Fishing
and Hauling had none, professions earn XP in very different ways, and below level 30 a focus made no
difference, which in the pace audit's model left the first half of the Run without a choice to make
(`local/premium-review-2026-10-04/AuditPace.md`). Nothing had been measured in play. The owner then
settled the policy in a one-question-at-a-time interview the same day and chose to start the Run
without a separate Shakedown, collecting the data from play.

## Decision

**The yardstick is time saved per hour of play, for a player alone.** A Land or Road focus is judged
by how much faster it makes what the player does anyway: gathering, carrying, finding, sailing. A
guild's mix and Market prices are left to push players apart by themselves. Craft is judged by demand
instead of speed: smith, alchemist and cook should be equally wanted.

**The choice is hard within each group, and the 2-1-1 quota stays.** In each group the best pick saves
at most 1.25 times the time of the worst: the **profession band**.

**Professions keep their own way of levelling** (owner: "not fully homogenized, but the choice
shouldn't be immediately obvious"). The band is judged on the combined result of pace and perks, and
only a pick outside it is corrected: perks first, XP pace last, and both ends toward the middle, the
strongest trimmed and the weakest lifted. Nothing is trimmed before data exists.

**Borrowed levels keep counting.** Work meals and EpicLoot's profession effects raise the level every
perk reads, as ADR-0029 chose for meals. EpicLoot is watched: its tool rolls add to Mining, Wood
Cutting and Fishing only, and its crafter rolls to Cooking, stacking across five armour slots.

**The steep curve starts at 10** (was 30). Black Forest goods stay open to everyone at full speed; a
non-focus profession needs 1.8 times the XP to reach 20, 1.93 times to reach 30 and 1.99 times to
reach 60 (was 1, 1 and 1.82). Switching a focus is free only below 10.

**Every Land and Road profession has at least one switch-on milestone.** The three that had none get
one at 50, written in `Lembitu.Callings` and adjustable by setting:

| Profession | Milestone at 50 | Default |
| --- | --- | --- |
| Wood Cutting | Log splitter: a chop on a fallen log can split the whole log, half logs included, into wood | 10% per chop at 50, rising to 30% at 100 |
| Fishing | Quick bite: fish head for your float every time they look for one | vanilla sends them half the time |
| Hauling | Steady overload: walking over the carry limit costs no stamina | up to 1.5 times the limit |

**Smith and herbalist XP take half of the audit's step now.** BlacksmithingExpanded's craft, smelt,
upgrade and first-craft XP rise about 1.75 times; Herbalist's Exp Gain Factor goes to 2. The audit's
full step (2.5 and 3.5 times) waits for measurement.

**Measurement: timed tasks and an XP log.** Each client reports its profession XP to the server log
every ten minutes of play: per profession, the real level, whether it is a focus, the raw XP after
every mod's rate and the XP the steep curve let through. A standard task per profession is timed on
the test host at levels 10, 30, 50 and 70. The two together place each pick against the band.

## Consequences

- The Run starts without a Shakedown. Every lift reaches players at no cost; every trim takes a perk
  away from players who chose it, so trims come early and are announced.
- Settings change with one `scripts/launch-server.sh restart`; code changes need a new Pack for every
  player, because our plugins require matching versions.
- The log splitter skips the chops it replaces, and with them their Wood Cutting XP: it saves time,
  not levels. The chopper's client rolls; the log's owner runs vanilla's `TreeLog.Destroy` on the log
  and every half log, so ImpactfulSkills' and EpicLoot's drop bonuses still apply.
- Quick bite marks the float on its ZDO, because a fish's AI runs on whichever client owns the fish.
  The bait test is untouched, so the biome baits still gate the biome fish.
- Steady overload leaves vanilla's other encumbrance rules in place: no running, jumping or dodging.
- The XP log is admin-facing: it lives in the server's BepInEx log, and no player sees it. A logout
  loses at most one unsent ten-minute window.
- Whether the Market records sales on the server is not yet known; without it, Craft demand is judged
  from play.
