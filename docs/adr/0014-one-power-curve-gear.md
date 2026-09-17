# ADR-0014: One power curve, gear

Status: Superseded by [ADR-0016](0016-no-power-curve-and-a-world-permanent-mod-removed.md)

The run keeps exactly one power curve: gear. Character level is removed, and with it
`WackyMole/WackyEpicMMOSystem` 1.9.67 and `WackyMole/WackyItemRequiresSkillLevel` 1.4.7 (#80,
decided 2026-09-17). This supersedes ADR-0004's decision to run two curves; every cut ADR-0004 made
still stands.

Two curves were one too many for the same reason four were. Character level and gear both multiply
the same damage and survivability numbers, and each was tuned by a different author against vanilla.
The difference is that gear's inputs are ours to shape — drop rates, effect counts, the rarity table
— while character level's were an XP curve and an attribute economy that we pinned at upstream
values and never measured. #72 existed to settle what awards XP and how fast the ladder climbs, and
it was never answered; a curve nobody has tuned is a curve nobody has chosen.

What remains beside gear is a *gate*, not a ladder. World Advancement Progression refuses to equip
or craft an item whose materials belong to a biome the character has not unlocked, per personal key.
That answers the question the level thresholds were there for — a clan cannot hand a newcomer
endgame equipment — without adding a second number that grows. The two mods therefore had to leave
together: the gate mod's curated rules gated iron, wolf, padded and carapace armour at levels 20,
35, 50 and 65, and nothing reads those thresholds once there are no levels.

## What this costs, accepted

- **Every existing character loses its invested attribute points**, and the health, stamina and
  damage they bought. `config/enforced/CreatureManager/levels.yml` therefore drops `Global.health`
  from 4 to 2 in the same change, so ordinary creatures are twice vanilla health rather than four
  times. Without that, removing a power curve would have been a difficulty increase nobody chose.
  `Boss.health` stays at 8 and per-player scaling stays off at `0 / 0 / 1`.
- **The mod's own items disappear.** EpicMMOSystem registered real prefabs through ItemManager —
  `mmo_xp_drink1` to `3`, `mmo_mead_minor`, `mmo_mead_med`, `mmo_mead_greater`, `Mob_chunks` and
  `ResetTrophy` — so anything of that set sitting in an inventory or a chest is gone the first time
  the world loads without the mod.
- **A Pack re-extract is forced**, the third in two days. A player who keeps either mod gets private
  rules: the gate mod would gate on its own local YAML, and the level mod would keep handing that
  one player attribute bonuses nobody else has.

Neither mod is world-permanent, which is what makes the removal possible at all. Character level and
XP live in the player's own character file, in `Player.m_knownTexts` under
`WackyMole.EpicMMOSystem_LevelSystem_Level`, `_CurrentExp` and `_TotalExp` (read from
`EpicMMOSystem.dll` 1.9.67). Removal leaves those keys stranded in each character file and writes
nothing to the world save, so the decision is reversible for the world even though it is not
reversible for a character's spent points.

## What is deliberately unchanged

Personal keys and every World Advancement Progression lock. The vanilla skill floor that rises by 10
for each boss key a character holds. EpicLoot's drops, rarities, enchanting and its
`PlayerMustKnowRecipe` gating. CreatureManager's difficulty tier, Karma and Enforcers. Clans, wards
and portals. ADR-0004's cuts — ImpactfulSkills, Valheim Enchantment System, ValheimArmory — and its
rule that DataForge stays tuning-only, because the deferred Trade Post ledger (ADR-0006) needs
stable item identity.

## Consequences

- Balance now has one input to tune. Gear is where depth is added, and adding it is one-way:
  EpicLoot-style item data cannot be removed without destroying gear (ADR-0007, ADR-0009).
- Progression is a gate rather than a treadmill. A character advances by unlocking biomes through
  personal keys, and the reward is what they may wear, not a stat multiplier.
- #72 is closed as moot: there is no XP to award, lose or curve.
- Three configuration files leave with the mods, because the drift check fails on an overlay naming
  a file no mod generates: the two enforced files `WackyMole.EpicMMOSystem.cfg` and
  `WackyMole.ItemRequiresSkillLevel.yml`, and the client seed
  `WackyMole.EpicMMOSystemUI.cfg`. That seed set the HUD bars back to vanilla colours;
  with the mod gone, vanilla bars are simply what the game draws.
- Re-adding character level mid-run is possible and cheap for the world, since nothing of it is in
  the save, but it is not cheap for players: every character would start at level 1 with the keys it
  already holds.


## Amendment — 2026-09-17

Gear lasted hours, not weeks. EpicLoot was removed the same day (ADR-0016, #85), so the run keeps no
power curve at all and progression is vanilla gear gated by personal keys. The reasoning above holds
in the same direction it always did — every curve was a multiplier on one number — and this is its
end point rather than a reversal.
