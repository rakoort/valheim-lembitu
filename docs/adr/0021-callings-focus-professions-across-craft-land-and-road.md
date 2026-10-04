# ADR-0021: Callings — four focus professions across Craft, Land and Road

Date: 2026-10-04
Status: Accepted (design); implementation pending in a plugin of ours
Amends: ADR-0019 (professions), ADR-0020 (scope of our own plugin code)

## Context

ADR-0019 asks for soft specialisation: anyone can do anything given enough time, but specialists
are more efficient, and players should clearly be pushed to focus and to divide responsibilities
inside a guild and between guilds. Oathbound gives combat that shape through classes. Professions
had no equivalent: every profession mod levels freely, so a dedicated grinder masters everything
and a guild never needs anyone else.

A review of the profession mods on Thunderstore (`local/mod-review-2026-10-04/prof-*.md`) found no
framework that delivers this. AeresProfessions allows a single profession and keeps XP outside the
skill system; Artisan_Mastery is equipment content with combat bonuses. The owner kept
ImpactfulSkills, BlacksmithingExpanded and Herbalist as the profession mods and designed the
specialisation layer here.

## Decision

**Skills fall into six categories.**

| Category | Skills | Specialised |
| --- | --- | --- |
| Combat | Swords, Knives, Clubs, Polearms, Spears, Axes, Unarmed, Bows, Crossbows, Elemental Magic, Blood Magic, Blocking, Dodge | Through the Oathbound class |
| Body | Run, Jump, Swim, Sneak, Ride | No |
| Common | Crafting (vanilla) | No |
| Craft | Blacksmithing, Herbalist, Cooking | Yes |
| Land | Mining, Wood Cutting, Farming, Fishing, Animal Handling | Yes |
| Road | Exploration, Sailing, Hauling | Yes |

Profession mods add nothing to Combat or Body skills: ImpactfulSkills' weapon, blocking, blood
magic, sneak, run, jump and swim perks are switched off.

**A Calling is four focus professions**: two from Land, one from Craft, one from Road. Each Calling
is a complete supply chain the player builds themselves, such as Mining, Wood Cutting,
Blacksmithing and Hauling. A guild of three to five covers most professions between its members;
a guild that lacks one buys from another guild on the Market.

**Focus professions level at full speed to 100. Every other profession skill levels on a steep
curve**: full speed to 30, half speed to 60, a quarter to 80, a tenth beyond. Nothing is capped,
so anyone can master anything given enough time; a focus gets there several times faster. Combat
and Body skills are not affected. The numbers are tuned in the Shakedown.

**Changing a focus knocks the dropped skill down to what it would have been without the focus.**
Every profession skill carries a shadow level that earns the same XP at the non-focus rate and
drains on death by the same proportion as the real skill. Dropping a focus sets the real level to
the shadow level. Below 30 the two never differ, so early switching is free; a master who switches
gives up exactly the advantage the focus gave.

**Choosing.** A player marks their focus professions with a star in the normal skills window, but a
change only takes effect while standing at the Oathstone, where the class is chosen too. Until a
Calling is chosen, every profession follows the steep curve; below 30 that changes nothing.

**What makes the top of a skill worth having.** Each mod's best perks are retuned to sit above the
full-speed band, and master recipes are gated at profession level with Radamanto/Item_Requirement,
which blocks the craft itself and reads modded skills such as Blacksmithing and Herbalist. Where
the item pool has nothing worth gating, premium items are authored in DataForge.

## Consequences

- A plugin of ours owns the focus choice, the steep curve and the shadow levels, by hooking skill
  gain for the eleven profession skills and storing the Calling on the character. This widens
  ADR-0020's single patch plugin into our progression layer.
- The skill floor from World Advancement Progression is a death-drain threshold only; it raises no
  skill (corrected in ADR-0019). It does not interact with the steep curve.
- BlacksmithingExpanded and Herbalist drain their skills with their own death-loss setting instead
  of the boss-key floor. Their loss percentage is set to match the vanilla drain.
- ImpactfulSkills' Crafting perks are off as well as Forging, because they duplicate
  BlacksmithingExpanded.
- Still open: the retuned perk thresholds per mod and the master-recipe list per profession. Boss
  trophies are a candidate ingredient for master recipes: boss loot is one drop per kill (EpicLoot
  `Boss Trophy Drop Mode = Default`), so re-killing a boss pays.
