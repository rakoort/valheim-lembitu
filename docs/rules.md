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

## The one power curve

There is exactly one way a character gets stronger: **gear** (ADR-0014). Every other candidate was
cut, because each was a multiplier landing on the same damage number, tuned by a different author
against vanilla. Character level was the second curve until 2026-09-17, when it left with the mod
that provided it; what stands beside gear now is a gate on it rather than a second ladder.

**What left, and what it costs a character.** WackyEpicMMOSystem and its companion gate mod are
gone. A character's level and attribute points stop applying, so the health, stamina and damage
bought with them go too — and ordinary creature health was halved in the same change so the
removal is not a difficulty increase nobody chose. The XP drinks, the three XP meads and
`Mob_chunks` were that mod's own items, so any sitting in an inventory or a chest disappeared the
first time it loaded without the mod. Nothing else about a character changed: personal keys,
vanilla skills and everything worn or carried are untouched.

**Gear** is magic items, rarities, effects and enchanting (EpicLoot). Bounties, treasure maps,
gambling and the secret stash are **off**: Adventure Mode was disabled on 2026-09-16 because named
elites with health multipliers and a trader casino read as a different game.

**Vanilla skills are not a second curve.** They run 0 to 100 as in vanilla and drain by a percentage
on death. The one deviation: the drain floor rises by 10 for each boss key a character holds, so a
veteran loses less to a death than a newcomer, while the gain ceiling stays at 100.

**Gear is gated by personal keys, not by world progress and no longer by a level.** World
Advancement Progression refuses to equip or craft an item whose materials belong to a biome the
character has not unlocked, per personal key — see "Personal keys" below for what earns one. The
intent is unchanged from when a level threshold did it: a clan cannot hand a newcomer endgame
equipment. What is gone is the second gate, the armour thresholds at levels 20, 35, 50 and 65;
material biome is now the whole answer.

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

- Register: *Intended*. Every value above is decided and none is measured in play. #68 applies them
  and #73 the effect thinning. #72, which owned the XP question, is closed by #80: there is no XP.

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

**Custom ships are closed to players, from 2026-09-17.** ValheimRAFT's hammer pieces are registered
disabled for anyone who is not an admin, so no new vessel can be built
(`config/enforced/zolantris.ValheimRAFT.cfg`). Anything already afloat still works. The mod stays
installed rather than removed for the reason in the paragraph above: its vessels are written into
the world save, so deleting the mod would take every ship, its cargo and anyone standing on it.
Whether the mod leaves the Pack at all is #82.

**The night can be voted away.** One player getting into bed raises a prompt for everyone; once
half the connected players are in bed or sitting down, the night is skipped
(`config/enforced/ArgusMagnus.ServersideQoL.JustSleep.cfg`). Sitting counts because a bed for
everyone is not always to hand. Half is a deliberate number: the package asks for everyone by
default, which on a twelve-player evening means never (#83).

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
  play belongs to #13 and #10. #26 owns ValheimRAFT's vehicles.

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

**PvP is each character's own stance, and today it is still a button.** Every biome rule is
`PlayerChoose`, so the server never forces PvP on anyone and Wards follow the biome rule
(`config/enforced/Turbero.PvPBiomeDominions.cfg:16-32`). Nothing restricts where or how often a
player flips it, and only a five-minute post-death grace slows them.

**What the stance becomes, decided 2026-09-16 and not yet built (#67).** A stance may be changed
only within 20 m of the sacrificial stones — the circle of boss power stones at the spawn point —
or inside a Ward that is enabled and claimed by the character's own clan, primary or Guest as
`ClanApi` resolves it. Both directions cost that journey: dropping a stance is no freer than taking
one up, which is what makes it a stance rather than a shield. It survives logout and death, because
the server keeps it per character rather than on the player's ZDO (ADR-0013), and the server
re-asserts its record and logs the attempt when a client's flag disagrees. There is no admin
bypass. Refusal is visible: the toggle still takes the click and a centre message names where the
stance can be changed. Vanilla's ten-second post-combat gate and the five-minute post-death grace
both stay as they are.

- Register: *Decided, not built*. The behaviour exists in no published mod — a survey of all 11,269
  Thunderstore Valheim packages on 2026-09-16 found neither the place gate nor victim-scoped
  tombstone access — so the run writes it (ADR-0012).

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
player's tombstone, which is the opposite of what the run wants. Observed by the owner, 2026-09-16.

**What tombstone access becomes, decided 2026-09-16 and not yet built (#67).** Access follows the
dead character, not the opener. An unflagged character's tombstone may be opened by that character
and by the clan that `ClanApi` says was active at the moment of death, recorded on the tombstone
when it is created so later roster changes cannot grant or remove access. A flagged character's
tombstone may be opened by any flagged player, so spoils require standing in the same danger and a
permanently unflagged player cannot farm graves from safety. Only the killer is not expressible:
PvPBiomeDominions patches `Player.CreateTombStone`, which takes no killer.

The tombstone still has to exist for any of it to matter, so no-item-loss stays off in both columns.
PvPBiomeDominions is the only authority on what a death takes: AzuExtendedPlayerInventory, which
owns the extra slots, has no death rules of its own, so nothing competes with it.
What happens to items in the extra equipment and quick slots on death follows from two assemblies
and is not yet confirmed in play. AzuEPI raises the grave's height in its
`Inventory.MoveInventoryToGrave` prefix, so extra-row items do reach the tombstone;
PvPBiomeDominions keeps an item only when it is `m_equipped`, or when `m_gridPos.y == 0`, which is
the vanilla hotbar row alone. Armour worn in an equipment slot is equipped, so a flagged player
keeps it; a quick slot sits on a row below the backpack, so its contents drop even though the HUD
shows them beside the hotbar. Read from `PvPBiomeDominions.dll` 1.7.8 and
`AzuExtendedPlayerInventory.dll` 2.4.14, decompiled 2026-09-16. One character dying twice, once
flagged and once not, turns it into a measurement; #67 carries that.

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
