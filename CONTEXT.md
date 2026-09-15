# valheim-lembitu

A private, modded Valheim server for one invited group, run as a fixed three-month **run**.
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
The set of mods and versions a player installs. During development it is a candidate; after
acceptance it is frozen for the run. A run client using anything else is a support problem, not a variant.
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

**Trade Post** (deferred, not built):
A clan's single buildable trading interface. What players see; the contracts and balances behind it
are server records, not chests. Deferred for this run and safe to add mid-run, because the records
never enter the world save (ADR-0006).
_Avoid_: market, shop, auction house

**Contract** (deferred, not built):
A standing offer posted at a Trade Post: goods wanted, price paid. Payment is held from the moment
it is posted, and it can be filled by another clan while its author is offline.
_Avoid_: order, listing, trade, offer

**Escrow** (deferred, not built):
The payment a posted contract holds until it is filled, expires or is cancelled. A server-side
balance, never coins in a container.

**Mailbox** (deferred, not built):
The per-player queue that delivers filled-contract goods and returned escrow at next login. How the
project would make trade work between players who never share an evening.
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

**Personal key**:
A boss or progression unlock stored per character, not in world state. Killing a boss advances the
players who were there for it and nobody else: the adopted World Advancement Progression mod awards
the key to every player within a hundred metres of the chunk host when the boss dies. Presence, not
measured damage, is what earns it — cooperation between clans is the point (ADR-0010).
_Avoid_: global key, world key, boss flag

**World key**:
Valheim's own world-wide progression flag. The thing personal keys deliberately replace, and this
server writes none: global keys are blocked outright. Adopted mods that used to read them are
configured to read the player instead, which is why EpicLoot gates loot on the requesting player's
known recipes.

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
Upstream source maintained by this project because no official build works on the game we run, or
because upstream does not publish the source of the release we need. Wanting different behaviour is
not a reason: configuration and enforced config reach that without owning someone else's code
(ADR-0003). One fork remains, MaxPlayerCount.
_Avoid_: patch, vendored mod, port

**Pin**:
The exact upstream version selected for a mod. A development pin identifies a candidate for
verification, not a freeze; run pins are the accepted versions fixed before the launch world exists.
