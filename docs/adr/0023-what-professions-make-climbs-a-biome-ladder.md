# ADR-0023: What professions make climbs a biome ladder

Date: 2026-10-04
Status: Accepted; the rule file is generated (2026-10-04, `scripts/generate-ladder.py`)
Amends: ADR-0021 (what makes the top of a skill worth having)

## Context

ADR-0021 gated master recipes at profession level with Radamanto/Item_Requirement and, where the
item pool had nothing worth gating, expected premium items authored in DataForge. Research the same
day (`local/mod-review-2026-10-04/prof-RecipeGatesAndQuality.md` and the grilling's MasterRecipes
handback) found real crafted items for seven professions: pickaxes, mead bases and Herbalist's
tonics, prepared dishes and feasts, the Scythe, biome baits, saddles, and AdventureBackpacks' packs.
Mining, Wood Cutting, Exploration and Sailing have no crafted item worth gating; ships and their parts
are build pieces or early materials.

A first proposal gated a short list of endgame items at level 70. The owner found gating only the
endgame odd, and weighed four shapes: endgame only, a ladder for profession goods, a ladder for
goods and gear, and no level gates at all. Without gates, trade becomes optional and Herbalist and
most of Cooking stop being trades, because tonic strength and food decay read the consumer's skill,
not the maker's (`Herbalist.cs:975-978`, `ImpactfulSkills.cs:3995-4002`).

A DataForge clone that is later removed vanishes from every save on the next load, and Marketplace
1.4.0 clears an account's items before delivering them, so buying or withdrawing a listing whose
prefab is gone loses the item (`MarketServer.cs:405-422`, `MarketClient.cs:394-427`).

## Decision

**What a profession makes climbs a ladder of ten levels per biome.**

| Biome | Profession level to craft |
| --- | --- |
| Meadows | none |
| Black Forest | 10 |
| Swamp | 20 |
| Mountains | 30 |
| Plains | 40 |
| Mistlands | 50 |
| Ashlands | 60 |
| Deep North | 70 |

An item's rung is the biome of its materials, as World Advancement Progression reads that biome for
its boss-key locks, so the two gates rise together.

**What climbs it, by profession:**

- **Blacksmithing:** weapons, shields and armour, capes included, crafted or upgraded. The smith is
  the guild's armourer. Pickaxes and axes are weapons by item type and climb with them; the iron
  pickaxe that silver needs sits on the Swamp rung, which asks only for practice.
- **Cooking:** dishes made in the crafting menu, up to the feasts. Meat cooked on a cooking station
  is not a recipe and stays open.
- **Herbalist:** mead bases, and Herbalist's own tonics and elixirs (ADR-0024).
- **Fishing:** biome baits.
- **Animal Handling:** saddles.
- **Hauling:** backpacks.
- **Farming:** the Scythe.
- **Mining, Wood Cutting, Exploration and Sailing:** nothing to craft; their perks are their reward.

Hammer, hoe, cultivator and utility items (belt, lantern, Wisplight) are not profession goods and
stay open. **Ammunition stays open too:** arrows and bolts are used up constantly, and ranged classes
should never wait on a smith for a refill; the smith still makes the bows and crossbows. **Magic
gear climbs with the rest:** staffs and Galdr-table gear are weapons and armour, so the smith is
armourer to every class, Mage and Warlock included; they sit on the Mistlands rung and above.

**Only crafting is gated.** Item_Requirement rules set `BlockCraft` and never `BlockEquip`, so anyone
may use, wear or buy what a specialist made. Repairs are not recipes and stay open.

**Boss trophies stay out of recipes.** No vanilla 1.0 recipe and no pinned mod consumes a boss
trophy, and one drops per kill. Re-killing a boss already pays through its other drops, which vanilla
recipes use, through EpicLoot's boss loot and through ProgressivePowers mastery; trophy costs would
only make some items scarce without giving trophies a role.

**Only items already in the game and the Pack.** DataForge stays tuning-only, as `docs/modstack.md`
states: it may change an existing recipe's ingredients, but it clones nothing. ADR-0021's "premium
items are authored in DataForge" is withdrawn.

**Why ten per biome.** Below 30 every profession levels at full speed, so the first three rungs only
ask for practice. From the Plains on, a non-focus crafter needs more work for each rung: 1.5× the
skill XP at 40, 1.7× at 50, 1.8× at 60 and 2.5× at 70, against a focus player who at 70 is about 40%
of the way to 100.

## Consequences

- **A specialist never drains below a rung.** A focus skill keeps its XP on death (ADR-0022), so a
  smith, cook or herbalist who reached a rung stays there. A non-focus crafter is protected only by
  World Advancement Progression's floor, 10 per personal boss key: a threshold, not a clamp, so a
  skill just above it can end a little below after one death and must be retrained across the gap.
- **Non-focus Blacksmithing and Herbalist follow the same floor.** Their bundled skill managers
  would drain on their own and ignore it (`prof-SkillModFamilies.md` section 1); `Lembitu.Callings`
  drains them by World Advancement Progression's rule instead (ADR-0022).
- **A guild depends on its specialists.** A guild whose smith is offline cannot craft or upgrade
  that tier until the smith is back, and buys from another guild meanwhile. EpicLoot drops still
  give gear no smith made.
- **The smith levels by crafting for others.** Blacksmithing XP comes from crafting and upgrading, so
  outfitting the guild is how a smith climbs.
- **Herbalist's and Cooking's customers gain less than they pay for.** Tonic and food strength read
  the consumer's skill; the ladder makes the specialist the only source of late tonics and dishes,
  not the source of stronger ones.
- No item exists that the Run cannot keep, so no Marketplace listing can point at a missing prefab.
- The rule file holds one entry per gated item: 364 at the 2026-10-04 generation, from a native
  1.0.16 ObjectDB dump of the Pack (`config/enforced/ItemRequirement/`). The generator reads World
  Advancement Progression's own material maps from the running game. Version 1.0.0 knows no bait
  trophy, no Herbalist herb and no Deep North material, so where it knows none of an item's
  materials the generator fills in the material's real biome from game data (creature spawns and
  drops, vegetation, Deep North locations) in a cited override table that can only raise a rung.
  121 rules rest on such an override; there the ladder gates an item World Advancement Progression's
  own lock does not.
- A rung follows the materials, not the name. The Deep North bait uses a Mountains trophy and sits on
  rung 30; the Plains feast uses a spice World Advancement Progression places after the Plains boss,
  so it sits on rung 50. Items whose materials are all Meadows stay open: SeaAnimals' saddle, the
  Meadows backpack, the Runner elixir, and the strength and swimmer mead bases.
- An item and its upgrades share one rule, so the rule takes the highest rung any quality needs. The
  1.0.16 Deep North gear is made from `*Uncooked` intermediates converted at the Frost Foundry; those
  intermediates carry the Blacksmithing rule, so the foundry is no way around the smith.
