# ADR-0036: The Chronicle — the web map and Discord record what happened, and colour means a claim

Date: 2026-10-11
Status: Accepted (owner, web map grilling of 2026-10-11)
Amends: ADR-0019 (guilds are rivals and cooperators at once), ADR-0003 (the web map fork is ours for
the Run)
Issues: #117, #118, #119, #120 (Milestone 8)

## Context

The web map showed a guild only as a suffix on a player's name, and coloured each player by a hash
of the name (`src/forks/ValheimWebMap/web/app.js:178,505-509`). Its side panel listed hours played
and death counts per player. Discord had five senders and no pattern: `#status` carried the live
status message, ServerManager's server events and plain restart countdowns; `#activity` carried
ServerManager's joins, leaves, jokey death lines and "final blow" boss posts; its raid posts are
likely silent, because Oathbound replaces vanilla's random raids
(`Plugin.cs:3019-3053`, decompiled `WarriorRpg.dll`). The guild channels received nothing.

The owner asked to make the map more interesting around guilds, then set the direction during the
grilling. The server should favour collaboration over competition: the game should be hard enough
that working together pays, and competition is welcome only where a player with more free time
cannot claim everything by playing more. Guilds are the central concept. Ground is claimed only
through the guild claiming mechanics: start regions, banners, wards and outposts.

Facts from `Guilds.dll` 1.5.1 (sha256 `1e642107…96e4ce44`) and Oathbound's `WarriorRpg.dll` (sha256
`ea2f605a…434f28ef`), decompiled with ilspycmd 11 on 2026-10-11:

- Guilds sends every connected client a roster of all guilds: name, tag, colour, emblem, leader,
  description, ranks, level, banner position and territory size, upgrades, buildings and
  diplomacy (`GuildServer.cs:841-876`, broadcast to everyone at `:919`). The game draws a territory
  border only within 250 m of it (`Territory.cs:325-327`).
- A guild's colour is one of twelve palette entries chosen in game (`Guild.cs:17`,
  `Palette.cs:7-11`). Relations are neutral, ally or war (`Relation.cs`).
- A guild-bound ward carries the `Guilds_WardGuild` key (`WardPatches.cs:9`). An outpost carries
  `oathbound.siege.state`, and Oathbound finds them through `ZDOExtraData.GetAllZDOIDsWithHash`
  without scanning the world (`Plugin.cs:3033`).
- Guild pins, the vault, coins and the message of the day are guild-private (`Guild.cs:21-33,59`).
- Guilds records a guild's own first kill of each boss and keeps a log of 200 entries per guild
  (`Guild.cs:9,57`), so it is not a lasting world record.

## Decision

**Collaboration first.** This amends ADR-0019's "rivals and cooperators at once". Guilds cooperate
first; rivalry stays friendly and shows only through what guilds build and claim. Nothing public
ranks guilds or players, and nothing counts or totals what they did, so time played alone never
reads as standing. A separate concept review will test the other systems against this.

**Colour means a claim or a build.** A guild's colour, a muted version of the one it chose in game,
marks start region claims, guild territory, guild-bound wards and outposts, and what its members
built or steer: players, ships, carts and the lines between paired portals. Exploring, killing and
travelling never colour ground. Anything without a guild is grey.

**The Chronicle.** The Run's record of what happened in the world, drawn in one neutral ink:

- every boss fall, naming the guilds and players within 100 m and who gained a personal key;
- the first entry into each landmark: dungeons, traders and boss altars;
- every Siege held, leaving a scar on the outpost that names the defending guilds;
- guild milestones: founded, start region claimed, banner raised or lost, alliance or war;
- deaths.

Each place shows its last ten entries, and the first is never highlighted. Credit appears in text,
never as colour. Every entry has a link that opens the web map on it: the map flies there, dims the
other layers and opens the place's card with that entry highlighted. The Chronicle starts at
deploy; nothing earlier is imported. It is kept for the whole Run in the map's data directory and
travels with the hourly backup.

**The web map** stays public. Its layers are the claims above with live Sieges, ships and carts,
the portal network (lines only, portal names hidden), tombstones still awaiting a corpse run, and
time-of-day shading with the wind direction. Clicking a guild territory or banner opens the full
public guild card: name, tag, emblem, description, leader, members with who is online, start
region, level, upgrades, buildings, allies and wars. The side panel shrinks to online players
grouped by guild, plus layer switches; the History tab and per-player death counts leave. The look
gets a light Valheim pass; the header keeps its content.

**Discord** gives each channel one purpose and types every event with an icon, a colour and a fixed
layout:

- `#world`, renamed from `#activity`: Chronicle entries other than deaths, Siege calls edited live
  until held or abandoned, and one morning digest of the landmarks entered the day before.
- `#deaths`: one card per death with a link to the tombstone, edited when the corpse run succeeds.
- Each guild's channel: Siege calls that ping that guild's role, guild progress (level, upgrades,
  achievement tiers, buildings) and member changes.
- `#status`: only the live status message, which names the next restart and shows restarting during
  it. (Revised 2026-10-12, owner: restart countdowns stay in game rather than being edited in; this
  part and ServerManager's move to `#admin-alerts` shipped ahead of the rest.)

A card carries a mini-map image of the spot rendered by the map server, and the event link. Texts
are short, factual and a little Norse. Joins and leaves are no longer posted, because the live
status message lists who is online. ServerManager keeps its server events, moved to
`#admin-alerts`; its activity events stop.

**Who writes what.** The map plugin records the Chronicle and a delivery journal on its data mount.
A host-side relay posts and edits the webhook messages, as `scripts/discord-status.py` does, so
webhook secrets never enter the game container. Events for a guild's own channel never reach the
map's public API.

## Rejected

- **Races and standings**: boss firsts by guild, each guild's share of the explored world, guild
  level rankings. All of them reward hours played.
- **Landmarks coloured by the finder's guild.** The busiest guild would paint the map.
- **A players-only map.** Rivals are players, so a password hides nothing from them.
- **A channel per event type** (`#bosses`, `#sieges`, `#guilds`, `#discoveries`). Too many to follow;
  typed cards in two channels separate events instead.
- **Importing earlier events** from `#activity` and Guilds' logs. The dates are sure, but who was
  present is not.
- **Event links that replay where everyone stood.** Focusing the entry is enough.
- **Portal names on the map.** They are free text that players never meant to publish.

## Consequences

- ValheimWebMap is ours for the Run (ADR-0003, 2026-10-11 amendment). Its reflection into Guilds
  grows from the guild name to the roster fields, and it reads Oathbound's siege keys, so a Guilds or
  Oathbound bump re-checks the map as it does `Lembitu.Guilds`.
- Hours played and death counts leave the public page. The server keeps recording sessions for
  operations.
- `config/discord/layout.json`, `scripts/servermanager-discord.py` and `docs/wiki/discord.md` change
  with the Discord work.
- `CONTEXT.md` gains **Chronicle**, and its Guild, Web map and Discord server entries follow this
  decision.
- A concept review is owed: guilds at the centre, collaboration first, and no advantage from free
  time alone, tested against classes, professions, the Market and guild progression.
