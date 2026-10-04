# The Run: concept and rules

This is the document players and agents read to understand what this server is and what the rules
are. It is the human-readable companion to `CONTEXT.md` (the vocabulary) and `docs/modstack.md`
(what runs at which version). Decisions and their reasons are in `docs/adr/`.

Every claim about current behaviour carries a citation to the configuration, source or decision that
implements it. Read the three registers below before trusting any sentence here.

| Register | Meaning |
| --- | --- |
| **Proven** | Measured on the current pack, with the measurement recorded. |
| **Intended** | Decided and enforced in `config/enforced/`, but not yet observed in play. |
| **Unresolved** | Policy nobody has settled. Do not read an answer into it. |

The distinction is not pedantry. This pack is a candidate until the acceptance gate passes
(`docs/modstack.md:92-115`), so "intended" is the honest register for most gameplay rules: the
configuration is committed, the overlay is applied, and no client has yet exercised it.

## What this server is

A private, modded Valheim server for one invited group of fifteen, run as a fixed three-month
**Run** with an announced start and end (`CONTEXT.md:12-19`). It is not a public server and not a
persistent world: the Run ends, and a later Run is a new set of decisions.

The design goal is MMO-lite: clans matter, and personal progress matters. Everything below follows
from those two, and the deliberate exclusions follow from refusing everything else that offered the
same feeling by adding another multiplier or another authority.

## The group

**Admission is by password alone.** The server is public and password-protected, so anyone who can
see it and knows the password can join. There is no whitelist and no per-person admission control.
A password is not a person filter: it cannot stop someone who has it from joining, and this pack
ships no moderation mod. That is the accepted shape for a known friend group, and it is a deliberate
change from the earlier invited-roster plan (`docs/wiki/operations.md`).

**Cap twenty.** The MaxPlayerCount fork raises the server's admission limit and the capacity it
advertises to Steam above Valheim's vanilla ten (ADR-0007). Twenty is a configured value and a
rewritten literal; an eleventh simultaneous connection has **not** been admitted, and #9 records
that gap rather than closing it.

**Clan is the only membership authority.** A Clan is a named group with roles, private chat and its
own friendly-fire rule. It is the *only* concept in the project that answers "is this player my
ally" (ADR-0008, `CONTEXT.md:27-33`). Groups and Guilds are not installed, not even as fallbacks, so
that no second system can start answering the same question differently.

- Roles are Leader, Officer and Member, held in a player's primary clan.
- A **guest clan** is a second, persistent connection. While it is active it is the clan used for
  chat, the HUD, pings, shared positions and friendly-fire checks. Code that asks "is X my clanmate"
  must ask Clan, which resolves primary versus guest, rather than comparing stored clan ids.
- **Friendly fire inside a clan is off**, server-locked, so clanmates cannot damage each other even
  when both have PvP flags on. This is the one rule that makes clan identity mechanically visible
  (`config/enforced/sighsorry.Clan.cfg:1-7`).
- Register: *Intended*. Clan configuration is locked and committed, and its integrations resolve
  against it; a live clan roster and ward behaviour have not been exercised on this pack.

## The two power curves

There are two ways a character gets stronger: **character level** and **gear** (ADR-0017). Both
were removed earlier on 2026-09-17 and both are back the same day, which is worth knowing because
it cost you things that did not come back.

**Character level** is an XP ladder with attribute points (WackyEpicMMOSystem): five points a
level, a cap of 100, and XP from kills. Dying costs between 5% and 15% of progress toward the
current level. **Every character starts again at level 1**: the mod stores level and XP in the
character file, and removing it stranded those values rather than preserving them. The armour
thresholds that used to accompany it — iron at 20, wolf at 35 and so on — are *not* back; nothing
gates gear by level now.

**Gear** is magic items, rarities, effects and enchanting (EpicLoot). Bounties, treasure maps,
gambling and the secret stash stay off. **Magic items you held before the removal are plain vanilla
items now**, because their effects lived on the item and were stripped when the mod left. New drops
roll normally, and the enchanting and augmenting stations must be rebuilt.

**Vanilla skills are not a third curve.** They run 0 to 100 as in vanilla and drain by a percentage
on death, with the drain floor rising by 10 for each boss key a character holds.

**Loot gating reads the player, not the world.** EpicLoot's drop limit is `PlayerMustKnowRecipe`,
so magic drops are gated on what the requesting player knows rather than on world progression.
Building pieces follow the same rule.

**Magic loot is quieter than the mod ships it.** Drops are cut to 0.6 of stock and shardstones from
0.2 to 0.05, every rarity rolls one fewer effect, and the rarity palette is muted with generated
item names off. Those are the same pinned values as before the removal; the configs came back
intact from the repository.

- Register: *Intended*. Restored and deployed 2026-09-17, unplayed. What nobody has measured is how
  a group feels about levelling from 1 again mid-run.

## Personal keys, and what earns one

Valheim's own progression is a set of **world keys** — kill a boss and the whole world advances.
This server does not use them. It uses **personal keys** instead: a boss or progression unlock
stored per character, not in world state (ADR-0005, ADR-0010).

**Presence earns a key, not damage.** When a boss dies, the mod awards the key to every player
within a hundred metres of the chunk host. Presence, not measured contribution, is what counts. One
clan can therefore carry another to a boss kill, and that is the intended cooperation
(`CONTEXT.md:78-84`).

- Personal keys are on, and the world's global key list is blocked outright
  (`config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg`). A flip of either would
  hand the first clan's boss kill to the whole roster.
- Raids are evaluated **per player**, so a player who has not killed a boss is not raided by that
  boss's events.
- Progression gates more than gear. Key-locked: equipment, crafting, **cooking**, **eating**,
  guardian powers (forsaken powers), and boss summons. Deliberately not key-locked: equipment
  repair, building, building repair, taming, boats and portals. Every lock is material-scoped, so a
  keyless character still cooks and eats Meadows food and builds in wood (ADR-0005 amendment,
  2026-09-16).
- Register: *Partly observed*, 2026-09-16. After the run's first boss kill the live world's newest
  committed save held no global keys at all, and a character file on a client held its `defeated_*`
  keys, so blocking and per-character storage both work. What is still unobserved: whether the
  player who made the kill received the key, and whether a bystander beyond a hundred metres
  correctly did not. The locks themselves have not been seen refusing anything.

## The world

**The world is half again as wide as a vanilla one.** Radius 15000 metres instead of 10000, with
terrain stretched to match and biomes a quarter larger (ADR-0018), so a continent carries more
distinct biome neighbourhoods rather than a few stretched thin. Area is roughly 2.25 times vanilla. The size is fixed for the life of this world: it is
baked into the terrain at generation and cannot be changed afterwards. **Every player needs the Pack
for this**, because your client generates the ground itself — without the mod you would see
different terrain than the server.

**Each clan starts in its own place.** Five group starts are provisioned — Skadi, Fenrir, Muninn,
Vidar and Eir — each in its own scored neighbourhood at least a kilometre from the next, chosen for
a large Meadows patch with Black Forest and a burial chamber within reach rather than on the
doorstep. Clans claim a name; the number of places is fixed at world generation and cannot grow
afterwards. Meeting another clan is meant to be an event rather
than the first thing that happens.

**Backpacks carry the extra weight.** AdventureBackpacks adds packs with their own storage; the
run's inventory mod stays at zero extra rows, so the backpack is the answer to carrying capacity
rather than a wider screen. Note it is one-way: if the mod ever left, the packs and everything in
them would go.

**Powers grow with use.** Forsaken powers still come from personal keys, but mastery now deepens as
you use them (ProgressivePowers). Bows also handle differently: quivers and revised draw and aim
(BetterArchery).

**World generation settings stay fixed while the world lives.** Expand_World_Size is
world-permanent in this sense (ADR-0018). No remaining mod adds the dungeon rooms or vehicle
prefabs covered by ADR-0009. Max Dungeon Rooms and ValheimRAFT, including its bundled
DynamicLocations, were removed on 2026-10-03 at the owner's instruction. Removal risks losing
existing vessels, their cargo and dungeon layout; it is not a tested safe migration.

**The night cannot be voted away.** The mod for it was adopted and cut on the same day: its
framework needs a BepInEx patcher in a directory the server container never mirrors, so it never
worked at all. Nights are vanilla length (#86).

**World Advancement Progression is one-way for a different reason.** Its keys live in character
saves, so it is not world-permanent, but it clears the world's global keys on startup. It therefore
belongs in the pack before the launch world is created, not after (ADR-0009 amendment).

**Ore does not teleport.** Portals are restricted so that ore and processed metal cannot pass through
them. This is the vanilla Hard portal setting and the one world rule the launch argument set states
explicitly (`config/launch/launch.env.example`).

**No regional pressure, and no scheduled event.** Until 2026-09-17 the run had Karma — pressure
that rose as players killed in an area — and the Enforcer it eventually summoned, a named creature
that stood in for an event since there is no game master. Both are switched off
(`config/enforced/sighsorry.CreatureManager.cfg`, #84). The mod that provided them is still
installed, because it is also what holds creature multipliers fixed, so turning either back on is
one config line rather than a Pack change.

**Difficulty.** The creature difficulty tier is `Hard` through CreatureManager's biome level preset:
it sets the level distribution for every natural spawn in a biome, and bosses follow the same preset
(`config/enforced/sighsorry.CreatureManager.cfg`). `Hard` spawns roughly 40% stronger ordinary
creatures than the `Easy` default, and the earliest biomes still spawn at level 1 most of the time,
so a new character is not softlocked. Expected boss health runs ×1.05 for Eikthyr to ×2.11 for Fader.

- Register: *Intended*. The preset is committed and loads; observed boss and creature behaviour in
  play belongs to #13 and #10.

**A fight is the same fight whoever turns up.** Vanilla makes every creature tougher for each
player standing nearby — 30% effective health and 4% damage each, capped at five — so a boss was a
different fight depending on who logged in, and inviting a sixth player made it easier. That
scaling is off entirely (`config/enforced/sighsorry.CreatureManager.cfg`,
[4 - Multiplayer Difficulty], both percentages at zero and the count cap at one). Difficulty is
fixed in the level table instead: ordinary creatures and Enforcers carry twice vanilla health,
regular bosses eight (`config/enforced/CreatureManager/levels.yml`). Damage is untouched, so
fights are longer rather than deadlier per hit. Bringing more people is then a choice about how
fast a boss falls, never a penalty, and a duo and a full group face the same wall.

Ordinary creatures carried four times vanilla health until 2026-09-17. Two things moved that
number. Twelve players found ordinary mobs unkillable, which was mostly a modifier problem and is
fixed separately, and character level then left the Pack, taking every character's attribute
points with it (#80). Halving the multiplier is what keeps the fight where it was.

Per-level growth compounds on top of those floors, so the biome preset still decides how much
harder a late biome is: an Ashlands creature at level 3 carries 2 × (1 + 2 × 1) = 6 times vanilla
health, and a level-2 boss 8 × 1.5 = 12 times.

**No creature carries a modifier.** Armoured, enraged, regenerating and twenty-nine other traits
are off entirely, all three master switches (#84). They were the cause of the 2026-09-16 evening
where twelve players found ordinary creatures unkillable: the stock chance reads as a per-creature
rate but is rolled once per group of eight. Cutting the rate to 4 creatures in 100 was the first
answer; switching the idea off was the owner's second. A creature is now exactly its kind and its
stars.

- Register: *Intended*. The multipliers are the owner's decision, applied by #68 and retuned on
  2026-09-17, and never yet measured in a real boss fight. Whether eight times is the right wall
  for a boss is a question for the first kill after it goes live.

## PvP and death

**PvP is the vanilla toggle.** Each player chooses whether to flag. Vanilla's ten-second
post-combat toggle gate remains, and the flag is off at login. No place-bound or persistent
stance has been implemented.

**Deaths follow vanilla rules for everyone.** PvPBiomeDominions was removed on 2026-10-03
at the owner's instruction. Flagged-player equipped-item and hotbar retention left with it,
as did its tombstone-looting restrictions and five-minute post-death PvP grace. There is no
killer-only tombstone access or replacement death mechanic in the stack. The earlier stance
and victim-scoped access decisions in ADR-0012 and ADR-0013 are not current behaviour.


**Carrying capacity does not grow with progression, and that is a deliberate choice.**
AzuEPI's extra rows are a flat 0 to 5 for everyone, with no way to unlock them as a character
advances. Rather than hand every new character several extra rows from the first minute, the run
pins extra rows at zero, so carrying capacity is vanilla plus whatever Haldor sells and the mod's
equipment and quick slots. Multicraft, the crafting grid with search and sort, and scrollable
tooltips have no counterpart in AzuEPI and the Pack no longer offers them; they were conveniences,
not rules. **Favourites do survive the swap**, which an earlier version of this page denied:
AzuEPI 2.4.14 ships a `[10 - Favoriting]` section whose `Favoriting Modifier Key` — Left Shift by
default — marks an item or a slot so storage mods leave it alone. It is a client key, so each
player owns their own binding (read from `AzuExtendedPlayerInventory.dll` 2.4.14, #78).

- Register: *Current stack policy*. Vanilla death rules replace the removed mod's rules;
  this documentation change is not a gameplay measurement.

## Crafting, building and comforts

**Materials come from containers near the station.** A workbench, forge, stonecutter or the
building hammer pulls from every container within **20 m**, so a chest beside the bench feeds it
and a storage hut across the base does not. Nothing is excluded: everything in range is pullable
(AzuCraftyBoxes, `config/enforced/Azumatt.AzuCraftyBoxes.cfg`). The mod is part of the server's
join-time version check, so it is not optional — a client without it is refused at join, the same
way the slot mod already behaves.

**Voice carries as far as your voice would.** Players within 4 m are heard at full volume and
fade out to nothing by 45 m, and the server holds those distances for everyone
(ProximityVoiceChat, `config/enforced/Azumatt.ProximityVoiceChat.cfg`). Your microphone, your
volume, your mute and your keybinds are yours: the server pins none of them. A player who removes
the mod simply has no voice and plays normally, so voice is a convenience rather than a rule.

**Three comforts are yours to keep or remove.** Hover readouts on creatures, pieces, chests and
crafting stations (AzuHoverStats), an on-screen clock with the weather forecast (AzuClock), and
mouse-and-modifier stack moving, splitting and dropping (MouseTweaks). None of them changes a
rule, none is enforced, and a player who deletes them sees vanilla. Hovering a chest inside
another clan's ward shows nothing, because the readout asks the same access check the ward
answers.

- Register: *Intended*. Live since 2026-09-16: both server-side mods are deployed, the overlay
  verifies drift-free, and Pack v8 carries the client halves. Nothing here has been watched in
  play yet — the 20 m pull against a chest at 30 m, the voice distances, the hover inside another
  clan's ward. The group's first session is the measurement.

## What is not here

**The Trade Post is not built.** A clan trading interface with contracts, escrow and mailbox
delivery was designed (ADR-0006) and deferred. It is deliberately safe to add mid-Run because its
records never enter the world save, so only its buildable piece is one-way. Nothing of it exists
today, and nothing in the current UI reads it.

**There is no game master and no scheduled events.** Karma and its Enforcers were the substitute
until 2026-09-17, when both were switched off (#84). Nothing stands in for an event today.

**There are no planned mid-Run content injections.** The accepted pack stays fixed; a mid-Run
upstream replacement requires something actually breaking and passing acceptance again (ADR-0007).

## Known gaps and accepted risks

These are stated to players rather than discovered by them (#23).

**Progression is client-owned and not tamper-resistant.** Personal keys live in the player's own
character save file, where World Advancement Progression stores them. A determined player can edit
their own file to grant themselves keys. This is accepted deliberately: it is a private friends'
server, and a player who edits their own character is a social problem rather than an engineering
one. No server-side character store will be built for this Run (ADR-0010).

**A server-only backup cannot restore progression.** Because those stores are client-owned, the
server's backup captures the world, the admission lists and the biome cache — not characters.
Restoring the world onto a fresh install returns the *world*; each player's character is restored by
Steam Cloud or by their own copy (`scripts/backup-world.sh`, `docs/wiki/operations.md`).

**Clan is load-bearing infrastructure.** If its registry fails to load, allied status is unavailable
rather than wrong: it fails open to an empty registry. Wards, clan chat and friendly-fire checks all
depend on it.

**Boss scaling is a weighting, not a tier step.** A boss rolls its level from the biome preset, so
any single kill can land above or below its expected health multiplier.

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
