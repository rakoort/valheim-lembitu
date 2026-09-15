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

**Character level** is an XP ladder with attribute points (WackyEpicMMOSystem). Experience comes from
kills and activities, and levels are spent on attributes.

**Gear** is magic items, rarities, effects and enchanting (EpicLoot), plus bounties.

**Gear is gated by character level, not by world progress.** `WackyItemRequiresSkillLevel` refuses to
craft or equip the chest, legs and helm of each armour tier past bronze until the character reaches a
level: iron at 20, wolf at 35, padded at 50, carapace at 65
(`config/enforced/WackyMole.ItemRequiresSkillLevel.yml`). The intent is that a clan cannot hand a
newcomer endgame equipment (ADR-0005). Those thresholds are a starting point for playtest tuning,
not a settled balance decision.

**Loot gating reads the player, not the world.** EpicLoot's drop limit is set to
`PlayerMustKnowRecipe`, so magic drops are gated on what the *requesting player* knows rather than on
world progression (`config/enforced/randyknapp.mods.epicloot.cfg`). Every other gating mode in that
setting reads world keys, which this server never writes — see "Personal keys" below.

- Register: *Intended*. Character level, attributes and both gates are configured and their
  mechanisms are known from the mods' own source; no client has been observed earning a level,
  being refused a recipe, or receiving a gated drop on this pack.

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
- Progression gates more than gear. Key-locked: equipment, crafting, guardian powers (forsaken
  powers), and boss summons. Deliberately not key-locked: equipment repair, building, building
  repair, cooking and eating — the overlay pins those *off* against a mod default that turns them on,
  because ADR-0005 says a character's progression must not start refusing them.
- Register: *Intended*. The gates are enforced configuration; a boss kill awarding a key to a
  present player has not been observed on this pack, and #13/#10 own that observation.

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

## PvP and death

**PvP is each player's own flag.** Every biome rule is `PlayerChoose`, so the server never forces PvP
on anyone and Wards follow the biome rule (`config/enforced/Turbero.PvPBiomeDominions.cfg:16-32`).

**Death rules differ by whether you opted in.** The server pins both sides, because the PvE side is
the rule for everyone who has not opted in and an upstream default flip must not change it silently:

| | Unflagged (PvE) | Flagged (PvP) |
| --- | --- | --- |
| Keep equipped items on death | no | **yes** |
| Keep hotbar items on death | no | **yes** |
| Loot another player's tombstone | no | **yes** |
| No items lost on death | off | off |

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
