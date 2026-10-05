# The Run: concept and rules

This is the document players and agents read to understand what this server is and what the rules
are. It is the human-readable companion to `CONTEXT.md` (the vocabulary) and `docs/modstack.md`
(what runs at which version). Decisions and their reasons are in `docs/adr/`.

Every claim about current behaviour carries a citation to the configuration, source or decision that
implements it. Read the four registers below before trusting any sentence here.

| Register | Meaning |
| --- | --- |
| **Proven** | Measured on the current pack, with the measurement recorded. |
| **Intended** | Decided and enforced in `config/enforced/` or the launch arguments, but not yet observed in play. |
| **Planned** | Decided in an ADR and waiting on code of ours (`Lembitu.Oathbound`, `Lembitu.Callings`) or a generated rule file that does not exist yet. |
| **Unresolved** | Policy nobody has settled. Do not read an answer into it. |

The pack is a candidate until the acceptance gate passes (`docs/modstack.md`, "Acceptance gate"),
and this page was rewritten on 2026-10-04 from the decisions of that day (ADR-0019 to ADR-0024).
Almost everything below is therefore *Intended* or *Planned*; the Shakedown is where it gets measured.

## What this server is

A private, modded Valheim server for one group of about eight active players, organised into
guilds of three to five (ADR-0019). The **Run** is open-ended, but every system is sized for an
actively playing group to kill Fader in about one month. Before it comes the **Shakedown**, played on
a world that will be discarded, where the rules below are tried and corrected.

The concept is **MMORPG-lite for rival guilds that must cooperate**. There is no PvP. Guilds compete
through progress, territory and the Market. A boss is tuned for eight players, so guilds need each
other to kill one. Trade between guilds is an advantage rather than a necessity: a guild of three can
cover every profession, but not every hour of the day. Anyone can do anything given time;
specialising is how you do it well.

Seven things make a character or a guild stronger: class level, talents, professions, gear tiers,
boss powers, guild progression and magic schools (ADR-0019, ADR-0020).

**The Pack is built for keyboard and mouse; controllers are not supported.** The rules of this page
are carried in game by the guide window: press **F1** or the Guide button in the inventory (ADR-0027).
It opens on a character's first join, its text is the server's (`config/enforced/lembitu.guide.md`),
and a refusal names the rule it hit and the guide page that explains it.

**Keys:** F1 Guide; F7 Market; F9 Guilds; O social; P party; Left Alt+E hides or shows
Explorer markers (`config/enforced/lembitu.guide.md` and the Pack key bindings).

## Admission

**Admission is by password alone.** The server is public and password-protected; there is no
whitelist and no moderation mod. That is the accepted shape for a known friend group
(`docs/wiki/operations.md`).

**Cap twenty.** The MaxPlayerCount fork raises the admission limit above Valheim's ten (ADR-0007).
An eleventh simultaneous connection has not yet been observed (#9).

## Guilds and parties

**A guild is who you belong to.** Northarun/Guilds supplies ranks, guild chat, a shared vault,
guild-bound wards, a banner territory, guild levels, upgrades and achievements. Founding is free,
a guild has at most five members, and at most three guilds exist because there are three start
regions to claim (ADR-0019, ADR-0028). A player who leaves or is kicked may join or found another
guild at once; there is no waiting period (`RejoinCooldownHours = 0`). Guild progress buys base
safety later in the Run: the monster ward at guild level 10 and comfort upgrades at 12 and 20. Coin
donations buy guild XP at 10 coins a point, so trade feeds the guild.

**Guilds form in game, at the stones.** Every new character wakes at the sacrificial stones, beside
the Oathstone, for as long as they belong to no guild holding a region: meet, take an oath, choose a
Calling, found or join a guild (ADR-0028). Separately from that first evening, a character with no
guild never takes over a start region, and a bed or logout point respawns them as in vanilla.
Press **F9** to open the guild window: **FOUND A GUILD** starts your own guild for free,
**INVITATIONS** lets you accept an invitation, and **GUILD LIST** lets you apply to a guild
and wait for approval.

**A guild claims a region at its portal stone.** Each region keeps one portal in the ring around the
sacrificial stones, 28 m out. A guild leader whose guild holds no region who uses an unclaimed
region's stone gets a confirmation window naming the region and where it lies — north or south,
how far out; confirming claims it. First come, first served; the claim is stored on the server
(`<BepInEx ConfigPath>/Lembitu.Guilds/<world>.claims.json`) and survives a restart. A non-leader cannot
claim, a guild already holding a region cannot claim a second one, and the region-side portal still
costs its 2 surtling cores to open initially (SeparateSpawns). Disbanding does not reset activation:
a freed region can be claimed again even if its portal pair remains open.
Hovering a free stones-side portal shows eligible leaders **[E] Claim <Region> for your guild**;
everyone else gets a free-region explanation and the F9 guild-window hint. A claimed portal names
its guild, while SeparateSpawns retains its own activation and travel text
(`src/plugins/Lembitu.Guilds/ClaimPortal.cs`).

**The region follows the guild, not the character.** A member of a guild with a region is assigned
to it: that is their bedless respawn point and its portal answers to them, while every other guild's
portals refuse them (`Lembitu.Guilds`, ADR-0028). Leaving the guild or being kicked returns that
player to the stones; disbanding the guild also frees its region for the next guild. Membership is
read from Guilds' server state, never from what a client reports, and belongs to each character
separately: another character on the same Steam account inherits neither membership nor region.
The assignment settles within seconds of a change or once a joining character's body identifies
them to the server. An initial join keeps vanilla beds and logout points; without either, it starts
at the stones rather than trusting another character's old assignment. Later bedless deaths retain
the identified character's region; a bed always overrides it, as in vanilla.

- Register: guild, claim and move rules *Intended* (`Lembitu.Guilds`,
  `config/enforced/lembitu.guilds.cfg`).

**A party is who you hunt with.** M2Valheim/SocialSystem parties are invite-only, hold up to eight
players and may mix guilds (`config/enforced/M2Valheim.SocialSystem.cfg`). A party shares exactly two
things: map positions, and kill XP. It never answers "who owns this".

**Kill XP goes to the killer's party, and only to members near the kill** (ADR-0022):

- The kill is credited to whoever landed the killing blow. Companions and burning count for their
  owner. Others who hit the creature but are not in the killer's party earn nothing.
- Party members within **100 m** of the creature when it dies split its XP equally. That is the same
  distance that earns a boss key. A member further away, disconnected or dead earns nothing and does
  not count. Being in a party never waives proximity. The killer always counts, wherever they stand,
  so partying never costs the killer a kill.
- The party's total rises with the members in range: 100% of the kill for one, about 117% for two,
  about 133% for three, **150% for four and every larger party** (ADR-0022): 58% of the kill each in
  a pair, 44% each in a trio, 37.5% each at four and 18.75% each at eight.

- Register: *Intended* (`Lembitu.Oathbound`, `config/enforced/lembitu.oathbound.cfg`).

## Classes, levels and talents

**Your class comes from Oathbound, chosen at the Oathstone.** Oathbound (LionAndOtter) gives thirteen
classes, each with active abilities and a 79-node talent tree: Huscarl, Shieldbearer, Valkyrie,
Ranger, Mage, Warlock, Rogue, Monk, Hunter, Berserker, Highlander, Breaker and Dragonsworn. Four are
unlocked by doing something first: equip paired axes (Berserker), a two-handed sword (Highlander) or
a two-handed axe (Breaker), or carry a dragon tear (Dragonsworn). Mage and Warlock are the magic
schools. Hunter and Dragonsworn fight beside a companion (ADR-0020).

**Go to the Oathstone first.** It stands 17-21 m from the start temple near the centre of the world.
Guilds start 0.5 to 1.2 km from there, so reaching it is the first short trip of the Run. A character with no
class earns no class XP at all (`Warrior.Core.Progression.GrantExperience`). Class, talents and your
Calling change only at the Oathstone (`config/enforced/local.warrior.rpg.cfg`, `AccessMode =
Oathstone`).

**Class level.** Kills earn XP for your active class, up to level 80. A kill pays about
2·√(its maximum health), between 10 and 80, four times that for a boss, plus up to 5 for creatures
that hit hard. Each level gives one talent point. There is no cap on points and no change to
Oathbound's XP pace, so a level-80 character owns all 79 nodes; level 80 needs about 2,500 to 3,000
kills (ADR-0022).

**Class power follows boss keys.** Everything that grows with class level — spells, Warlock summons,
wards and Wither, Monk fists, class abilities, the Hunter's wolf and the Dragonsworn whelp, and the
defense tree's pool — reads the **power level** instead: your class level capped at ten per personal
boss key, so 10 before Eikthyr and 80 after Fader (ADR-0025). Grinding kills without bosses no longer
outgrows the gear gate. Talent points, class XP and the class level itself are untouched. Spell
growth stays 4% per power level behind a server-locked setting (`lembitu.oathbound.cfg`, `[Power]
SpellGrowth`), and companions start the Shakedown at 0.75× damage (`[Companions] DamageMultiplier`).

**Respec and class switch cost the class level.** Resetting your talents puts the class back to
level 1, and so does switching to another class: both the class you leave and the class you take
start over. You level one class at a time. This is cheap early and expensive late (ADR-0020,
ADR-0022). The tree says so: its reset button reads "Reset to level 1", and taking an oath while
either class has progress asks once more.

**Class equipment rules stay, except for tools.** Classes keep Oathbound's armour, weapon, shield
and bow rules: Mages, Warlocks, Rangers, Monks and Rogues wear no metal armour, Shieldbearers and
Valkyries carry no bow, and so on. Every class may use the fishing rod, and a Monk's bare-handed blows
on rocks and trees train Mining and Wood Cutting, so no class is shut out of a profession (ADR-0022).
A refused item names the rule and points at the guide: "Guide: Oath and class (oath-and-class)".

- Register: *Intended* (`Lembitu.Oathbound`).

## Professions and Callings

**Eleven professions in three groups** (ADR-0021):

| Group | Professions |
| --- | --- |
| Craft | Blacksmithing, Herbalist, Cooking |
| Land | Mining, Wood Cutting, Farming, Fishing, Animal Handling |
| Road | Exploration, Sailing, Hauling |

Combat skills (weapons, magic, blocking, dodge) and body skills (run, jump, swim, sneak, ride) are
not professions and are not affected by anything in this section.

**Your Calling is four focus professions: two Land, one Craft, one Road.** A focus levels at full
speed to 100. Every other profession levels at full speed to 30, half speed to 60, a quarter to 80
and a tenth beyond. Nothing is capped, so anyone can master anything given time; a non-focus skill
needs 1.8 times the work of a focus to reach 60, 2.5 times to reach 70 and nearly 6 times to reach
100. Until you choose, every profession follows the slow curve, which changes
nothing below 30.

**You choose your focuses in the Calling window**, opened from the Calling button in the skills
window. It can be read anywhere; a change takes effect only while standing at the Oathstone, and
elsewhere the controls say to go there. The stars on the profession rows are read-only markers with
their tooltip. Dropping a focus asks first, and names the level the skill falls to.

**A focus keeps its XP when you die.** Every other skill drains as described under *Death*.

**Dropping a focus costs exactly what the focus gave.** The game keeps a second, hidden level for each
focus: what it would be without the focus, earning at the slow rate and draining on death like a
non-focus skill. Dropping the focus sets the skill to that level. Early on the two hardly differ;
a master who switches gives up the faster gain and the death protection together.

**A seed bed is a planter that follows soil's rules** (ADR-0022). It returns soil's yields — barley
and flax 5 → 10, a vegetable seed 5 → 5 vegetables, a vegetable 5 → 15 seeds, the Mistlands
mushrooms 5 → 15 — and it refuses what soil refuses: a seed whose plant cannot grow in the bed's
biome, until Farming 60 lifts the biome rule as it does for soil (`Lembitu.Callings`; the yields in
`config/enforced/blacks7ar.SeedBed.yml`). A seed with no vanilla cultivator piece stays allowed;
its existing SeedBed conversion is not removed.

- Register: *Intended* (`Lembitu.Callings`, `config/enforced/lembitu.callings.cfg`, ADR-0022).

## What professions make: the biome ladder

**What a profession makes climbs ten levels per biome** (ADR-0023). Crafting an item needs the
matching profession at its rung, by the biome of its materials, the same biome World Advancement
Progression reads for its boss-key locks:

| Biome | Level to craft |
| --- | --- |
| Meadows | none |
| Black Forest | 10 |
| Swamp | 20 |
| Mountains | 30 |
| Plains | 40 |
| Mistlands | 50 |
| Ashlands | 60 |
| Deep North | 70 |

Up to the Mountains a rung only asks for practice. From the Plains on, a crafter without the focus
needs 1.5 times the skill XP at 40, rising to 2.5 times at 70.

| Profession | What climbs the ladder |
| --- | --- |
| Blacksmithing | Every weapon, shield and armour piece, capes and Galdr-table magic gear included, crafted or upgraded. Pickaxes and axes are weapons too; the iron pickaxe that silver needs sits on the Swamp rung. |
| Herbalist | Mead bases, Herbalist's tonics and elixirs |
| Cooking | Dishes made in the crafting menu, up to the feasts. Meat cooked on a cooking station is not a recipe and stays open. |
| Fishing | Biome baits |
| Animal Handling | Saddles |
| Hauling | Backpacks |
| Farming | The Scythe |
| Sailing | OdinShip's caulked wood at 40, the one named material exception |
| Mining, Wood Cutting, Exploration | Nothing to craft; their perks are their reward |

**Only crafting is gated, never use.** Anyone may wear, wield, drink or buy what a specialist made.
Repairs, ammunition, the hammer, hoe and cultivator, and utility items stay open to everyone.
Three Meadows-material items climb early by name, all crafting-only: the Herbalist's Swift elixir
at Herbalist 40, SeaAnimals' saddle at Animal Handling 40 and OdinShip's caulked wood at Sailing 40
(2026-10-05, ADR-0023) — a taste of each speciality before its biome rung.

**The smith is the guild's armourer and the alchemist its apothecary** (ADR-0024). From the Plains
on, every new piece of gear comes from a smith at the right rung, and every vanilla mead (healing,
stamina, eitr, and the poison, frost and fire resistance meads) and every elixir comes from an
alchemist. Gear is bought once per tier; potions are used up every fight. A master smith's gear is
also a little better: +1% damage, +0.5 armour and +1 block power per 10 Blacksmithing levels.
EpicLoot drops still give gear no smith made.

**Herbalist's elixirs, retuned to boss-fight strength** (`config/enforced/blacks7ar.Herbalist.cfg`):
Berserker ×1.25 damage, Swift ×1.2 speed, Jump ×1.5, Fast Learner ×1.5 skill XP at half health,
Defender as shipped (very resistant, but you deal a fifth of your damage), Invisibility 60 s,
Heavy Lifter 60 s, Slow Fall as shipped. Durations grow with the drinker's own Herbalist skill.

- Register: the ladder *Intended* (364 rules in `config/enforced/ItemRequirement/`, generated from the
  game's item database; a rung follows an item's materials, not its name, ADR-0023); elixir and
  smith numbers *Intended*.

## Perks

**A focus makes you visibly better at the job, and no profession is the obvious pick** (ADR-0024).
Perks grow with every level: more wood and ore per swing, faster taming and more from each animal,
more carry weight, a wider map reveal, longer-lasting tools and faster smelting. At 100, for
example, chopping and digging hit 1.5 times as hard and yield 1.67 times the wood or ore, taming runs
2.5 times as fast, a hauler carries 100 more and an explorer reveals 300 m around them. Herbalist and
Fishing get extra output instead: about 1.5 extra items per craft and 1.25 extra fish per catch at
100, from `Lembitu.Callings`, because their mods give the maker nothing. A master sailor's ship takes
up to 2.5 times the sail force and rows faster.

**Power perks that switch on at a level sit on the ladder's rungs**, never below 30. Explorer's
information unlocks instead follow the biomes: Meadows 1, Black Forest 10, Swamp 20,
Mountain 30, Plains 40, Mistlands 50, Ashlands 60; dungeons and caves 10. Live marker
range grows linearly from 20 m at Explorer 1 to 64 m at 100.

| Level | Perks |
| --- | --- |
| 40 | Cooking bonus servings, honey bonus, mining critical hits, area harvesting, planting several at once, faster paddling |
| 50 | Hives in any biome, boat damage reduction, area mining, better wind angles |
| 60 | Crops in any biome |
| 70 | Whole-vein mining, an extra star on tamed animals, no ram damage to your ship |

- Register: rungs and magnitudes *Intended* (`config/enforced/MidnightsFX.ImpactfulSkills.cfg`,
  `config/enforced/blacks7ar.Explorer.cfg`); the Herbalist and Fishing bonus *Intended*
  (`Lembitu.Callings`). The Shakedown judges the balance by playing each focus.

## Personal keys, and what earns one

Valheim's own progression is a set of **world keys**: kill a boss and the whole world advances. This
server writes none. It uses **personal keys**: a boss unlock stored per character (ADR-0005,
ADR-0010).

**Presence earns a key, not damage.** When a boss dies, every player within 100 m of the client
controlling the boss gets the key, and nobody else. Guilds do not share keys with absent members
(`config/enforced/adrian.valheim.guilds.cfg`). A late joiner catches up by being carried through
re-kills, never by skipping content.

**A key unlocks a biome's gear for both crafting and wearing.** Key-locked: equipment, crafting,
cooking, eating, guardian powers and boss summons. Not key-locked: repairs, building, taming, boats
and portals. Every lock follows the biome of the item's materials
(`config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg`). Drinking follows the
same rule for Herbalist's tonics and elixirs (ADR-0022): each needs the personal boss key of its
strongest herb's biome, a biome World Advancement Progression does not know on its own
(`Lembitu.Callings`). Trade helps, but never skips a boss.

**Boss powers are passive and grow with boss kills** (ProgressivePowers). You attune one Forsaken
power at a time; it gives passive bonuses rather than the vanilla active power, and it gains up to
seven mastery levels as you are present (within 100 m) at boss kills, later bosses included
(`config/enforced/MidnightsFX.ProgressivePowers.cfg`).

- Register: *Partly proven*, 2026-09-16, on an earlier pack: the world held no global keys after the
  first boss kill and a character file held its keys. The locks have not been seen refusing anything.

## Death

Deaths are meant to cost something (ADR-0019):

- **Class XP:** you lose half your progress into the current class level, never a level
  (Oathbound).
- **Skills:** each non-focus skill loses 5% of its level, but only while it is above your skill
  floor, which rises by 10 for every personal boss key you hold
  (`config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg`). The floor never raises a
  skill; it only stops the drain. A skill just above it can end a little below after one death.
  Focus professions lose nothing. Blacksmithing and Herbalist follow the same rule as every other
  profession (ADR-0022).
- **The corpse run:** your tombstone holds what vanilla death rules take, and you go back for it.
  Carried items and durability are otherwise untouched.

- Register: class, floor, focus protection and the Blacksmithing and Herbalist drain *Intended*
  (`Lembitu.Callings`).

## The world

**About 1.76 times the area of a vanilla world.** Radius 13,250 m, world stretch 1.325, biome stretch
1.25, and points of interest at vanilla density (Expand_World_Size, ADR-0019). The size is baked into
the terrain when the world is created and cannot change afterwards. Every player needs the Pack,
because your client generates the ground itself.

**Each region is its own place, and a guild claims one.** Three scored start regions, 0.5 to 1.2 km
from the sacrificial stones and at least a kilometre apart (SeparateSpawns, ADR-0018,
`config/dedicated/abortipus.separatespawns.cfg`). A guild claims one at that region's portal stone
in the ring around the sacrificial stones, after the confirmation window (ADR-0028, *Guilds and
parties*); nobody lives out there until one does, and every new character wakes at the stones.
Meeting another guild is meant to be an event rather than the first thing that happens.

**Ore does not teleport, until the Ashlands.** Ordinary portals refuse ore and metal, so they travel
by ship or cart (`config/launch/launch.env.example`, `Portals hard`). Vanilla's Ashlands stone portal
carries everything, metal included, and that late reward is kept. XPortal only lets you pick a
destination.

**Maps are personal.** You share what you have explored at a cartography table, and guilds share
pins. Party members see each other on the map. There is no creature radar. Explorer
shows temporary resource and dungeon markers near you as its skill unlocks them;
BetterMap makes no automatic resource pins. Everyone's public position is off
(`config/enforced/xtav1m.BetterMap.cfg`, `config/enforced/blacks7ar.Explorer.cfg`,
`config/enforced/com.orianaventure.mod.MultiplayerTweaks.cfg`). Readouts are welcome:
hover stats, skill progress, a clock and the weather forecast.

**There is no PvP.** It is held off for everyone (`config/enforced/com.orianaventure.mod.MultiplayerTweaks.cfg`).

## Difficulty

**Harder than vanilla, and the same fight whoever turns up** (ADR-0019). Nothing scales with the
number of players nearby. Bosses are tuned for eight players and ordinary creatures for two:

- Ordinary creatures carry twice vanilla health and vanilla damage (the 2026-10-04 raise to 1.2
  was trimmed back on 2026-10-05 — health keeps a fight long, damage growth was what one-shot);
  bosses eight times its health and 1.5 times its damage. Level growth is slower than vanilla on
  both (`config/enforced/CreatureManager/levels.yml`).
- Creature levels follow CreatureManager's `Hard` biome preset, so a late biome spawns stronger
  creatures and bosses follow suit (`config/enforced/sighsorry.CreatureManager.cfg`).
- The game's own `Combat hard` world modifier is also set (`config/launch/launch.env.example`).
- About 10 in 100 ordinary creatures carry a **creature modifier** (armoured, enraged, an elemental
  infusion and others), a boss about one, and an Enforcer two. Deathward, regenerating, omen and
  blamer are off, and bosses and Enforcers never roll the three counters that punish ranged and
  caster classes — vortex, adaptive and chameleon (`config/enforced/CreatureManager/levels.yml`,
  `karma.yml`, 2026-10-05).
- **Karma:** an area where players kill heavily grows more dangerous — two steps, at 90 and 180,
  capped at +2 — and eventually an **Enforcer**, an elite hunt target worth a group's effort,
  appears.
- **Additive resistances:** resistances stack additively, and a player always takes at least 25%
  of each damage type, so stacked resistances never reach immunity
  (`config/enforced/sighsorry.AdditiveDamageModifier.cfg`).

Bringing more people makes a boss fall faster; it never makes it harder or easier per hit.

- Register: *Intended*. The numbers are measured against real fights in the Shakedown.

**Raids are Oathbound's sieges.** Whenever vanilla would start a random raid, a siege starts instead
at a ready outpost: a portal, or a crafting station with six or more pieces within 90 m. With no
outpost, nothing happens. A siege warns you, sends an assault and reinforcements, and ends when you
kill its commander; it pauses while nobody is within 100 m. Its strength follows the biome the
outpost stands in, never how many players are online, and from the Black Forest tier up its raiders
do full damage to buildings. Sieges come less often than vanilla raids (`Raids less` in
`config/launch/launch.env.example`), because each one is a bigger fight. ZenRaids keeps natural
spawns out of a base with a lit fire, and the guild monster ward, from guild level 10, starves a
siege of places to spawn. There are no blood moons (`config/enforced/local.warrior.rpg.cfg`).

- Register: *Intended* (ADR-0019, ADR-0020).

## Gear and loot

**Magic gear comes from EpicLoot.** Magic items, rarities, effects, enchanting and Haldor's adventure
trade: treasure maps, bounties (at most five in progress per player), gambling and the secret stash.
Drops run at 0.6 of stock — a creature drop's odds of coming out magic are 0.36 times the
package's — and shardstones at 0.1; a failed tempering can destroy the item. A drop is
gated on recipes the player knows rather than on world progress (`Item Drop Limits =
PlayerMustKnowRecipe`). A boss drops one trophy, one Wishbone and one swamp key per kill, not one per
player present, so killing it again pays (`config/enforced/randyknapp.mods.epicloot.cfg`). The sea
hunts the oceans gained — sharks, the Humboldt squid and the crocodile — drop magic gear like the
land creature of their biome's tier, and the peaceful turtles and whales drop none
(`config/enforced/EpicLoot/patches/lembitu-seaanimals.json`).

## The Market

**One server-wide market that works while the other side is offline.** Northarun/Marketplace offers
coin sales, buy orders, bounties and a bank. A 5% fee on every payout keeps coins scarce
(`config/enforced/adrian.valheim.marketplace.cfg`). Under the ladder the Market is where a guild buys
what its own members cannot yet make.

## Crafting, building and comforts

**Materials come from containers near the station.** A station or the hammer pulls from every
container within 20 m (AzuCraftyBoxes, `config/enforced/Azumatt.AzuCraftyBoxes.cfg`). A client without
the mod is refused at join.

**Every piece costs full materials at its station.** PlanBuild's plans, Extra Snap Points and the
building-piece mods help you plan and place precisely, but PlanBuild's direct build and terrain tools
are off for players, so a plan is finished with real materials (`config/enforced/marcopogo.PlanBuild.cfg`).
Free-building tools are for admins only.

**Carrying.** The inventory stays at vanilla rows, with equipment, quick and special slots
(`config/enforced/Azumatt.AzuExtendedPlayerInventory.cfg`). AdventureBackpacks' packs carry the
extra weight — contents at 85% weight and a small carry bonus per quality: stock bonuses halved
and rounded down to **2/5/7/10/12/15**, Meadows through Mistlands (owner, 2026-10-05). A backpack
helps but stays below what the Hauling profession grants
(`config/enforced/vapok.mods.adventurebackpacks.cfg`); they are one-way, so if the mod ever left,
the packs and their contents would go. Its automation settings are yours.

**Voice carries as far as your voice would.** Full volume within 4 m, fading to nothing by 45 m
(ProximityVoiceChat, `config/enforced/Azumatt.ProximityVoiceChat.cfg`). Your microphone, volume and
keybinds are yours.

**Your own settings may only express preference.** Snapping, convenience automation, keybinds and
interface layout are yours. Anything that changes difficulty, combat or what one player gets over
another is locked by the server or not in the Pack (ADR-0019).

## Known gaps and accepted risks

These are stated to players rather than discovered by them (#23).

**Our two plugins are new.** `Lembitu.Oathbound` and `Lembitu.Callings` exist and were checked in a
real client on 2026-10-04 (`docs/build.md`, "Plugin native checks" and "Full-pack native
acceptance"). The kill XP split within a party of two or more has not yet been seen in play; the
Shakedown measures it and the rest of their numbers.

**Progression is client-owned and not tamper-resistant.** Personal keys, Oathbound's class progress
and the Calling all live in your own character file. A determined player can edit it. That is
accepted on a friends' server (ADR-0010).

**A server-only backup cannot restore progression.** The server's backup captures the world, not
characters. Each character is restored by Steam Cloud or the player's own copy
(`scripts/backup-world.sh`, `docs/wiki/operations.md`).

**Some settings are not proven locked.** BlacksmithingExpanded's main settings are synced from the
server but carry no lock entry; whether a player can change them while connected is a Shakedown check
(ADR-0024).

**Boss health is a weighting, not a fixed step.** A boss rolls its level from the biome preset, so a
single kill can land above or below its expected health.

## Where the rest lives

| Question | Document |
| --- | --- |
| What a word means here | [`CONTEXT.md`](../CONTEXT.md) |
| Which mods, at which versions, and why | [`docs/modstack.md`](modstack.md) |
| Why a decision was made, and what was rejected | [`docs/adr/`](adr/) |
| Building, installing and the test loop | [`docs/build.md`](build.md) |
| Operating the server, backups, launch | [`docs/wiki/operations.md`](wiki/operations.md) |
| Installing the client Pack | [`docs/wiki/pack.md`](wiki/pack.md) |
| Research provenance | [`docs/research.md`](research.md) |
| Where documentation and behaviour disagree | [`docs/reconciliation.md`](reconciliation.md) |
