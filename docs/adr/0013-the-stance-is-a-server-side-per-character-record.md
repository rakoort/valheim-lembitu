# ADR-0013: The stance is a server-side per-character record

A player's PvP stance is stored by the server, in a plugin-owned file inside the save tree, keyed by
character. The server is the only authority on it: on spawn it writes the recorded stance onto the
player, and when a client's live flag disagrees with the record it re-asserts the record and logs the
attempt naming the character.

Vanilla keeps the flag nowhere durable. `Player.SetPVP` writes `ZDOVars.s_pvp` on the player's own
ZDO and `PlayerProfile` stores nothing, so the flag is already off at every login. With the stance
place-bound in both directions (#67), that default is a hole rather than a neutral starting point: a
flagged player could drop their stance by logging out instead of travelling to the sacrificial stones
or their clan's ward, which is the same button the rule exists to remove.

The alternative was the character file, where the run keeps character level and personal keys. It was
rejected because characters are client-owned (ADR-0010): a player could edit their own stance and
bypass the place gate entirely, and the rule would hold only for the honest.

## Relationship to earlier decisions

ADR-0010 accepts that progression lives in the character save with no tamper resistance, and that
acceptance stands: level, XP and personal keys stay where they are. The stance is different in kind.
It is not a power a player earns but a permission other players are exposed to, so its integrity is
someone else's safety, not only the owner's own progress.

ADR-0008 stays intact: the stance record keys on the identity Clan already resolves, and membership
questions go to `ClanApi` rather than to identifier comparison.

## Consequences

The save tree gains a fourth server-side store beside `permittedlist.txt`, `adminlist.txt` and
`bannedlist.txt`. `scripts/backup-world.sh` must capture it, so one hourly archive holds the world and
the stances together and a restore brings back a consistent pair; a backup that omits it would restore
a world whose players are all unflagged.

The record is per character, so a second character starts unflagged and a player may keep a flagged
main and an unflagged alt. That matches every other per-character rule in the run and is a known,
accepted scouting loophole.

The file starts empty. Nothing is written until a player first sets a stance, so every entry in it is
a deliberate choice made at a permitted place, and the boot that installs the plugin leaves every
existing character unflagged.
