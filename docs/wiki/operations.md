# Server operations

This page records how to deploy the server's configuration and plugins, and separates those implemented tools from the recovery and launch requirements for the Run. The operating model is a public, password-protected server running one accepted Pack for a three-month Run (`CONTEXT.md:3-23`).

## Decisions

**The Run has a defined window, not continuous upgrades.** Announce its start and end; an extension
is optional while interest lasts. The server is public and password-protected, and membership is
whoever holds the password (`CONTEXT.md:12-28`; `docs/adr/0007-frozen-game-version-and-pinned-pack.md:56-100`).
The player cap was twenty through Pack v16, held by the MaxPlayerCount fork, which never proved an
eleventh simultaneous connection (`docs/modstack.md:245-248`). From Pack v17 it is vanilla's ten and
the fork leaves (ADR-0007, 2026-10-07 amendment).

**Enforced configuration is the server's deliberate deviation from mod defaults.** It belongs in server-locked configuration, not a player's file. The committed overlay is `config/enforced/`; it is applied to the files the mods generate on first boot. This is distinct from the package-supplied configuration seeds deployed by the installer (`docs/modstack.md:18-20`; `docs/build.md:201-230`). The current overlay owns these choices:

- Clan configuration is locked, friendly fire is off and clan positions are shared. Clan is the only membership authority; guest connections must be resolved through Clan rather than by comparing primary membership IDs. Ward and allied-player integrations use that same answer (ADR-0008).
- PvP is the vanilla player toggle. Deaths follow vanilla rules for everyone. PvPBiomeDominions was removed on 2026-10-03 at the owner's instruction; flagged-player equipment and hotbar retention, tombstone-looting restrictions, map-hiding rules and its five-minute post-death grace left with it. There is no killer-only tombstone access or replacement mechanic. Clan position sharing remains, but no overlay now forces other players' map positions hidden.
- Personal keys are enforced in `config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg`: private keys on, the world's global key list blocked, and private raids on. It also names what progression gates, which is more than gear: `LockEquipment` and `LockCrafting` (ADR-0005), `LockCooking` and `LockEating` (added by the 2026-09-16 review, amending ADR-0005), plus `LockGuardianPower` and `LockBossSummons`, so forsaken powers and boss altars follow each character's own keys. Equipment repair, building and building repair are pinned *off* against a package default that turns them on; taming is pinned off at its own default, and `AdminBypass` off so an admin plays the same run as everyone else. Every one of these locks is material-scoped, so a keyless character still cooks and eats Meadows food and builds in wood. The boat, portal and nine `[PortalUnlocking]` key names are pinned empty, which is vanilla: no key opens ore hauling, which is the `Portals hard` launch rule said a second time. The skill manager is now *on*, with the ceiling pinned at the vanilla 100 and the floor following `UseBossKeysForSkillLevel` at 10 per private key, so a character who was present for five boss kills starts a fresh skill at 50; the floor and ceiling are decided independently in the mod's own `SkillsManager.UpdateCache` (ADR-0005, ADR-0010).
- PortalRules left on 2026-10-03 at the owner's instruction; XPortal's destination list is the only portal mod, and portal access is unrestricted. DataForge and CreatureManager are locked, with their committed data files pinning an empty override state rather than silently accepting future package examples. CreatureManager additionally carries the difficulty tier: `Biome Level Preset = Hard` plus `Bosses Follow Biome Level Preset` in its `[2 - Levels]` section. The preset is primarily about ordinary creatures — it sets the level distribution for every natural spawn in a biome, and `Hard` gives roughly 40% stronger spawns than the `Easy` default (expected level 1.10 in Meadows rising to 3.22 in Ashlands) — while the earliest biomes still spawn at level 1 most of the time (90% in Meadows, 68% in Black Forest), so a new character is not softlocked. Bosses follow the same preset, so boss level and therefore boss health through `Boss.healthPerLevel` rises by biome tier: expected health ×1.05 for Eikthyr to ×2.11 for Fader, a 2.01× gradient. `Hard` is not the package default, which is why it is pinned: an upstream flip or a fresh install must not silently rebalance the run. Observed boss health and any further retune belong to #13 and #10's two-client session (`config/enforced/sighsorry.DataForge.cfg:1-7`; `config/enforced/sighsorry.CreatureManager.cfg:1-40`).
- CreatureManager also fixes difficulty against headcount. Vanilla scales every creature by the number of players standing nearby — 30% effective health and 4% damage each, capped at five — so the same boss was a different fight depending on who logged in, and a sixth player made it easier. Both percentages are pinned to zero and the count cap to one, and the difficulty is set in the level table instead: `Global.health = 2` and `Boss.health = 8`, so ordinary creatures and Enforcers carry twice vanilla health and regular bosses eight. Ordinary health was 4 until 2026-09-17, when character level left the Pack and every character lost the stats its attribute points had bought (#80). Damage is untouched at 1, so a fight is longer rather than deadlier per hit, and per-level growth still compounds on top — a level-3 Ashlands creature is 6× and a level-2 boss 12×. `levels.yml` and `karma.yml` are pinned wholesale, so a package update that retunes them is a review; their modifier tables are tuned per group (2026-10-04, see below) (`config/enforced/sighsorry.CreatureManager.cfg`; `config/enforced/CreatureManager/`).
- Gear is gated by personal keys alone. World Advancement Progression's `LockEquipment` and `LockCrafting` refuse an item whose materials belong to a biome the character has not unlocked. A second gate used to sit beside it — ItemRequiresSkillLevel's armour thresholds at character levels 20, 35, 50 and 65 — and it left with character level on 2026-09-17, taking its enforced YAML with it (ADR-0014, #80). One gate means a refusal has one explanation.
- EpicLoot gates magic drops on the requesting player's known recipes rather than on world keys, since this server writes none: `config/enforced/randyknapp.mods.epicloot.cfg` sets `[2 - Balance] Item Drop Limits = PlayerMustKnowRecipe`, and `Gated Freebuild Mode = Unlimited`, because its only other modes read world progression and would leave the roster at Meadows tier. The overlay was rebuilt from 0.14.13 defaults on 2026-10-04: drops at 0.6 of stock, shardstones 0.1, tempering can destroy items, and Adventure Mode on (bounties, treasure maps, gambling, secret stash) with five bounties per player. The enchant counts per rarity need no patch: 0.14.13's stock table matches the old #73 patch.
- DiveIn's swimming block and SkadiNet's network profile are pinned. MaxPlayerCount is 20. BepInEx gets `AppendLog = true`, so a restart preserves the previous boot's log. DiscordConnector sends no positions and refuses `@here`/`@everyone`; its lifecycle, join, leave, death and shout toggles are on. The webhook URL is a secret.

**Apply overlays after generation, not instead of generation.** Run `scripts/apply-enforced-config.sh <bepinex-config-dir>` after the server's first boot and whenever an overlay or pin changes. For `.cfg` files, the script matches the section and exact key, preserving unrelated entries and generated comments. A missing key is appended under a re-declared section; a missing target file aborts, because creating an unused filename would look like successful enforcement. Non-`.cfg` files replace their targets wholesale. A second unchanged application reports nothing to do (`docs/build.md:215-230`; `scripts/apply-enforced-config.sh:6-24,36-65,103-132`). The shell tests cover section isolation, unchanged reapplication, missing-key append, missing-target failure, data replacement and an entry outside any section. They test file transformation, not a real client's receipt of synced rules (`test/apply-enforced-config.test.sh:27-121`; `docs/modstack.md:165-183`).

**Applying by hand once was not enough, and that is measured.** On 2026-09-16 a key-by-key
comparison of the live server against the overlay found ten of forty-six pinned keys sitting at mod
defaults: the difficulty tier at `Easy` instead of `Hard`, five World Advancement Progression locks,
the skill manager, EpicLoot's drop gating, clan friendly fire, and the slot mod's keep-on-death.
Every drifted value was the package default, and a full evening of play — including the run's first
boss kill — had run under them. Nothing in the repository compared the applied result to the overlay
afterwards, so the revert was silent. ADR-0011 therefore decides that the overlay is re-applied on
every container start and verified by a drift-check command that exits non-zero on
drift and is wired into the launch path and the backup timer's service (#68 applies the review, #69
builds the verification).

**Applied state, 2026-09-16.** The review is live. `scripts/launch-server.sh restart` stopped the
container, applied 35 changed entries with nothing holding the files, started it, and the boot
that followed reported `29 plugins to load` — the same count as before — and
`Chainloader startup complete` with zero exceptions and zero unparseable config values.
`scripts/verify-enforced-config.sh ~/lembitu/config/bepinex` then answered
`enforced config verified: 163 entries match`, and a second apply reported nothing to do.
`Biome Level Preset = Hard` was read back off the running server's own file. The backup taken
before the apply is `lembitu-all-worlds-20260916T103020Z.tar.gz`, with its off-host copy on
astral-tricep.

**Historical overlay expansion — 2026-09-16.** It covered nine files and forty-six keys; that
review expanded it to twenty-seven files — eighteen `.cfg` and nine data files, 163 entries — adding
DiveIn, SkadiNet,
MaxDungeonRooms, MaxPlayerCount, DynamicLocations, BepInEx's log appending, DiscordConnector's
main settings and its notification toggles, and CreatureManager's level table. The rule that
drove the expansion: an upstream default is not a decision, so a setting the project cares about
is pinned even when the default already matches.

**A key belongs to a section, not to a name.** CreatureManager's three modifier switches read
like they live in `[5 - Modifiers]`, and `local/decisions-2026-09-16.md` records them there, but
the mod generates them in `[2 - Levels]` — `local/live-config-sections.txt` has the read-off
proof, at lines 66, 72 and 78, between the `[2 - Levels]` header at 36 and `[3 - Karma]` at 80.
The overlay pins the section the mod writes. Naming the wrong one is not an error anybody sees:
the applier appends the key under a re-declared section, the mod reads its own copy, and the
drift check then passes forever. That evidence file is why it is captured before every overlay
change: the generated file is the authority on where a key lives, never the decision note.

**A stated chance is not a rate until you know what it is rolled against.** CreatureManager's
modifier table ships 5 per modifier, which reads as "5% of creatures carry this". It is not: the
mod rolls **one modifier per group**, and `levels.yml` holds four groups — Offense, Defense,
Affliction, Special — of eight modifiers each. Each group therefore fired at 40%, and an average
ordinary creature carried about 1.7 modifiers. Stacked onto the run's flat health multiplier, a
one-star Greydwarf at 8× vanilla health with `armored`, `regenerating` and `adaptive` is a wall.
Twelve players met exactly that on 2026-09-16 and reported ordinary creatures taking eight people
to kill, while bosses were fine — bosses have their own smaller multiplier, and karma and
Enforcers are blocked during a boss fight.

Two things about the diagnosis are worth keeping. The owner's first reading was that per-player
scaling had come back, and that was checkable rather than arguable: CreatureManager writes
vanilla's own `Game.m_healthScalePerPlayer`, `m_damageScalePerPlayer` and
`m_difficultyScaleMaxPlayers` from its `[4 - Multiplayer Difficulty]` keys in a `Game.Awake`
postfix, the live server holds `0 / 0 / 1`, and the drift check matches — so headcount scaling was
already off and the flat 4× was the intended difficulty. And the fix had to miss two targets:
ordinary chances are now 0.125 each, 4 creatures in 100 — cut to 0.25 and halved again the
same day — while boss chances stay at 10
and Enforcers keep their own 10s in `karma.yml`'s `Enforcer.modifiers`, which inherits from
`levels.yml` only for a modifier it does not name. Modifiers remain the Enforcer's signature.

**Modifiers back, retuned per group — 2026-10-04.** The owner turned modifiers back on for all
three targets, and both tables are now ours. `levels.yml` gives ordinary creatures about 10 in 100
and bosses about one modifier. `karma.yml` joined the overlay wholesale and gives Enforcers about
two. deathward, regenerating, omen and blamer are excluded for every target.

**One mod keeps its config outside BepInEx, and the overlay cannot own it.** SeparateSpawns 0.1.1
calls `ModPaths.UseDedicatedConfigLayout()`, true for any headless server, and then writes to
`<game root>/config/bepinex` instead of `/config`. Putting those keys in `config/enforced/` would
merge them into a path the mod never reads while `verify-enforced-config.sh` reported success — the
exact silence ADR-0011 exists to prevent. They live in `config/dedicated/` instead, applied by
`scripts/apply-dedicated-config.sh` through the same parser, and re-applied on every deploy because
that directory is inside the tree the container re-extracts when BepInEx updates. One mod, one
mechanism, and a test file of its own; if a second mod ever needs it, that is the moment to
generalise rather than now.

**Drift is asserted, not assumed.** `scripts/verify-enforced-config.sh <bepinex-config-dir>`
compares every overlay entry against the live tree and exits non-zero on any difference, printing
`file :: section :: key` with expected and live values. `.cfg` overlays are compared key by key
inside their own section; anything else is a data file compared byte for byte; a target file the
overlay names and no mod generated is a failure, never a pass. It shares one parser with the
applier (`scripts/lib/enforced-config.sh`), so the two cannot disagree about what is enforced.

It runs in two places. `scripts/launch-server.sh run` applies the overlay, starts the container,
waits for `Chainloader startup complete` — the boot is when mods rewrite their own files, so
checking earlier races the rewrite — and then verifies, failing loudly rather than leaving a
drifted server accepting players. The backup unit runs it after each hourly capture, so a revert
between starts surfaces as a failed unit within the hour instead of next evening
(`config/backup/lembitu-backup.service`).

**Never apply the overlay to a running server — that is what undoes an apply.** Measured on
2026-09-16 while applying this very review: the applier wrote 35 entries to the live tree with
the container up, and within seconds EpicLoot logged
`Config file ... randyknapp.mods.epicloot.cfg changed on disk, reloading it`. The ServerSync-locked
mods answered a mid-session edit by writing their in-memory values back over the file. The next
drift check found 16 of the 35 keys returned to package defaults, with nothing in any log calling
it a failure. That is the silent revert of the original incident, reproduced on demand, and it
means the mechanism was never a forgotten step: it was the order of operations.

`scripts/launch-server.sh restart` is therefore the only supported way to change enforced
configuration on a live server. It stops the container, applies while nothing holds the files,
starts, waits for that boot's chainloader, and verifies. `docker restart` skips all of it.

**A value the mod cannot parse reverts the key, loudly but harmlessly.** The same apply set
`Gated Freebuild Mode = PlayerMustKnowRecipe`, which `local/decisions-2026-09-16.md` had asked
for. That key's type is `GatedPieceTypeMode`, whose members are only `Unlimited`,
`BossKillUnlocksCurrentBiomePieces` and `BossKillUnlocksNextBiomePieces`, so the server logged
`Requested value 'PlayerMustKnowRecipe' was not found` and wrote the default back. Both boss-kill
modes read world keys this server never sets, which would freeze the Freebuild effect at Meadows
pieces for the run, so the overlay pins `Unlimited`. The general rule: the enum a key accepts is
read off the generated file's own `Acceptable values` comment, never assumed from a sibling key
that happens to share a vocabulary.

**The image's updater can empty the plugin directory on a restart.** Also observed on that boot:
`valheim-bootstrap` syncs `/config/bepinex/plugins/` into the runtime BepInEx tree, and then
`valheim-updater` decided the server "was updated from Steam" and extracted BepInExPack over the
same tree, leaving `BepInEx/plugins` empty and the boot reporting `0 plugins to load`. The source
directory was untouched, so the following start restores it — but a server that boots with no
plugins is a vanilla server on a modded world, which is worse than drift. Any restart is
therefore checked for the plugin count, not only for the config.

**A mod the server cannot enforce is not a mod this project keeps.** AdminQoL taught it: none of
its twenty-nine settings is server-synced, so its defaults — no durability loss from damage or use,
no equip delay, no crafting-station roof requirement — were live for everyone and unreachable from
the server. The 2026-09-16 review dropped every client-only mod, AdminQoL and BoneMod, and withheld
the server-only ones from the client Pack (`docs/modstack.md`, "Where each mod runs"; #70).

**Deploy complete package trees into the BepInEx root.** The install loop builds maintained plugins, stages adopted packages, then runs `scripts/install-plugins.sh <bepinex-dir>`. Staging checks package hashes against `docs/modstack.lock.json`; deployment preserves `plugins/`, `patchers/` and configuration seeds, including asset-bundle manifests and nested bundle directories. The installer target is the BepInEx directory itself, not its `plugins/` child (`docs/build.md:193-208,271-296`; `scripts/install-plugins.sh:94-103`; `test/install-plugins.test.sh:62-96,199-239`).

The installer records every deployed file in `.lembitu-installed` at that root. On subsequent installs it prunes previously owned files absent from `dist/`, removing directories only when empty. A same-name foreign file is overwritten with a warning and becomes owned; unrelated foreign files survive. Old plugins-only manifests are migrated so their files remain prunable (`scripts/install-plugins.sh:105-201`; `test/install-plugins.test.sh:98-170,286-299`).

**A persisted manifest is untrusted input to a destructive step.** Pruning is driven by `.lembitu-installed` alone, so an entry that escapes the BepInEx target would make `rm` delete outside it. The installer therefore validates every entry before the first removal, naming the offending line, and the check precedes both the `.lembitu-removed` append and the manifest rewrite, so a corrupt manifest never leaves a partial prune. The policy is shared with `dist/` names and the prune ledger: a character allowlist plus a refusal of traversal shapes (`.`, `..`, leading-dot components, absolute paths), either half of which aborts the run. Both writers of that manifest are covered — the install validates each name before copying, and the plugins/-era migration validates the legacy entries before rewriting them, while the legacy file is still on disk to correct rather than deleting it first (`scripts/lib/ledger.sh:5-12`; `scripts/install-plugins.sh:94-201,220`; `test/install-plugins.test.sh:394-442`).

**Launch and recovery remain acceptance requirements.** Freeze the game and Pack together only after the same candidate passes a clean full-pack boot and a manual two-client session. Check public releases again before that gate, then control installations and disable automatic updates (ADR-0007). Keep Expand_World_Size's generation settings fixed for the world's life (ADR-0018). World Advancement Progression clears global keys on startup and belongs in the Pack before world creation. The 2026-10-03 removals do not prove that an existing world can be migrated safely; see [Pack](pack.md).

Recovery policy is rollback on the accepted versions, not an improvised mod upgrade. Through Pack v16
characters are client-owned (ADR-0010), so a server archive does not capture them. From Pack v17 the
server holds the character store (ADR-0034) and the archive captures it with the world. The
implemented capture, schedule, rotation, off-host copy and proven restore are in
[Backups](#backups--20) below (`docs/adr/0007-frozen-game-version-and-pinned-pack.md:39-40`).

### Decisions of 2026-10-07

The owner asked for the server to run like a professional dedicated server and settled the following
in a one-question-at-a-time interview. ADR-0034 records the character store; ADR-0007's 2026-10-07
amendment records the cap, the enforced Pack and admission. The research is in
[Character store](character-store.md); the Discord setup is in [Discord server](discord.md).

| Topic | Decision |
| --- | --- |
| Character store | ServerManager after a test-host trial; a player's crash loses at most five minutes, a server crash about ten, a planned restart nothing; one character per account; the server refuses a client whose mods differ from the Pack; detections logged, never acted on automatically; player logs disclosed and deleted after the Run (ADR-0034) |
| Maintenance restart | Warn in game and on the Discord server at ten, five and one minutes, run `save`, wait for ServerManager's `WorldCharacterCheckpointCompleted ... pending=0`, then stop. Daily at 06:00 Europe/Oslo and for every deploy. A restart never runs the container's updater. Today `scripts/launch-server.sh:144` is a plain `docker stop` |
| Player cap | Vanilla's ten; the MaxPlayerCount fork leaves |
| Discord | The Run's own Discord server. ServerManager's webhooks post status and activity publicly and admin alerts privately, and its bot bridges chat; DiscordConnector leaves. Channels: status, activity, announcements and Pack releases, support, one per guild made by the admin when the guild forms, and a private admin channel |
| Monitoring | Built on OdinEye plus host statistics. Alerts go to the private admin channel when the server is down or unresponsive, unreachable from outside, misses a world save, fails a backup or its off-host copy, or runs short of memory, CPU or disk |
| Backups | One hourly archive holds the world, cache, admission lists, the character store, and the Guilds, Marketplace and region-claim files, so a restore returns all of them to the same hour |
| Admission | Public with a password, shared in a members-only Discord channel; the owner is the only admin |
| Host | The game stays on astral-bicep with reserved CPU and memory (CPU shares 4096, 4 GiB reservation). The other projects' containers are not capped (owner, 2026-10-09); monitoring's resource alerts decide whether that changes |
| Web map | koenhendriks/ValheimWebMap, public with every layer: everyone's live position, heading and guild, live combined exploration, cartography-table pins, deaths and play sessions, at `https://lembitu-map.astral.ee` through a Cloudflare Tunnel with a Cloudflare rate limit; no router port opens and the game's own port 3000 stays private. The owner reversed web-map position privacy on 2026-10-09; the in-game public-position setting stays off. Carried as a fork so it draws the whole 13,250 m world (ADR-0003, 2026-10-07 amendment) |
| Pack additions and refusals | Jumpingmushroom/Tally is required, with sharing on. nbusseneau/Better_Cartography_Table is not added: its guild pins need Smoothbrain's Guilds, not Northarun's, its settings cannot be locked, and pin privacy is checked only on the client. ValMedia/OdinOnDemand is already pinned at its latest release, 1.3.0 |

Tickets: the ServerManager trial #101 and adoption #102, the maintenance restart #103, backups #104,
monitoring #105, the Discord server #106, host resources #107, the web map #108 and Tally #109.
The owner decided the next release waits for all nine: Pack v17 (#99) ships only once #101 to #109
are done.
Two-player checks in #101, #106 and #109 run in one owner session with two separately licensed
Steam accounts before the release, from a checklist prepared at the end of the build. The Tickets
are tracked on `master` without the `nt` readiness gate.

## Launch provisioning — #19

**Admission is by password alone; there is no whitelist.** The owner's decision on 2026-09-15 is a
public, password-protected server: friends find it in the browser and join with the password. This
departs from #19's "whitelisted to the invited roster" and from the Roster framing in ADR-0007, and
it is recorded rather than quietly dropped.

`permittedlist.txt` is deliberately **not** created. Valheim treats that file as a whitelist — adding
anyone to it bans everyone else — so its absence is what keeps the server open to anyone holding the
password. `SERVER_PUBLIC=true` publishes it to the server browser.

The cost, stated plainly: **a password is not a person filter.** Anyone who sees the server can try
the password, and this pack ships no moderation mod. There is no per-person admission control on
this server, and adding one later means either the whitelist model above or a moderation mod that is
not currently in the Pack. The password lives in `launch.secret.env` and is never committed.

**The launch server is described by `config/launch/launch.env.example`, not by whatever the host
happens to contain.** That file is the committed, non-secret container environment: identity, world
rules, capacity, the freeze schedule and the backup posture. The secret file beside it —
`launch.secret.env`, in the same directory, gitignored — holds only `SERVER_PASS`, and later the
Discord webhook. `scripts/launch-server.sh env` prints the merged environment; `run` creates the
data directories and starts the container from it. Values the container needs, including the port,
are read from that file rather than from the caller's shell.

**Every world rule is an explicit `-modifier`; nothing is inferred from a preset.** The arg string is
`-savedir /config/save` followed by five modifiers — `Combat hard`, `DeathPenalty default`,
`Resources default`, `Raids less` (from 2026-10-03; every raid is an Oathbound siege since
2026-10-04, ADR-0020), `Portals hard` — and the form was verified against the game's own log
on Valheim 1.0.12, which printed one `Setting world modifier: <Name>-><value>` line per rule and no
parse error.

Two failure modes are worth knowing, because both are silent:

- A bad value leaves the rule **unset** rather than failing the boot. The game logs `Could not parse
  '<Name>' with a value of '<value>' as a world modifier` and starts anyway. `default` is the token
  that restores vanilla behaviour; there is **no** `normal` value. Measured rejections: `Combat
  normal`, `Portals normal`, `DeathPenalty normal`, `Resources normal`, `Raids normal`.
- `-preset` assigns the whole modifier set at once, so any rule a later `-modifier` does not restate
  becomes whatever the preset chose. The launch config therefore avoids `-preset` entirely: stating
  all five is both what #19 specifies and the only version verifiable from the log.

The four `-setkey` checkboxes are all absent deliberately, and `-setkey` only ever sets a key, so the
absence is the choice.

**The update freeze is the container's empty-string disable, not a future date.** `valheim-bootstrap`
writes a crontab line only when `UPDATE_CRON` is non-empty (`[ -n "$UPDATE_CRON" ]`), so an empty
value means no line and no update SIGHUP. A date far in the future is **wrong**: the value is emitted
verbatim into a busybox crontab line, and busybox cron takes exactly five fields, so a sixth token
becomes the first word of the command. `RESTART_CRON` still restarts on Sunday morning with
`RESTART_IF_IDLE=true`.

**A container restart is not a guaranteed no-op.** Independently of any cron, the container's updater
calls `update()` on its first loop iteration and re-syncs the installed game from its Steam download
when the server is idle. The real freeze is the one ADR-0007 names: install the accepted versions
once, by a controlled installation, and do not re-create the host from scratch mid-Run.

### Pre-launch checklist

Seven steps stand between the Shakedown Pack and players (owner answers 2026-10-05):

1. **No roster.** Guilds form in game and claim start regions at their portals (ADR-0028), so
   `config/dedicated/SeparateSpawns.groups.json` keeps its three empty regions (Skadi, Fenrir,
   Muninn), and `Lembitu.Guilds` assigns players to them by guild. Superseded: the 2026-10-04 plan to
   roster each guild's Steam IDs before the Run world. The live roster still lists three Steam IDs
   in Skadi from the 2026-10-03 world; it is moved aside, not deleted, before the Shakedown world's
   first boot, so the committed empty roster seeds it.
2. **ServerQuickConnect is seeded.** `config/client/radamanto.ServerQuickConnect.cfg` points the
   main-menu button "Join Lembitu" at `lembitu.astral.ee:2456` from Pack v17, with a blank password,
   which stays with each player. Through v16 it held an address (`85.253.16.237`), which went stale
   when the home address changed; the name is kept current by `scripts/update-dns.sh` (below).
3. **Drop `Lembitu.LevelUpSound` from the live server.** The current server loads
   `Lembitu.LevelUpSound.dll`, deployed 2026-10-03 from untracked source in the bicep checkout; the
   owner retired it on 2026-10-04. The live install manifest owns it (the server's
   `/config/bepinex/.lembitu-installed`), so installing from a `dist/` without it prunes it, and
   `prune-mirror` then clears the container's copy. Install from a clean build: the bicep checkout's
   `dist/plugins/` still holds the DLL and would put it back.
4. **No Discord webhook for the Shakedown.** DiscordConnector stays installed and posts nothing until
   a webhook URL is set in the server's DiscordConnector config; the owner deferred it.
5. **The server password is kept.** `SERVER_PASS` in bicep's `launch.secret.env` is set (eight
   characters, from 2026-10-03), and the owner kept it for the Shakedown.
6. **The Shakedown gets its own world, `LembituShakedown`** (owner, 2026-10-05):
   `config/launch/launch.env.example` names it, and the 2026-10-03 world `Lembitu` stays on disk.
   A new world name means re-creating the container, since its environment is fixed at
   `docker run`.
7. **The enforced overlay and the dedicated config are in force before the world is generated.**
   Expand_World_Size bakes its radius and stretch into terrain at generation (ADR-0018), and the live
   file still reads 12500 / 1.25. The new mods have never written their configs on this host either,
   and the applier refuses a missing target. So a disposable config-generation boot comes first,
   then the overlay and `scripts/apply-dedicated-config.sh`, then the Shakedown world's first boot,
   the same order `scripts/test-native.py` uses.

**Applied state, 2026-10-05 — the Shakedown is live.** All seven steps were done in that order on
astral-bicep with the owner's go-ahead for each stage:
- **Backup first.** All worlds were backed up first (`lembitu-all-worlds-20261005T185312Z.tar.gz`,
  with a copy on astral-tricep).
- **A fresh clone in place.** The old bicep checkout, with its uncommitted work and the untracked
  `Lembitu.LevelUpSound` source, was renamed to `~/code/valheim-lembitu-2026-10-03`, not deleted.
  A fresh clone of `master` took its path, so the backup units' `%h/code/valheim-lembitu` paths
  still resolve.
- **The tested build was installed.** The tested `dist/` from the Mac was copied over and
  installed; that pruned LevelUpSound and the cut mods.
- **The container's plugin copy was cleaned.** `prune-mirror` cleaned the container's copy, and
  BetterArchery, which no manifest owned, was removed from it by hand.
- **The old roster was kept aside.** The 2026-10-03 roster sits beside the new one as
  `SeparateSpawns.groups.json.world-Lembitu-2026-10-03`.
- **Configs came from a throwaway world.** A disposable `LembituConfigGen` boot wrote every mod's
  configuration; it was not public, and its world was deleted afterwards.
- **Then the overlays.** The applied overlays verified `337 entries match`, with World radius 13250,
  stretch 1.325, InnerRadius 1200 and MinStonesDistance 500.
- **Then the world.** `scripts/launch-server.sh run` created `LembituShakedown`: Valheim 1.0.16
  (network 40), the five world modifiers, `70 plugins to load` (69 loaded, 1 skipped, 0 failed),
  every Lembitu feature `on`, three empty regions, `Opened Steam server`, and no exception in the
  log.

Region claims live in `/config/bepinex/Lembitu.Guilds/LembituShakedown.claims.json`, inside the
BepInEx config the backups deliberately skip. A world restored from a backup therefore keeps the
claims as they are now, not as they were then. Reconciliation frees claims whose guild no longer
exists, but a claim made after the backup survives the restore.

**Pack v15 on the same world, 2026-10-06.** The deploy went in this order:
1. A backup (`lembitu-all-worlds-20261006T063339Z.tar.gz`, with a copy on astral-tricep).
2. With the server stopped, the install added Explorer and removed ExpertExplorer, CrewStats and
   DamageMeter.
3. One plain `docker start` so Explorer wrote its config. The applier refuses a missing target, so
   a new mod always needs this boot before the overlay.
4. `prune-mirror`. ExpertExplorer's `Assets` directory survived it, because the container user may
   not delete that directory, and was removed by hand.
5. `scripts/launch-server.sh restart`. It reported `enforced config verified: 349 entries match`,
   then `68 plugins to load` (67 loaded, 1 skipped, 0 failed), every Lembitu feature `on`, and
   `Opened Steam server`. v14 clients are refused from then on.

**The Run on its own world, `LembituRun`, with Pack v16, 2026-10-06** (owner; ADR-0030). Nobody was
connected. The deploy went in this order:
1. Backups of both old worlds (`lembitu-LembituShakedown-20261006T145515Z.tar.gz`,
   `lembitu-Lembitu-20261006T145515Z.tar.gz`) and of the per-world BepInEx state, the Guilds and
   Marketplace files, region claims, the old Almanac data and the Separate Spawns roster and layouts
   (`lembitu-bepinex-state-20261006-pre-run.tar.gz`), each with a copy on astral-tricep.
2. With the server stopped, the tested `dist/` from the Mac was copied over and installed;
   FineDining was new.
3. A plain `docker start` on the old world so FineDining wrote its config. It booted with
   `0 plugins to load`: the updater had re-extracted BepInEx, which also emptied the Separate Spawns
   tree in the game folder, roster included. A second start loaded 69 plugins (68 loaded, 1 skipped,
   0 failed) with every Lembitu feature `on`.
4. `prune-mirror` (nothing pending), then the container was removed, because the world name is fixed
   at `docker run`, and `scripts/apply-dedicated-config.sh` seeded the committed empty roster.
5. `scripts/launch-server.sh run` created `LembituRun` with the five world modifiers, `Opened Steam
   server`, 43 Lembitu features `on` and none off, and Separate Spawns chose its layout on the first
   try (score 28.67). Its verify reported 10 of 387 entries absent, all AdventureBackpacks backpack
   sections the mod had not yet written; a re-run a minute later reported `enforced config verified:
   387 entries match`.
6. Client Pack v16 published as
   [client-pack-2026-10-06-v16](https://github.com/rakoort/valheim-lembitu/releases/tag/client-pack-2026-10-06-v16);
   v15 clients are refused. Players start new characters for the Run (owner).
7. The old worlds `Lembitu` and `LembituShakedown`, their auto-backups, their Guilds, Marketplace and
   claim files, the stale `lembitu.levelupsound.cfg` and the unused `Almanac` tree were removed from
   the server after the backups.

**A first verify can race AdventureBackpacks.** It writes its per-backpack sections some time after
the chainloader completes, so a verify straight after a boot can report those keys absent. The
first v17 maintenance restart (2026-10-09) failed this way with 11 absent entries while the server
itself came up fine; a manual verify a minute later matched all 448. `scripts/launch-server.sh` now
checks once more after 60 seconds (`VERIFY_RETRY_DELAY`) before calling it drift.

**Pack v17 on `LembituRun`, 2026-10-09** (owner's go). Nobody was connected. In order:
1. Backups: the hourly unit's archive `lembitu-all-worlds-20261009T145716Z.tar.gz` and
   `lembitu-bepinex-state-20261009-pre-v17.tar.gz`, both copied to astral-tricep.
2. `docker stop -t 120 lembitu`; the live checkout fast-forwarded to `a589de3`; the Mac's `dist/`
   copied over; the Pack unpacked to `~/lembitu/pack/2026-10-09-v17` for ServerManager's policy;
   `~/.config/lembitu/deploy.env` set with `LEMBITU_LOAD_SERVER_CHARACTER=false`; the bot token
   added to `launch.secret.env` as `SERVERMANAGER_DISCORD_BOT_TOKEN`.
3. `scripts/install-plugins.sh` pruned DiscordConnector, Item_Requirement and MaxPlayerCount; the
   same three were removed from the container's mirror on the host while the container was down,
   because `prune-mirror` needs a running container and the old plugins must not load beside
   ServerManager. The web map's overlay was copied as its first target, since the applier refuses an
   overlay with no generated file.
4. The container was recreated with `scripts/launch-server.sh run` (frozen updater, reservation,
   loopback map): `ServerManager policy verified: 78 required DLLs, 7 optional`, `discord.yml: 4
   webhook routes`, `enforced config verified: 448 entries match`, game `l-1.0.17`, `68 loaded, 1
   skipped, 0 failed`, no version-mismatch warning, `ZNet.LoadWorld: LembituRun … save number 148`,
   `Opened Steam server`, and the map at `https://lembitu-map.astral.ee` answering 200.
5. Release `client-pack-2026-10-09-v17` published with `scripts/publish-pack.sh`, announced in
   `#announcements` with `@Player`.
6. Timers installed: maintenance (first run 06:00 Oslo), monitor (with
   `LEMBITU_QUERY_TARGET=lembitu.astral.ee`), DNS, Discord status (now from the main checkout) and
   the updated backup. The status message read `Pack: 2026-10-09-v17`.

Two findings. The first backup after boot ran in the seconds before ServerManager created its
`characters/` directory and was refused ("ServerManager installed without character store"), so the
monitor raised one backup fault; a rerun a minute later succeeded and verified 448 entries. And
Discord refused the bot's privileged intent: the Lembitu Server application needs **Message Content
Intent** switched on in the Developer Portal for the chat bridge; webhooks and the status display do
not need it. Enrollment stays open until yesterday's three players have joined once.

## Backups — #20

**The container's own backup must stay off on this server, and that is a measured finding, not a
preference.** It archives `/config/worlds_local`, while the server writes to `/config/save/worlds_local`
because `SERVER_ARGS` sets `-savedir /config/save`. On the historical host it had produced
twenty-three archives with two distinct checksums between them, every one of them a stale flat-file
`AstralTest` world — a backup that looks like a backup and contains nothing the live server wrote.
`config/launch/launch.env.example` therefore sets `BACKUPS=false`.

**`scripts/backup-world.sh` is the backup.** It captures one consistent set of the stores the pack
actually writes, and it refuses the failure above by construction:

| Captured | Owner | Note |
| --- | --- | --- |
| `worlds_local/<World>/` | server | the 1.0 chunked form: `_main.<n>.fwl2`, `.db2`, `.chunks`, `.chunk`, `.ok` |
| other `worlds_local/` directories | server | so a promoted playtest world is not lost |
| `cache/` | server | biome data cache, regenerable but cheap |
| `permittedlist.txt`, `adminlist.txt`, `bannedlist.txt` | server | admission |
| **not** `characters/` | client | personal keys live in the player's own file (ADR-0010) |
| **not** BepInEx config | repo | deployed from `config/enforced/` and `dist/` |

**Consistency is observed, not assumed.** The game writes `_main.<n>.ok` last and only then reaps
generation `<n-1>`, so the script records the `.ok` marker set before and after the copy and retries
if a save committed mid-read. A capture with no world files is deleted and the run fails, which is
the guard against the container's stale-archive outcome. Rotation keeps the newest `--keep` archives
and never removes a file it did not name.

**A restore is a documented, reversible operation.** `scripts/restore-world.sh` extracts into an
isolated save directory, refuses an archive with no committed-generation marker (so a pre-1.0
flat-file backup cannot be restored into a server that will then refuse to load it), and moves an
existing world aside to `<World>.replaced-<stamp>` rather than deleting it. `--dry-run` prints the
plan and changes nothing.

Measured on astral-tricep, 2026-09-15, on a disposable server: the capture of a real 1.0 world was
byte-identical to the source after restore (`diff` of per-file MD5s, zero differences), and a server
started against the restored directory logged `ZNet.LoadWorld: launch (launch), save number 1`
followed by `Opened Steam server`, advancing the world to a new committed generation. The regression
suite is `test/backup-world.test.sh` (15 checks, no network).

**What a restore does not return, through Pack v16.** Because characters are client-owned until
Pack v17, restoring the world returns the world — not each player's character, level or keys. Steam
Cloud or the player's own copy is what recovers those. From Pack v17 the archive also holds the
character store (ADR-0034).

**From Pack v17 the archive holds every server-held store (#104).** It captures `worlds_local`,
`cache`, the admission lists, the whole `ServerManager/` directory beside them, and the Guilds,
Marketplace and region-claim state under the sibling `bepinex/` directory (`--bepinex` overrides
it). Guilds and Marketplace keep per-world `<World>.dat`, `.dat.bak` and `.log` files under
`Guilds/` and `Marketplace/`; claims are `Lembitu.Guilds/<World>.claims.json`. ServerManager's
characters are account-global, so an archive restores as one set and never with `--world`. An
installed ServerManager without `characters/` is refused, and a restore refuses a partial set
before writing anything. `MANIFEST.txt` records each store as present or absent, and a restore
moves aside (or, with `--force`, removes) any target store the archive recorded as absent, so later
state never survives a restore. `--dry-run` lists every store it would replace, including the
account-global character store. ServerManager's `cron.yml` is the one deliberate exception to a
byte-identical restore: it is reset to the idle seed `config/launch/servermanager-cron.yml`, so an
archive taken during the 06:00 window cannot replay its one-off jobs. `INVENTORY.txt` records every
file's SHA-256; archives are mode 0600 because they hold private player data. The capture does not
request a checkpoint: it checks that files stay unchanged while it copies, and `STATE-TIMES.txt`
records their disk times, so world and characters can differ by up to the five-minute character
interval, longer if a client stalls. Proved by `test/backup-world.test.sh` (30 checks, no network);
the test-host restore with a rejoining character is part of the v17 acceptance run.

**The schedule, the retention and the off-host copy are now chosen and installed.** The decision is
committed as two systemd user units in `config/backup/`, which is what makes it reviewable in a diff
rather than host lore: `lembitu-backup.timer` runs `OnCalendar=hourly` with a five-minute randomised
delay and `Persistent=true`, and `lembitu-backup.service` calls `scripts/backup-world.sh` against the
container's bind-mounted save directory with `--keep 48` and
`--offhost astral-tricep:/home/ra/lembitu-backups`.

Hourly, because the server autosaves every thirty minutes, so at most two autosaves are ever at
risk. Forty-eight archives, because that is two days of play at roughly 11 MB an archive — trivial
against the host's free space, and long enough that a corruption noticed the next evening is still
recoverable. astral-tricep, because #20 requires that a copy leave the host and it is the project's
second machine, already trusted for ssh and running continuously.

The units are installed for the `ra` user on astral-bicep, which has `Linger=yes`, so the timer runs
with no session logged in. The capture needs no cooperation from the container: it copies the live
tree and compares the `.ok` marker set, so no restart, pause or `docker` call is involved, and it
runs `Nice=10` with idle I/O scheduling to stay out of the server's way.

Measured on astral-bicep, 2026-09-15, with players connected and the container untouched:
`systemctl --user start lembitu-backup.service` finished `Result=success`, wrote an 11 MB archive
holding world generation `_main.6` plus the three admission lists, and mirrored it to astral-tricep
with an identical SHA-256 on both hosts (`1412b996…8e931`). Restoring that archive into a disposable
directory reproduced all ten files of the live world with matching MD5s, and the restore moved
nothing aside in the live save because it was never pointed at it.

**What the restore proof does not cover: Clan membership.** The restore was verified by a byte
comparison of the captured files and by a server loading the restored world (`ZNet.LoadWorld`, then
`Opened Steam server`). No client connected and no Clan registry was observed, so #20's "verified to
load with clans and characters intact" is half-met: characters are client-owned and out of scope by
design, and Clan membership — which lives inside the world save — was not checked. That check belongs
to the same two-client session as the rest of acceptance.

## Maintenance restart, monitoring and the web map — #103, #105, #107, #108

**The host owns the schedule; ServerManager's cron is only the console.** A systemd user timer
(`config/launch/lembitu-maintenance.timer`) starts `scripts/maintenance-restart.py` at 05:49:40
Europe/Oslo. It writes one-off jobs into ServerManager's `cron.yml` for the ten-, five- and
one-minute warnings and the `save`. It stops the container only after the `save` job's own
completion record, with a `WorldCharacterCheckpointCompleted ... pending=0` logged after the save
began and before that completion. ServerManager binds a scheduled save to its own operation and
logs the job complete only once that checkpoint has finished (decompiled
`ServerScheduleRuntime.cs:577-599,670`), so an autosave or an older checkpoint cannot authorise a
stop. Any refusal or missing confirmation aborts the restart and posts to
`DISCORD_WEBHOOK_MONITOR`. Its lock and a `maintenance-until` marker live in
`~/.local/state/lembitu/`, outside the backed-up save tree. `scripts/launch-server.sh restart` and
`stop` use the same path when the container is running; on a stopped container `restart` and the
new `start` go straight to applying the overlay, starting and verifying (ADR-0011). Proved with a
fake Docker in `test/launch-server.test.sh` (18 checks). On the test host (#101,
`20261007T133035Z-ticket101-planned-orders`), progress made just before the console `save` survived
the stop: the save made ServerManager request a fresh copy from the connected client
(`CharacterShadowAccepted`) before the checkpoint logged `captured=1, persisted=1, pending=0`. No
disconnect step is needed before the save.

**A restart can no longer update the game.** An empty `UPDATE_CRON` never stopped the image's
updater on start (see "The image's updater can empty the plugin directory" above, and the 1.0.14
drift in Launch provisioning). The container now mounts `scripts/frozen-valheim-start.sh`
read-only in place of the updater, which starts the installed game without downloading or
extracting anything. A container created without that mount is refused before any warning.

**The game's resources are reserved, not capped (#107).** The container runs with CPU shares 4096,
a 4 GiB memory reservation and a 120-second stop timeout, and no memory limit. Caps on the other
stacks on astral-bicep are proposed, not applied, because they belong to other projects. A single
read-only sample measured the spore preview `web` container at 20.27 GiB, which deserves a look
before any cap.

**Monitoring runs every minute and speaks only on change (#105).** `scripts/monitor.sh`, driven by
`config/monitor/lembitu-monitor.timer`, keeps its state under `~/.local/state/lembitu` and posts
one fault and one recovery per condition through `DISCORD_WEBHOOK_MONITOR`. Container down,
OdinEye unanswered and the outside query failing must last 120 s; a world save must complete
within 600 s. While a maintenance restart's `maintenance-until` marker is valid, those
availability faults are held back, so planned restarts post nothing; a server still down when it
expires alerts as usual, and resource, backup and off-host faults are watched throughout. OdinEye
answers on `http://localhost:2469/` inside the container and is never published; the outside check
is an A2S query sent from astral-tricep (`scripts/query-server.py`). The starting limits in
`config/monitor/settings.json` come from one sample (the game at about 10% CPU and 1.8 GiB, the
host at 38% memory and 55% disk) and must be tuned after a week of play. Proved by
`test/monitor.test.sh` (26 scenarios) and a local UDP protocol smoke; the staged-fault drill on a
disposable test container is part of the v17 acceptance run.

**The public Discord display is a separate snapshot, not an admin alert.**
`scripts/discord-status.sh` and `config/discord-status/lembitu-discord-status.timer` refresh one
STATUS webhook message every minute. The Lembitu Server bot renames the locked top-level voice
channel only on a changed status/count, at most once per five minutes. State is outside the saves
in `~/.local/state/lembitu/discord-status.json`; a valid maintenance marker displays restarting.
The map link remains the Cloudflare Tunnel URL; no OdinEye or game port is exposed for Discord.
The installed Pack marker is `~/lembitu/config/bepinex/.lembitu-pack-version`: a successful
`scripts/build-client-pack.sh --version LABEL` labels the staged `dist/`, and
`scripts/install-plugins.sh` copies that label with the deployed plugins. An unlabelled install
removes a stale marker and status reports Unknown. This reports the deployed Pack rather than
assuming a newly published client release was already deployed. See `docs/wiki/discord.md`.

Install on astral-bicep (operator steps; not applied by these changes):

1. Reconcile the layout on the Mac with `scripts/discord-layout.sh apply`. Copy the resulting
   `~/.config/lembitu/discord.env` and `discord-webhooks.env` to the same directory on astral-bicep.
   The first contains `DISCORD_STATUS_VOICE_CHANNEL_ID` and `DISCORD_ROLE_PLAYER_ID`; the second
   contains `DISCORD_WEBHOOK_STATUS`. Keep the webhook file 0600.
2. Transfer the **Lembitu Server** token from keychain service `lembitu.discord.serverbot` through
   private stdin to `~/.config/lembitu/discord-serverbot.env` on astral-bicep as
   `DISCORD_SERVER_BOT_TOKEN=...`, mode 0600. Never transfer the Ops token or put a token in an
   SSH argument, shell history or log. This is the same Server bot used by ServerManager, with
   Manage Channels granted only on the status voice channel.
3. Put the updated checkout at `~/code/valheim-lembitu` and deploy the labelled staged plugins
   through the normal installer. On astral-bicep, copy
   `config/discord-status/lembitu-discord-status.{service,timer}` into `~/.config/systemd/user/`,
   run `systemctl --user daemon-reload`, then `systemctl --user enable --now
   lembitu-discord-status.timer`, and read `journalctl --user -u lembitu-discord-status.service`.
   Enable user lingering with `loginctl enable-linger "$USER"` if it is not already enabled.
   A different checkout location needs an `ExecStart` unit override. `scripts/lib/python.sh`
   supplies Python through the repository-pinned Nix fallback when no `python3` is on PATH.
4. Check the one status message and locked voice channel in Discord. The fake scenarios in
   `test/discord-status.test.sh` cover creation, edits, deleted-message recreation, maintenance,
   names, empty lists, unavailable OdinEye, throttling and missing secrets.

**Live since 2026-10-09, before the cutover.** The timer runs on astral-bicep from a separate
checkout, `~/code/valheim-lembitu-ops`, through a unit drop-in that overrides `ExecStart`, so the
live server's own checkout, which the hourly backup and drift check use, stays on v16 until the
cutover. Its first run posted `🟢 Online`, `0/10`, game `l-1.0.17`, Pack `Unknown` (the label
arrives with the v17 install) and the uptime. Two findings: the Ops and Server bots both lost
access to the voice channel because its @everyone overwrite denies Connect, so the layout now
grants each its own Connect; and the Ops bot cannot read message text without the Message
Content intent, so the message is read back through its webhook instead. Until v17 deploys, the
message's "next daily maintenance" line describes the schedule v17 brings.

**The web map draws the whole world (#108).** Expand_World_Size does not change
`WorldGenerator.worldSize`, a constant 10000; it patches the game's literals and exposes its radius
and edge in its configuration. The fork in `src/forks/ValheimWebMap/` reads those once per world:
13,250 + 500 + one 64 m zone gives a 13,814 m half-size. Upstream also clipped terrain at the
vanilla 10,500 m edge and assumed a 12,288 m cartography bitmap; both are corrected. At 4096 px a
pixel is 6.7 m and the render arrays take about 160 MiB on two background workers.
`test/webmap-coverage.test.sh` runs the real renderer and tile service on synthetic terrain and
finds land, not fog or void, at 13,000 m on all four sides, and mask coverage at the 13,750 m edge.

**The owner reversed web-map privacy on 2026-10-09.** Everyone's live position, heading and guild
are public, regardless of the in-game public-position toggle, and exploration reveals during the
connection rather than waiting for logout. The enforced `[Players] IgnorePositionPrivacy = true`
bypasses the fork's private-exploration buffer; its default false preserves the earlier behaviour
for other installations. The in-game map still keeps public positions off. Guild names come from
Northarun/Guilds 1.2.3's server membership store, keyed by the character's persistent player ID,
not a client-provided guild or a matching display name. The optional reflection lookup calls
`GuildServer.EnsureLoaded()` and `GuildServer.GuildOf(long)`, then reads `Guild.Name`; missing or
changed Guilds leaves the name null and logs one warning per map session. Map labels and the online
list show the guild beside the player name. The map listens on 3000 inside the container, published
only on `127.0.0.1`.

**The map is published through a Cloudflare Tunnel, not an open port (owner, 2026-10-09).** The
first plan put Caddy on astral-bicep behind router forwards of TCP 80 and 443. The owner judged
opening web ports into the home network a security risk. A `cloudflared` container
(`scripts/launch-server.sh tunnel`, host networking, pinned image) dials out to Cloudflare and
forwards only `lembitu-map.astral.ee` to `127.0.0.1:3000`; the name is a proxied CNAME, so visitors
see Cloudflare's addresses, and a Cloudflare rule blocks any visitor sending more than 100 requests
in 10 seconds. Caddy and its configuration left the repository. The map is `lembitu-map.astral.ee`
rather than `map.lembitu.astral.ee` because Cloudflare's free certificate covers only names one
level under the domain, and the owner chose the free plan.

**The game has a name, not just an address (owner, 2026-10-07).** The owner registered `astral.ee`
on Cloudflare. `lembitu.astral.ee` is the game's address, an A record set to DNS only, because
Cloudflare's free plan cannot carry the game's UDP traffic; the home address therefore stays
visible, as it already is in Steam's server browser. astral-bicep sits behind the home router
(`192.168.0.101`) on an address that changes: the Pack's join button still pointed at
`85.253.16.237` while the host was at `85.253.100.163`. Valheim resolves a hostname at join
(`DnsResolver.URLToIP`) and ServerQuickConnect accepts one, so the v17 seed uses the name.

**`scripts/wizard-cloudflare.sh` sets all of this up.** It walks the owner through one API token
limited to the zone (DNS edit, zone read, WAF edit) and to Cloudflare Tunnel, then creates or
updates the game record, the tunnel, its route and CNAME, and the rate-limit rule, and copies the
tunnel token and the API token to private files on astral-bicep, the latter for the address
updater. Tokens reach `curl` and `ssh` on standard input, never as arguments.
A token whose TTL start date lies in the future verifies as "active" yet refuses every call, and
one with an expiry date would later strand the updater; the wizard now refuses both.

**Set up 2026-10-09.** The owner ran the wizard: `lembitu.astral.ee` (A, DNS only) and
`lembitu-map.astral.ee` (CNAME to the tunnel, proxied) exist, the rate-limit rule is in place, and
the token has no TTL dates. The `lembitu-tunnel` container runs on astral-bicep and registered four
connections to Cloudflare. From astral-tricep the map answered HTTP 502, Cloudflare reaching the
tunnel with nothing yet on port 3000 (the web map ships with Pack v17), and a burst of 140 requests
drew 23 × 429 from Cloudflare's rule. No router port was opened.

**`scripts/update-dns.sh` follows the home address.** Run every five minutes by
`config/dns/lembitu-dns.timer` on astral-bicep, it reads `~/.config/lembitu/cloudflare.env`, takes
the first public IPv4 from two address services, and patches each A record in `CLOUDFLARE_RECORDS`
whose content differs. A private, missing or failed answer leaves the records alone. With a 60 s
TTL, players reach a new address within about six minutes. `test/update-dns.test.sh` covers it
against a fake API (9 checks); a dry run on astral-bicep with the real token reported
`lembitu.astral.ee already 85.253.100.163`. The units are installed at cutover, like the others.
The outside reachability check in monitoring uses the same name: set
`LEMBITU_QUERY_TARGET=lembitu.astral.ee` in the monitor unit's drop-in.

## Two-player checks, on the live server after Pack v17

The test host has one Steam account. The owner chose on 2026-10-09 to ship v17 without a separate
two-account test session and to watch these on the first live evening instead; failures are fixed
forward or rolled back from the backup. Account A is the owner, the admin, with Infinity Hammer,
its addon and World Edit Commands on top of the Pack; any other player stands in for account B.

| # | Do | Expect | Ticket |
| --- | --- | --- | --- |
| 1 | A joins with the admin tools | A is admitted; ServerManager logs the admin exemption for the extra mods | #101 |
| 2 | B joins, then tries a second character on the same account | The first is admitted, the second refused | #101 |
| 3 | Both fight the same creatures for two minutes; one heals the other | Each Tally window (F10) shows both players' damage and healing and does not cover the inventory | #109 |
| 4 | Both play ten minutes in one area | Server CPU and tick times are recorded beside the one-player figures in [Character store](character-store.md) | #101 |
| 5 | Each writes in the Discord `#chat` and in game chat | Messages cross both ways through the Lembitu Server bot | #106 |
| 6 | A runs `scripts/launch-server.sh restart` with B online | B sees the 10-, 5- and 1-minute warnings in game and in `#status`; after rejoining, B has the progress made just before the save | #103 |

### First-evening finding: the portal panel near the spawn stones — #110

A Windows player reported that pressing E on a wood portal crashed the game. ServerManager's per-player log put both of the player's disconnects beside the portal at (44, 34, 219), near the sacrificial stones. On a copy of the live world on the test host, XPortal 1.2.25's configuration panel opened there with both buttons non-interactable while it blocked game input; far from the stones it worked. XPortal 1.2.26 fixes this upstream (the panel now outranks the game's start-temple UI group), and the same run with it shows the buttons interactable. The pin moved to 1.2.26 in `docs/modstack.md`. The Windows process exit itself was not captured, because no Player.log or crash dump was available.

### Pack v18 deploy and the silent restart warnings — 2026-10-09

Pack v18 (every mod at its latest release, XPortal's fix included) went live at 23:39 EEST with nobody online. ServerManager's policy was regenerated from `~/lembitu/pack/2026-10-09-v18`, the enforced config was verified at 448 entries, and 68 plugins loaded. The same run was first proven on a copy of the live world on the test host (`~/lembitu-native-tests/20261009T201218Z-update-live`): all 128,551 world objects loaded under Expand World Size 1.44, and the world saved and reloaded. No hook of ours switched off, and the near-spawn portal panel worked.

The deploy restart showed that `scripts/maintenance-restart.py` had never delivered its 10-, 5- and 1-minute warnings to `#status`. Discord's Cloudflare answers Python's default `Python-urllib` agent with HTTP 403 (error 1010), and the script only logs "Discord delivery failed". It now sends the same `DiscordBot (...)` agent as the shell scripts. `test/launch-server.test.sh` checks the agent the real `post()` sends. Check 6 above remains open until a restart with a player online shows the warnings in `#status`.

**Test servers posted to the players' Discord.** The live-world copies used for the v18 checks came from a backup, and backups include ServerManager's discord.yml (in the save directory) with the real bot token and webhooks. Eight test sessions on 2026-10-09 (19:03–20:19 UTC) therefore posted their test characters' joins, chat greetings and admin alerts, plus their own restarts, into `#activity`, `#chat`, `#admin-alerts` and `#status`. The 56 posts were deleted through the webhooks that sent them on 2026-10-10. `scripts/native_session.py` now deletes that file from any save directory a test server adopts.

## Exclusions

- The overlay does not own every setting. PvP and death now follow vanilla rules. No biome-forced flag, flagged-player retention or special tombstone-looting rule replaces the removed mod.
- DataForge is for tuning, not cloned or custom items; CreatureManager's empty overrides exclude cloning and customisation while leaving Karma and levels at mod defaults. Groups and Guilds are not fallback membership systems (`docs/adr/0004-two-power-curves.md:37-38`; `config/enforced/sighsorry.CreatureManager.cfg:1-5`; `docs/adr/0008-clan-is-the-only-membership-authority.md:23-27`).
- There are no planned mid-Run content injections. A newer release is declined by default unless it fixes something actually broken and passes replacement acceptance. Development pins and historical server boots are not approval to create the launch world (`docs/adr/0007-frozen-game-version-and-pinned-pack.md:27-48`).

## Lessons

**The Run started on a game version nobody chose.** The 2026-10-06 deploy's container start ran the
image's updater, which installed Valheim 1.0.17, published that day, so `LembituRun` was created on
1.0.17 while the test host and reference assemblies were still 1.0.16 (`docker logs lembitu`:
`Valheim Version: l-1.0.17`). 1.0.17 is network-compatible and fixes a rare world-save chunk bug
that could erase objects. What it changed for our mods, all logged on the live server since then:
Zen.ModLib 1.14.20 and ZenRaids 1.2.3 report a version mismatch but keep running (Zen_ModLib
1.14.21 is the 1.0.17 build and ships in v17); CreatureManager 1.2.5 disables Deathward's lethal
prevention (Deathward is banned by ADR-0033) and Swift's swimming bonus; FineDining's recovery of
AzuExtendedPlayerInventory's hidden slots no longer matches, so recovered food does not keep its
spoilage timer. `scripts/frozen-valheim-start.sh` now keeps a restart from updating the game; an
update is a deliberate act.

**Deleting the bind-mounted plugin is not enough.** The real-server container copies plugins from `/config/bepinex/plugins` into `/opt/valheim/bepinex/BepInEx/plugins` using rsync without deletion. Old DLLs and bundle trees can therefore keep loading; renamed DLLs can produce duplicate GUIDs. After installer pruning, use `scripts/install-plugins.sh prune-mirror <bepinex-dir> <docker-container>` to replay `.lembitu-removed` against that second copy (`docs/build.md:232-263`). Only plugin entries are replayed; configuration and patcher entries are consumed without a container deletion. A failed replay retains the ledger for retry. The tests exercise this through a fake Docker command, not a live container (`scripts/install-plugins.sh:188-220`; `test/install-plugins.test.sh:8-9,301-391`).

**A retired plugin must also leave the build output.** The installer treats `dist/` as its source, so stale locally built DLLs can be reinstalled unless the output is cleaned after a rename or removal. This became concrete when official BossRules replaced the temporary local authority guard: the recorded cutover requires clean output, normal installer pruning and separate container-mirror pruning (`docs/build.md:210-213,646-650`). ADR-0009's DLL-only installer warning is historical: complete asset-bundle deployment and pruning are now covered by the current installer tests (`docs/adr/0009-world-permanent-mods-land-before-world-creation.md:31-35`; `test/install-plugins.test.sh:62-118`).

**Historical permission-bearing alert — 2026-09-16.** PvPBiomeDominions bypassed its tombstone-looting restriction when its alert was off or empty. The overlay therefore pinned an enabled alert and non-empty message. That lesson survives the mod's 2026-10-03 removal; those keys are no longer enforced.

**Successful file application is narrower than gameplay proof.** The merge tests protect same-named keys in different sections and make missing targets fail visibly, but cannot prove client authority, death retention or capacity under simultaneous connections. Historical evidence names those gaps explicitly; the latest full-pack report likewise separates its passing scenario from exhaustive mod-feature and two-client acceptance (`test/apply-enforced-config.test.sh:27-95`; `docs/modstack.md:165-183`; `docs/build.md:704-706`).
