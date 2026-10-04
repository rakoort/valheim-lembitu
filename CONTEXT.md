# valheim-lembitu

A private, modded Valheim server for one invited group, run as an open-ended **Run**.
This file is the project's glossary: what the words mean when we use them in tickets, ADRs, code and
player-facing text. The stack itself is in [docs/modstack.md](docs/modstack.md); decisions are in
[docs/adr/](docs/adr/).

## Language

### The group

**Run**:
The period the server is open for play, from an announced start date. Open-ended, but every system
is sized for an actively playing group to kill the last boss in about one month (ADR-0019).
_Avoid_: season, wipe cycle, campaign

**Shakedown**:
The period before the Run, played by real players on a world that will be discarded. Characters,
progress and the world carry no promise of survival, which is what makes it the right place to
settle rules and to change a decision that the Run would freeze.
_Avoid_: beta, test run, pre-season, soft launch

**Roster**:
The invited players. Now an informal idea rather than an enforced one: the server is public and
password-protected, so admission is whoever holds the password, not a list. A player cap of twenty
bounds how many may be connected at once.
_Avoid_: playerbase, community, whitelist

**Pack**:
The set of mods and versions a player installs. During development it is a candidate; after
acceptance it is frozen for the run. A run client using anything else is a support problem, not a variant.
_Avoid_: modpack, profile, loadout

### Guilds and parties

**Guild**:
A named group of three to five players with ranks, a shared vault, guild chat, its own start region
and land it claims. The membership that owns things: land, vault, wards and guild progress. Guilds
are rivals and cooperators at once (ADR-0019).
_Avoid_: clan, tribe, team, faction

**Guild rank**:
A named tier inside a guild that carries permissions such as ward access, vault access and inviting.

**Party**:
An intentional, invite-only group of up to eight players that may mix guilds. It exists to share a
hunt: the killer's party members within 100 m of a kill split its XP, and members see each other on
the map, nothing else. Being in a party never waives that proximity. Temporary by nature, and never
the answer to "who owns this".
_Avoid_: group, squad, raid group

**Ward**:
A buildable claim that controls who may build, open and use things inside its radius, resolved
against guild membership and rank.
_Avoid_: territory, protection zone

**Guild territory**:
The square of land a guild claims around its banner, where only permitted members may build or use
things. The base safety a guild earns later in the Run lives here.
_Avoid_: claim, zone

**Market**:
The single server-wide place where players sell items, post buy orders and settle trades while the
other side is offline. Remote by design, because players log in at any time.
_Avoid_: trade post, auction house, shop

### Progression

**Progression pillar**:
One of the seven systems that make a character or guild stronger: class level, talents,
professions, gear tiers, boss powers, guild progression and magic schools (ADR-0019).
_Avoid_: power curve, progression system

**Axis**:
The kind of power a pillar owns, such as base attributes, playstyle perks or crafting efficiency.
Pillars prefer to own separate axes; overlap is accepted where a mod is well built and its overlap
can be tuned (ADR-0020).

**Class**:
The role a character chooses at the Oathstone, such as Mage, Ranger or Hunter. It decides which
talents, abilities and companions are available. A character levels one class at a time.
_Avoid_: job, profession, build

**Oathstone**:
The stone near the starting sacrificial stones where a character chooses a class, buys talents and
changes their Calling. Reaching it from a guild's start is the first journey of the Run.

**Class level**:
The active class's XP ladder, earned from kills, which grants one talent point per level. Death
costs half the progress into the current level, never a level. Respecing or switching class starts
the character over at level 1.
_Avoid_: character level, MMO level, rank, XP level

**Talent**:
A perk bought with a talent point from the active class's tree. Changing talents means a respec,
which costs the class level.
_Avoid_: skill (that word is Valheim's own skills)

**Profession**:
One of eleven non-combat skills in three categories: Craft (Blacksmithing, Herbalist, Cooking),
Land (Mining, Wood Cutting, Farming, Fishing, Animal Handling) and Road (Exploration, Sailing,
Hauling). Anyone can practise any profession; specialists are better at it (ADR-0021).
_Avoid_: class, job, trade skill

**Calling**:
A character's four focus professions: two from Land, one from Craft and one from Road. A Calling
is a supply chain the player builds, and the way a guild divides its work.
_Avoid_: class, role, build

**Focus**:
A profession inside a character's Calling. It levels at full speed to 100, while every other
profession follows the steep curve, and it keeps its XP when the character dies. Dropping a focus
sets that skill to what it would have been without the focus, deaths included.
_Avoid_: specialisation, main, primary

**Shadow level**:
The hidden level a focus profession carries: what the skill would be without the focus, earning at
the steep-curve rate and draining on death like a non-focus skill. Dropping the focus sets the skill
to it (ADR-0021, ADR-0022).

**Profession ladder**:
The level a profession needs to craft what it makes, ten per biome of the item's materials, from
none in the Meadows to 70 in the Deep North. Each step is a **rung**. Only crafting is gated; anyone
may use what a specialist made (ADR-0023).
_Avoid_: master recipe, recipe tier, gate level

**Gear tier**:
A magic item's rarity and the effects rolled on it.
_Avoid_: item power, loot tier

**Personal key**:
A boss or progression unlock stored per character, not in world state. Killing a boss awards it to
every player present at the kill and nobody else; guilds do not share keys. A biome's key is needed
both to craft and to equip that biome's gear (ADR-0005, ADR-0019).
_Avoid_: global key, world key, boss flag

**World key**:
Valheim's own world-wide progression flag. The thing personal keys deliberately replace, and this
server writes none.

**Skill floor**:
The level at or below which death does not drain a Valheim skill, raised by each personal boss key.
It protects progress from death; it never raises a skill, so it is not a catch-up mechanism.

### Conflict

There is no PvP on this server (ADR-0019). Players never damage each other, and rivalry between
guilds plays out through progress, territory and the Market.

**Tombstone**:
The container a character's death leaves behind, holding whatever vanilla death rules take. Getting
it back is the corpse run, one of the costs of dying.
_Avoid_: grave, corpse, gravestone, headstone

### The world

**Launch world**:
The world the run is played on, created once with the launch configuration and the world-permanent
mods already installed.

**World-permanent mod**:
A mod whose content is written into the world save — locations, dungeon rooms, vehicles — so it must
be installed before the launch world is created and can never be removed during the run.
_Avoid_: world-gen mod, sticky mod

**Karma**:
Regional pressure: an area where players kill heavily grows more dangerous over time, which pushes
players to move on rather than farm one spot.

**Enforcer**:
An elite, modifier-carrying creature that appears as a hunt event in the open world or a dungeon,
worth a group's effort. The stand-in for a game master.

**Siege**:
Oathbound's raid: a staged attack on an outpost (a portal, or a crafting station with six or more
pieces nearby) that ends when its commander dies. Sieges replace vanilla's random raids and scale by
the outpost's biome, never by headcount (ADR-0020).
_Avoid_: raid event, invasion

**Creature modifier**:
An extra trait a creature can spawn with, such as armoured, enraged or an elemental infusion. The
main knob for fine-tuning difficulty.

**Tuning target**:
The number of players a fight is balanced for: eight for bosses, two for ordinary creatures. Fixed,
never scaled by how many players are nearby (ADR-0019).
_Avoid_: player scaling, headcount

**Enforced config**:
The deliberate deviations this project pins in a mod's generated configuration, and nothing else: a
file there holds only the entries the Run chose, not a copy of what the mod wrote. An upstream
default is not a decision, so a setting the project cares about belongs here even when the default
already matches.
_Avoid_: server settings, config overrides, the overlay

**Difficulty tier**:
The biome level preset that decides what level a creature spawns at, and through it how much health
a boss has. It is one setting for the whole Run, not a per-creature value, and it is not a
progression pillar: players do not advance through tiers.
_Avoid_: level preset, difficulty, boss scaling

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
