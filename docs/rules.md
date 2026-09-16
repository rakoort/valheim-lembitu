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

There are exactly two ways a character gets stronger: **character level** and **gear**
(ADR-0004). Everything that offered a third was cut, because four multipliers land on one damage
number and each was tuned by a different author against vanilla.

**Character level** is an XP ladder with attribute points (WackyEpicMMOSystem): five points a level,
a cap of 100, and XP from kills. The curve and the attribute economy are pinned at the mod's own
values on purpose — the 2026-09-16 review chose to measure real levelling speed before tuning them.
Dying costs between 5% and 15% of progress toward the current level. What else awards XP is not yet
decided: chopping trees, mining, gathering, building and even killing players all award it today,
which #72 settles.

**Gear** is magic items, rarities, effects and enchanting (EpicLoot). Bounties, treasure maps,
gambling and the secret stash are **off**: Adventure Mode was disabled on 2026-09-16 because named
elites with health multipliers and a trader casino read as a different game.

**Vanilla skills are not a third curve.** They run 0 to 100 as in vanilla and drain by a percentage
on death. The one deviation: the drain floor rises by 10 for each boss key a character holds, so a
veteran loses less to a death than a newcomer, while the gain ceiling stays at 100.

**Gear is gated by character level, not by world progress.** `WackyItemRequiresSkillLevel` refuses to
equip the chest, legs and helm of each armour tier past bronze until the character reaches a level:
iron at 20, wolf at 35, padded at 50, carapace at 65
(`config/enforced/WackyMole.ItemRequiresSkillLevel.yml`). Crafting is allowed ahead of the level;
wearing is not. The intent is that a clan cannot hand a newcomer endgame equipment (ADR-0005). Those
thresholds are a starting point for playtest tuning, not a settled balance decision.

**Loot gating reads the player, not the world.** EpicLoot's drop limit is set to
`PlayerMustKnowRecipe`, so magic drops are gated on what the *requesting player* knows rather than on
world progression (`config/enforced/randyknapp.mods.epicloot.cfg`). Building pieces follow the same
rule. Every other gating mode in that setting reads world keys, which this server never writes — see
"Personal keys" below.

**Magic loot is deliberately quieter than the mod ships it.** The first tester read three shardstones
from chopping trees and a Legendary shardstone from Eikthyr as a genre change. Three things answer
that. Drops are cut to 0.6 of stock and shardstones from 0.2 to 0.05. Every rarity rolls one fewer
effect, with the extra-effect roll thinned as well, so an item usually shows exactly its tier's
count — one for Magic, five for Ancient (#73). And the rarity palette is muted with generated item
names off, shipped in the client Pack because those keys cannot be enforced from the server.

- Register: *Intended*. Every value above is decided and none is measured in play. #68 applies them,
  #72 owns the XP question, #73 the effect thinning.

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

**World-permanent mods land before the launch world is created.** A world-permanent mod writes its
content into the world save — locations, dungeon rooms, vehicles — so it must be installed before
the launch world exists and can never be removed during the Run (ADR-0009). Two qualify:
**Max Dungeon Rooms** (larger dungeons) and **ValheimRAFT** (custom ships, anchoring, vehicle
building).

**World Advancement Progression is one-way for a different reason.** Its keys live in character
saves, so it is not world-permanent, but it clears the world's global keys on startup. It therefore
belongs in the pack before the launch world is created, not after (ADR-0009 amendment).

**Ore does not teleport.** Portals are restricted so that ore and processed metal cannot pass through
them. This is the vanilla Hard portal setting and the one world rule the launch argument set states
explicitly (`config/launch/launch.env.example`).

**Karma and Enforcers.** Karma is regional pressure that rises as players kill creatures in an area,
strengthening later spawns. An **Enforcer** is a high-level, modifier-carrying creature that Karma
summons, in dungeons or the open world. It is the project's stand-in for a scheduled event, since
there is no game master (`CONTEXT.md:105-115`).

**Difficulty.** The creature difficulty tier is `Hard` through CreatureManager's biome level preset:
it sets the level distribution for every natural spawn in a biome, and bosses follow the same preset
(`config/enforced/sighsorry.CreatureManager.cfg`). `Hard` spawns roughly 40% stronger ordinary
creatures than the `Easy` default, and the earliest biomes still spawn at level 1 most of the time,
so a new character is not softlocked. Expected boss health runs ×1.05 for Eikthyr to ×2.11 for Fader.

- Register: *Intended*. The preset is committed and loads; observed boss and creature behaviour in
  play belongs to #13 and #10. #26 owns ValheimRAFT's vehicles.

**A fight is the same fight whoever turns up.** Vanilla makes every creature tougher for each
player standing nearby — 30% effective health and 4% damage each, capped at five — so a boss was a
different fight depending on who logged in, and inviting a sixth player made it easier. That
scaling is off entirely (`config/enforced/sighsorry.CreatureManager.cfg`,
[4 - Multiplayer Difficulty], both percentages at zero and the count cap at one). Difficulty is
fixed in the level table instead: ordinary creatures and Enforcers carry four times vanilla
health, regular bosses eight (`config/enforced/CreatureManager/levels.yml`). Damage is untouched,
so fights are longer rather than deadlier per hit. Bringing more people is then a choice about how
fast a boss falls, never a penalty, and a duo and a full group face the same wall.

Per-level growth compounds on top of those floors, so the biome preset still decides how much
harder a late biome is: an Ashlands creature at level 3 carries 4 × (1 + 2 × 1) = 12 times vanilla
health, and a level-2 boss 8 × 1.5 = 12 times.

- Register: *Intended*. The multipliers are the owner's 2026-09-16 decision, applied by #68 and
  never yet measured in a real boss fight. Whether eight times is the right wall is a question for
  the first kill after it goes live.

## PvP and death

**PvP is each player's own flag, and today it is a button.** Every biome rule is `PlayerChoose`, so
the server never forces PvP on anyone and Wards follow the biome rule
(`config/enforced/Turbero.PvPBiomeDominions.cfg:16-32`). Nothing restricts where or how often a
player flips the flag, and only a five-minute post-death grace slows them. #67 decides that a stance
may be changed only at a boss runestone or inside your own Clan's Ward, which no pinned mod can
express.

**Death rules differ by whether you opted in.** The server pins both sides, because the PvE side is
the rule for everyone who has not opted in and an upstream default flip must not change it silently:

| | Unflagged (PvE) | Flagged (PvP) |
| --- | --- | --- |
| Keep equipped items on death | no | **yes** |
| Keep hotbar items on death | no | **yes** |
| Loot another player's tombstone | no | **yes** |
| No items lost on death | off | off |

**That last-but-one row is about the looter, not the victim.** The upstream rules are area-scoped —
"in PvE areas all tombstones can be looted" — and with every biome on `PlayerChoose` the effective
area is whichever flag the *acting* player carries. So a flagged player may loot an unflagged
player's grave, which is the opposite of what the Run wants. Observed by the owner, 2026-09-16. #67
records the intended rule: an unflagged death is private, a flagged death is lootable.

The tombstone still has to exist for any of it to matter, so no-item-loss stays off in both columns.
InventorySlots has an independent keep-on-death system and it is disabled, so it cannot compete with
that authority (`config/enforced/sighsorry.InventorySlots.cfg`).

**Two things to know that the configuration does not say:**

- **Retention is death-cause blind.** The mod's tombstone patch takes no killer, so a flagged player
  who drowns also keeps their gear. Dying to a player is not mechanically distinct from dying to a
  troll for a flagged player (`config/enforced/Turbero.PvPBiomeDominions.cfg:6-10`).
- **Loot permission depends on a non-empty alert message.** The loot restriction lives in a prefix
  that returns early — allowing everyone to loot every grave — when the alert toggle is off or the
  message is empty. Both are therefore pinned, and the message is load-bearing configuration rather
  than decoration.

- Register: *Intended*. Flag behaviour, retention and grave access have not been observed on this
  pack; #8's policy question is settled by the overlay above, but the behaviour is not measured.

## What is not here

**The Trade Post is not built.** A clan trading interface with contracts, escrow and mailbox
delivery was designed (ADR-0006) and deferred. It is deliberately safe to add mid-Run because its
records never enter the world save, so only its buildable piece is one-way. Nothing of it exists
today, and nothing in the current UI reads it.

**There is no game master and no scheduled events.** Enforcers and Karma are the substitute.

**There are no planned mid-Run content injections.** The accepted pack stays fixed; a mid-Run
upstream replacement requires something actually breaking and passing acceptance again (ADR-0007).

## Known gaps and accepted risks

These are stated to players rather than discovered by them (#23).

**Progression is client-owned and not tamper-resistant.** Character level, XP and personal keys live
in the player's own character save file (EpicMMOSystem stores them in `Player.m_knownTexts`; World
Advancement Progression stores keys in the character file). A determined player can edit their own
file to grant themselves levels or keys. This is accepted deliberately: it is a private friends'
server, and a player who edits their own character is a social problem rather than an engineering
one. No server-side character store will be built for this Run (ADR-0010).

**A server-only backup cannot restore progression.** Because those stores are client-owned, the
server's backup captures the world, the admission lists and the biome cache — not characters.
Restoring the world onto a fresh install returns the *world*; each player's character is restored by
Steam Cloud or by their own copy (`scripts/backup-world.sh`, `docs/wiki/operations.md`).

**Two gates refuse the same actions.** Character level and personal keys both hook crafting and
equipping, so a player can satisfy one gate and be refused by the other. This is visible as a refusal
without an explanation of which gate fired.

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
