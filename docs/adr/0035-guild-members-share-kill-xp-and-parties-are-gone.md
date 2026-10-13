# ADR-0035: Guild members share kill XP, and parties are gone

Date: 2026-10-11
Status: Accepted (owner); shipped in Pack v21 (2026-10-13), two-player acceptance still required
Amends: ADR-0019 (parties), ADR-0020 (SocialSystem supplies parties), ADR-0022 (a kill pays the
killer's party), ADR-0027 (the first party opens the guide's groups page)

## Context

The Run had two groupings. A guild owned land, vault and wards; a party, from M2Valheim/SocialSystem,
was a second, invite-only group of up to eight that shared kill XP and map positions (ADR-0019,
ADR-0022). Guilds hold three to five players, so in practice the people who hunt together are a
guild. Players had to form a party on top of the guild before a hunt to share XP, and SocialSystem
added its own friends list, direct messages, party chat, ready checks and two windows on P and O.
The owner asked to remove the party system, to show the other guild members on screen all the time,
and to share XP between guild members automatically, but only by proximity.

## Decision

**Parties are gone.** SocialSystem leaves the Pack and the server. Its friends list, direct
messages, party chat, ready checks, party map markers and party frames leave with it. Guild chat
and guild map positions stay, because Northarun/Guilds supplies them.

**A kill pays the killer's guild members near the kill, automatically.** Nothing to form or accept:
being in the same guild is enough. The rule is ADR-0022's party rule with the guild as the group.
Oathbound's `SharedExperience` stays off, so the server credits the owner of the killing blow. The
killer always counts, wherever they stand. Each other member of the killer's guild counts if they
are connected, alive and within 100 m of the creature when it dies, measured on the server. A
member who is not near the kill earns nothing from it and does not count in the split. A guildless
killer, or a killer with no guild member in range, earns the kill in full. Players who hit the
creature but are not in the killer's guild earn nothing from it.

**The bonus is unchanged.** With n members in range, the killer included, the guild shares the
kill's XP × (1 + 0.5 × min(1, (n − 1) / 3)), split equally and rounded at random: 100% for one, 58%
each for two, 44% each for three, 37.5% each for four and 30% each for five.

**Membership comes from Guilds' server store.** `Lembitu.Oathbound` reads the killer's guild from
Northarun/Guilds on the server by player ID, never from anything a client reports.

**An always-on guild HUD.** `Lembitu.Guilds` shows every other member of the player's guild on the
left of the screen whenever the game HUD is shown: name, health and distance for members online,
dimmed for members who are dead or offline. The server sends each guild's member list and their
health and position only to that guild's members. There is no switch to hide it; the vanilla
hide-HUD key hides it with the rest of the HUD.

**The guide follows.** The guide's `groups` page now opens once on a character's first guild
rather than first party, and its text describes guild XP sharing.

## Consequences

- Guild members never lose XP for forgetting to party up, and a guild hunt shares by default.
- Hunting across guilds shares no XP: the killer earns the kill and a helper from another guild
  earns nothing. Inter-guild cooperation rests on the Market and on trade between specialists.
  Two guildless friends who want to share XP found a guild; founding is free.
- Boss keys and boss-power mastery are unchanged: they were always earned by presence within 100 m,
  not by grouping.
- The P and O keys are free. Map positions come from Guilds alone.
- Two-player acceptance is still owed, as it was for parties: a kill split between two guild
  members in range, a member outside 100 m left out, and the HUD showing a second member's health
  and distance. A single client can prove only that the features switch on and that an offline
  member shows dimmed.
