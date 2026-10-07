# ADR-0029: The cook grades dishes, feeds the trades, and food spoils

Date: 2026-10-06
Status: Accepted; implemented 2026-10-06 in `Lembitu.Callings` 0.4.0 and the FineDining overlay
Amends: ADR-0021 (what a Cooking focus earns), ADR-0022 (scope of `Lembitu.Callings`), ADR-0024
(Cooking perks "as shipped")

Amended 2026-10-06 (owner): ADR-0032 retires recipe rungs, raises the food bonus per grade to 5%, and gives the alchemist a separate brewer’s grade. Shelf life is unchanged. Earlier values below are historical where annotated.

## Context

The owner asked for cooking to be as useful and as fleshed out as alchemy and smithing, with
cooperation first (2026-10-06). Food already decides most of a fighter's health: a fed Meadows
character measured 76 health and an unfed one 25 (`docs/wiki/shakedown.md`, Food after rejoin). Yet
the cook had only the ladder, which makes late dishes theirs to craft (ADR-0023), and ImpactfulSkills'
bonus servings at 40. Nothing showed who made a dish, nothing tied the other professions to the cook,
and a cook could stock a guild for the whole Run in one evening.

The smith's gear is a little better from a master (+10% damage at 100, ADR-0024); the alchemist sells
power by the dose. The cook had neither. FineDining 1.1.3 was the only spoilage system among the 169
post-1.0 food mods on Thunderstore; dish-content mods (BoneAppetit, ValheimCuisine, Culinary
Horizons) add recipes but no role.

## Decision

**The cook's grade.** A dish made at a Cooking station carries the grade of the cook who made it: 1
below Cooking 25, then one per 25 levels, 5 at 100. Each grade above 1 adds ~~2.5%~~ 5% to everything
the dish gives, health, stamina, eitr and regeneration (ADR-0032, amended 2026-10-06: +20% at
grade 5), and 12.5% to shelf life (+50%, unchanged). The grade reads real Cooking level,
never food or gear bonuses. Recipe rungs are retired. A dish is anything edible made at a Cooking
station, or anything a cooking station turns into an edible dish: graded dough bakes into graded bread. Herbalist's products and
mead bases stay the alchemist's; feasts are ungraded.

The grade lives in item quality, which keeps grades in separate stacks (Valheim stacks by name,
quality and world level only) and survives the Market, and in a custom-data marker the effects read,
so a quality-3 fish is never taken for a dish. FineDining computes food stats and shelf life, so the
grade scales its food effect, which FineDining saves with the player, and its lifetime rule.

**Work meals.** While one of these dishes is one of the eater's foods, its profession counts as ten
levels higher for perks, never for the cook's grade, which reads the real level (ADR-0032).
Recipe requirements are retired; the former rung column is removed.

| Dish | Profession |
| --- | --- |
| Boar jerky | Exploration |
| Deer stew | Wood Cutting |
| Sausages | Mining |
| Carrot soup | Farming |
| Serpent stew | Sailing |
| Wolf jerky | Hauling |
| Blood pudding | Animal Handling |
| Fish wraps | Fishing |

Only Land and Road professions take work meals; a Craft meal would feed the smith's stamped bonus
or the cook's own grade. The bonus is a status effect timed to the food, not the dish's consume
effect: vanilla refuses to consume an item whose consume effect is active, which would stop
re-eating the dish at half time.

**Food spoils, and keeping it pays.** FineDining 1.1.3 joins the stack with its package lifetimes,
two to four days of server time, and three food slots. Its stat scale is 1.1, so a fresh dish gives
110% of vanilla and a stale one 82.5%. Storage climbs with the Run: from the Meadows, jerky, sausages,
smoked fish and smoked moose meat never spoil, beside the package's honey; from the Mountains, nothing
spoils in the Mountains or Deep North, so a guild's mountain storehouse is its larder; with
Mountains materials, the Icebox pauses spoilage at home, two per player. Managing food is rewarded,
not only protected: fresh food beats vanilla, a master's dish keeps longer, and the Market keeps both
the grade and FineDining's expiry, so listing food never refreshes it.

Everything that rewards the eater rather than the cook is off: FineDining's Chef's Choice,
diminishing returns, Full Course, Cooking XP for eating and its production bonus, and ImpactfulSkills'
Cooking XP for eating and the eater's food-decay reduction. The vanilla fermenter is excluded from
FineDining, so meads keep vanilla timing and output and stay the alchemist's goods.

**Not taken.** Feast fellowship (a bonus for party members eating one feast) rewarded a party, not
the cook's skill, and was dropped (owner, 2026-10-06). No dish-content mod was adopted.

## Consequences

- `Lembitu.Callings` hooks FineDining's internal `FoodRules.CalculateFoodEffect` and
  `SpoilagePolicy.Resolve`; FineDining has no public API. FineDining is pinned at 1.1.3 and a bump
  re-checks `Lembitu.Callings`, whose feature switches off alone on a mismatch. Without these hooks
  a grade does nothing, so the tooltip stops showing it.
- FineDining fixes a dish's lifetime once, in its own first prefix on `Inventory.AddItem`. The grade
  marker is stamped ahead of it, ordered before FineDining's Harmony id; a bump that moves that
  assignment shows up as graded dishes keeping no longer than plain ones.
- A grade crosses a cooking station on the station's ZDO: the inserting client sends it after
  vanilla's add, and the owner stamps what the slot spawns, FineDining's auto-eject and a destroyed
  station's drops included.
- FineDining 1.1.3 saves its diet state without the list of eaten foods: with carrot soup eaten,
  the saved state was only `{"UnlockedFoodSlots":3,"AppliedBaseSlotScale":1.1}` (2026-10-06). After a
  relog every eaten food fell back to the base 110%, so a graded dish lost its grade and stale food
  came back fresh. `Lembitu.Callings` keeps each eaten food's scales in its own player key
  (`lembitu.callings.eaten-scales`) and restores them only when FineDining loads an empty list, so a
  FineDining fix takes over without a change here.
- Vanilla drops a fresh, ungraded copy when a craft finds the inventory full, with no crafter name
  either; a graded craft into a full inventory loses its grade the same way.
- Historical tuning assumed vanilla food. Fresh food stays 110%; v17's graded food reaches 132%
  (ADR-0032), replacing the former 121% maximum. Native results below describe earlier settings.
- One-way: the Icebox and FineDining's rotten foods vanish if FineDining leaves.
- The test harness's snapshot now reports item quality, custom data and tooltip, foods, status
  effects, maximum health and stamina and effective skill levels, and can give items a quality and
  custom data and reach a cooking station's switches.
- Proven 2026-10-06 in one native full-Pack session on astral-tricep
  (`~/lembitu-native-tests/20261006T094335Z-cook/`): a cauldron craft at Cooking 100 makes grade-5
  carrot soup and one at Cooking 20 an ungraded stack beside it; grade 5 keeps 1.5× as long; eaten,
  it gives 18.15 health and 54.45 stamina (×1.21); the dish tooltips show the grade and the work
  meal; the Farming work meal raises Farming 20 to 30 for the soup's time; a grade-4 dough bakes in
  an oven into grade-4 bread that keeps 1.375× as long; after a relog the soup still gives its
  graded scale (17.89 health at 1430 s left) and the work meal is back. A station owned by another
  client and a Market round-trip were not tested.
