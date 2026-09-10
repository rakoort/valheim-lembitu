# valheim-lembitu

A private, modded Valheim 1.0.7 server for one invited group, run as a fixed three-month **run**.
This file is the project's glossary: what the words mean when we use them in tickets, ADRs, code and
player-facing text. The stack itself is in [docs/modstack.md](docs/modstack.md); decisions are in
[docs/adr/](docs/adr/).

## Language

### The group

**Run**:
The three-month period the server is open, with an announced start and end date, optionally
extended while interest lasts.
_Avoid_: season, wipe cycle, campaign

**Roster**:
The invited players, whitelisted on the server. Fifteen people against a player cap of twenty.
_Avoid_: playerbase, community

**Pack**:
The pinned set of mods and versions a player installs. One pack for the whole run; a client running
anything else is a support problem, not a variant.
_Avoid_: modpack, profile, loadout

### Clans

**Clan**:
A named group of players with roles, private chat and its own friendly-fire rule. The only
membership concept in the project — nothing else answers "is this player my ally".
_Avoid_: guild, group, party, team, tribe

**Clan role**:
One of Leader, Officer or Member, held in a player's primary clan.

**Guest clan**:
A second, persistent clan connection a player holds alongside their primary membership. While it is
active it is the clan used for chat, HUD, pings, shared positions and friendly-fire checks.
_Avoid_: secondary clan, alliance

**Ward**:
A buildable claim that controls who may build, open and use things inside its radius, resolved
against clan membership.
_Avoid_: territory, claim, protection zone

**Trade Post**:
A clan's single buildable trading interface. What players see; the contracts and balances behind it
are server records, not chests.
_Avoid_: market, shop, auction house

**Contract**:
A standing offer posted at a Trade Post: goods wanted, price paid. Payment is held from the moment
it is posted, and it can be filled by another clan while its author is offline.
_Avoid_: order, listing, trade, offer

**Escrow**:
The payment a posted contract holds until it is filled, expires or is cancelled. A server-side
balance, never coins in a container.

**Mailbox**:
The per-player queue that delivers filled-contract goods and returned escrow at next login. How the
project makes trade work between players who never share an evening.
_Avoid_: inbox, courier, delivery box

### Progression

**Power curve**:
A system that makes a character stronger over time. The project runs exactly two: character level
and gear.
_Avoid_: progression system, build system

**Character level**:
The personal XP ladder and its attribute points. The first power curve.
_Avoid_: MMO level, rank, XP level

**Gear tier**:
A magic item's rarity and the effects rolled on it. The second power curve.
_Avoid_: item power, loot tier

**Contribution**:
The share of a creature's fight a player earned, by damage dealt and, at a reduced rate, damage
taken. The rule that decides who gets XP and keys from a kill.
_Avoid_: participation, tagging, presence, credit

**Personal key**:
A boss or progression unlock stored per character, not in world state. Killing a boss advances the
players who earned it and nobody else.
_Avoid_: global key, world key, boss flag

**World key**:
Valheim's own world-wide progression flag. The thing personal keys deliberately replace; several
adopted mods still read it, which is why the progression bridge exists.

**Progression bridge**:
Our plugin that answers other mods' progression and creature-level questions from per-character
state, so adopted mods see personal keys and character levels instead of world keys and raw stars.
_Avoid_: compatibility shim, patch layer

**Forsaken power mastery**:
The permanent, level-by-level effects a player's attuned forsaken power grants, earned by boss
kills.
_Avoid_: power level, blessing

**Banked XP**:
The doubled-XP pool that accrues while a player is offline and drains as it is spent. The catch-up
mechanism for people with a few hours a week.
_Avoid_: rest XP, bonus pool

### The world

**Launch world**:
The world the run is played on, created once with the launch configuration and the world-permanent
mods already installed.

**World-permanent mod**:
A mod whose content is written into the world save — locations, dungeon rooms, vehicles — so it must
be installed before the launch world is created and can never be removed during the run.
_Avoid_: world-gen mod, sticky mod

**Karma**:
The regional pressure that rises as players kill creatures in an area, strengthening later spawns.

**Enforcer**:
A high-level, modifier-carrying creature that Karma summons, in dungeons or the open world. The
project's stand-in for a scheduled event, since there is no game master.

### Mods

**Adoption**:
Installing an upstream mod at a pinned version and verifying it, without taking ownership of its
source.
_Avoid_: dependency, third-party install

**Fork**:
Upstream source vendored under `src/forks/`, ported by us and maintained by us, because upstream has
no working 1.0.7 build.
_Avoid_: patch, vendored mod, port

**Pin**:
The exact upstream version a mod is fixed at for the run. Pins are chosen once, before the launch
world exists, and then frozen.
