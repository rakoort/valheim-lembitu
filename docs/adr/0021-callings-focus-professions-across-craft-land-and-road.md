# ADR-0021: Callings — four focus professions across Craft, Land and Road

Date: 2026-10-04
Status: Accepted; implemented in `Lembitu.Callings` (ADR-0022, 2026-10-04); the Calling window and
the read-only stars of the 2026-10-05 amendment implemented 2026-10-05 (#89)
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

Amended 2026-10-05: Road Exploration is blacks7ar/Explorer 1.1.7, replacing
ExpertExplorer. Its bundled-manager skill is named Explorer; it follows the same
Calling, shadow curve and single profession death drain as the other professions.
Its rewards are skill-gated live resource/dungeon markers and wider personal map reveal
(ADR-0019, ADR-0024), with no P pin prompt; P belongs to SocialSystem Party.

Profession mods add nothing to Combat or Body skills: ImpactfulSkills' weapon, blocking, blood
magic, sneak, run, jump and swim perks are switched off.

**A Calling is four focus professions**: two from Land, one from Craft, one from Road. Each Calling
is a complete supply chain the player builds themselves, such as Mining, Wood Cutting,
Blacksmithing and Hauling. Three players already cover all eleven professions (six Land slots for
five, three Craft, three Road), so trade between guilds is an optional advantage, not a dependency:
guilds trade for speed, surplus and specialists who are offline (owner, 2026-10-04 premium review;
first written as "a guild that lacks one buys from another guild").

**Focus professions level at full speed to 100. Every other profession skill levels on a steep
curve**: full speed to 30, half speed to 60, a quarter to 80, a tenth beyond. Nothing is capped,
so anyone can master anything given enough time; a focus gets there several times faster. Combat
and Body skills are not affected. The numbers are tuned in the Shakedown.

**Changing a focus knocks the dropped skill down to what it would have been without the focus.**
Every profession skill carries a shadow level that earns the same XP at the non-focus rate and
drains on death as a non-focus skill would. A focus skill itself keeps its XP on death (ADR-0022).
Dropping a focus sets the real level to the shadow level. Below 30 the two differ only by the deaths
the focus absorbed, so early switching is nearly free; a master who switches gives up exactly the
advantage the focus gave, in gain and in death protection.

**Choosing.** A player chooses focus professions in a Calling window opened from a button in the
skills window; it can be read anywhere, but a change only takes effect while standing at the
Oathstone, where the class is chosen too (owner, 2026-10-05; first built as clickable stars on the
skills rows, which remain as read-only markers). Until a
Calling is chosen, every profession follows the steep curve; below 30 that changes nothing.

**What makes the top of a skill worth having.** Each mod's best perks are retuned to sit above the
full-speed band. What a profession makes, weapons and armour included for Blacksmithing, is gated
by profession level with Radamanto/Item_Requirement on a ladder of ten levels per biome, which
blocks the craft itself and reads modded skills such as Blacksmithing and Herbalist. Only items
already in the game and the Pack are gated (ADR-0023, which replaced the first plan of a few master
recipes and withdrew premium items authored in DataForge).

## Consequences

- Our second plugin, `Lembitu.Callings`, owns the focus choice, the steep curve and the shadow
  levels, by hooking skill gain for the eleven profession skills and storing the Calling on the
  character. It is separate from `Lembitu.Oathbound` (ADR-0022).
- The skill floor from World Advancement Progression is a death-drain threshold only; it raises no
  skill (corrected in ADR-0019). It does not interact with the steep curve.
- BlacksmithingExpanded, Herbalist and Explorer handle death through bundled managers outside
  the boss-key floor. `Lembitu.Callings` restores them and applies World Advancement
  Progression's rule once instead (ADR-0022); Explorer's own loss is pinned to 0.
- ImpactfulSkills' Crafting perks are off as well as Forging, because they duplicate
  BlacksmithingExpanded.
- Perk thresholds are settled in ADR-0024; boss trophies were considered as ingredients and left
  out (ADR-0023).
