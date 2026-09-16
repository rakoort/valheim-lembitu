# Server operations

This page records how to deploy the server's configuration and plugins, and separates those implemented tools from the recovery and launch requirements for the Run. The operating model is a public, password-protected server running one accepted Pack for a three-month Run (`CONTEXT.md:3-23`).

## Decisions

**The Run has a defined window, not continuous upgrades.** Announce its start and end; an extension
is optional while interest lasts. The server is public and password-protected, with a player cap of
twenty, and membership is whoever holds the password (`CONTEXT.md:12-23`; `docs/adr/0007-frozen-game-version-and-pinned-pack.md:38-54`).
MaxPlayerCount is an implemented server-only fork with a default of twenty. Historical server evidence
shows the admission and matchmaking literals rewritten and the Steam capacity call executed; it
explicitly does not prove an eleventh simultaneous connection (`docs/modstack.md:36,269-303`).

**Enforced configuration is the server's deliberate deviation from mod defaults.** It belongs in server-locked configuration, not a player's file. The committed overlay is `config/enforced/`; it is applied to the files the mods generate on first boot. This is distinct from the package-supplied configuration seeds deployed by the installer (`docs/modstack.md:18-20`; `docs/build.md:201-230`). The current overlay owns these choices:

- Clan configuration is locked, friendly fire is off and clan positions are shared. Clan is the only membership authority; guest connections must be resolved through Clan rather than by comparing primary membership IDs. Ward and other allied-player integrations must use that same answer. Position sharing is now a clan privilege rather than a map feature, because the map hides everyone else (`config/enforced/sighsorry.Clan.cfg`; `docs/adr/0008-clan-is-the-only-membership-authority.md:12-38`).
- PvP remains each player's flag: all nine biome rules are `PlayerChoose`, and Wards follow the biome rule. The server pins death retention and grave-looting rules: flagged players keep equipped and hotbar items and may loot another tombstone; unflagged players do not receive those permissions or retention. No-item-loss remains off in both cases. The separate `[3 - Map Position]` block, which reuses the same nine key names, is now pinned too: every biome is `HidePlayer`, so no player's position appears on another's map and the ward override defers to the biome rules (`config/enforced/Turbero.PvPBiomeDominions.cfg`). InventorySlots' independent keep-on-death system is disabled so it cannot compete with that authority (`config/enforced/sighsorry.InventorySlots.cfg:1-6`).
- Personal keys are enforced in `config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg`: private keys on, the world's global key list blocked, and private raids on. It also names what progression gates, which is more than gear: `LockEquipment` and `LockCrafting` (ADR-0005), `LockCooking` and `LockEating` (added by the 2026-09-16 review, amending ADR-0005), plus `LockGuardianPower` and `LockBossSummons`, so forsaken powers and boss altars follow each character's own keys. Equipment repair, building and building repair are pinned *off* against a package default that turns them on; taming is pinned off at its own default, and `AdminBypass` off so an admin plays the same run as everyone else. Every one of these locks is material-scoped, so a keyless character still cooks and eats Meadows food and builds in wood. The boat, portal and nine `[PortalUnlocking]` key names are pinned empty, which is vanilla: no key opens ore hauling, which is the `Portals hard` launch rule said a second time. The skill manager is now *on*, with the ceiling pinned at the vanilla 100 and the floor following `UseBossKeysForSkillLevel` at 10 per private key, so a character who was present for five boss kills starts a fresh skill at 50; the floor and ceiling are decided independently in the mod's own `SkillsManager.UpdateCache` (ADR-0005, ADR-0010).
- PortalRules configuration is locked and the portal map is disabled. DataForge and CreatureManager are locked, with their committed data files pinning an empty override state rather than silently accepting future package examples. CreatureManager additionally carries the difficulty tier: `Biome Level Preset = Hard` plus `Bosses Follow Biome Level Preset` in its `[2 - Levels]` section. The preset is primarily about ordinary creatures — it sets the level distribution for every natural spawn in a biome, and `Hard` gives roughly 40% stronger spawns than the `Easy` default (expected level 1.10 in Meadows rising to 3.22 in Ashlands) — while the earliest biomes still spawn at level 1 most of the time (90% in Meadows, 68% in Black Forest), so a new character is not softlocked. Bosses follow the same preset, so boss level and therefore boss health through `Boss.healthPerLevel` rises by biome tier: expected health ×1.05 for Eikthyr to ×2.11 for Fader, a 2.01× gradient. `Hard` is not the package default, which is why it is pinned: an upstream flip or a fresh install must not silently rebalance the run. Observed boss health and any further retune belong to #13 and #10's two-client session (`config/enforced/sighsorry.PortalRules.cfg:1-9`; `config/enforced/sighsorry.DataForge.cfg:1-7`; `config/enforced/sighsorry.CreatureManager.cfg:1-40`).
- CreatureManager also fixes difficulty against headcount. Vanilla scales every creature by the number of players standing nearby — 30% effective health and 4% damage each, capped at five — so the same boss was a different fight depending on who logged in, and a sixth player made it easier. Both percentages are pinned to zero and the count cap to one, and the difficulty is set in the level table instead: `Global.health = 4` and `Boss.health = 8`, so ordinary creatures and Enforcers carry four times vanilla health and regular bosses eight. Damage is untouched at 1, so a fight is longer rather than deadlier per hit, and per-level growth still compounds on top — a level-3 Ashlands creature is 12× and a level-2 boss 12×. `levels.yml` is pinned wholesale like the other CreatureManager data files, which keeps the 32 stock modifiers and their 5% chances under review rather than at whatever the next package ships. This is the owner's 2026-09-16 decision applied by #68; it has not yet been measured in a real boss fight (`config/enforced/sighsorry.CreatureManager.cfg:65-79`; `config/enforced/CreatureManager/levels.yml`).
- ItemRequiresSkillLevel's enforced rules gate equipping on character level rather than world progression; crafting is deliberately left open, so a player may craft armour ahead of their level and carry it until they grow into it. Their armour-tier thresholds are a starting point for playtest tuning, not settled balance. They sit beside the key gate, so a player can satisfy one and be refused by the other — and World Advancement Progression's `LockCrafting` still blocks the craft itself on boss keys (`config/enforced/WackyMole.ItemRequiresSkillLevel.yml`).
- EpicLoot gates magic drops on the requesting player's known recipes rather than on world keys, since this server writes none: `config/enforced/randyknapp.mods.epicloot.cfg` sets `[2 - Balance] Item Drop Limits = PlayerMustKnowRecipe`, and `Gated Freebuild Mode` follows it so building pieces obey the same rule. Every other gating mode in that setting reads world progression, so on this server they would all leave the roster at Meadows tier. The same overlay carries the 2026-09-16 curve reduction — drops at 0.6 of stock, shardstones from 0.2 to 0.05 — and turns Adventure Mode off, removing bounties, treasure maps, gambling and the secret stash. Effect counts per rarity are not overlay keys at all: they live in the mod's own loot tables and change through an EpicLoot patch file placed under the overlay's EpicLoot patches directory, which #73 specifies and has not yet added.
- The 2026-09-16 review pinned six surfaces nobody had ever enforced, plus two loader-level ones. EpicMMOSystem carries `Force Server Config` and the whole XP economy frozen at what the first evening ran, with death costing between 5% and 15% of the level and the group and kill ranges widened to 100 metres; its competing creature-level system is off, because CreatureManager owns creature levels. DiveIn's swimming block, SkadiNet's measured network profile and DynamicLocations' two spawn-point keys are pinned as they ran. Max Dungeon Rooms is 20–40 with its three per-dungeon overrides disabled, world-permanent under ADR-0009. MaxPlayerCount is 20, which is where the Roster's capacity is actually implemented. BepInEx itself gets `AppendLog = true`, so a restart stops destroying the log of the boot before it. DiscordConnector sends no positions and refuses `@here`/`@everyone`, with the eight lifecycle, join, leave, death and shout toggles pinned on; the webhook URL is a secret and stays in `config/launch/launch.secret.env`.

**Apply overlays after generation, not instead of generation.** Run `scripts/apply-enforced-config.sh <bepinex-config-dir>` after the server's first boot and whenever an overlay or pin changes. For `.cfg` files, the script matches the section and exact key, preserving unrelated entries and generated comments. A missing key is appended under a re-declared section; a missing target file aborts, because creating an unused filename would look like successful enforcement. Non-`.cfg` files replace their targets wholesale. A second unchanged application reports nothing to do (`docs/build.md:215-230`; `scripts/apply-enforced-config.sh:6-24,36-65,103-132`). The shell tests cover section isolation, unchanged reapplication, missing-key append, missing-target failure, data replacement and an entry outside any section. They test file transformation, not a real client's receipt of synced rules (`test/apply-enforced-config.test.sh:27-121`; `docs/modstack.md:165-183`).

**Applying by hand once was not enough, and that is measured.** On 2026-09-16 a key-by-key
comparison of the live server against the overlay found ten of forty-six pinned keys sitting at mod
defaults: the difficulty tier at `Easy` instead of `Hard`, five World Advancement Progression locks,
the skill manager, EpicLoot's drop gating, clan friendly fire, and InventorySlots' keep-on-death.
Every drifted value was the package default, and a full evening of play — including the run's first
boss kill — had run under them. Nothing in the repository compared the applied result to the overlay
afterwards, so the revert was silent. ADR-0011 therefore decides that the overlay is re-applied on
every container start and verified by a drift-check command that exits non-zero on
drift and is wired into the launch path and the backup timer's service (#68 applies the review, #69
builds the verification).

**The overlay's scope grew with that review.** It covered nine files and forty-six keys; it now
covers seventeen files and 163 checked entries, adding EpicMMOSystem, DiveIn, SkadiNet,
MaxDungeonRooms, MaxPlayerCount, DynamicLocations, BepInEx's log appending, DiscordConnector's
main settings and its notification toggles, and CreatureManager's level table. The rule that
drove the expansion: an upstream default is not a decision, so a setting the project cares about
is pinned even when the default already matches.

**A key belongs to a section, not to a name.** CreatureManager's three modifier switches read
like they live in `[5 - Modifiers]`, and `local/decisions-2026-09-16.md` records them there, but
the mod generates them in `[2 - Levels]`. The overlay pins the section the mod writes. Naming the
wrong one is not an error anybody sees: the applier appends the key under a re-declared section
and the mod reads its own copy, so the file looks enforced and nothing is. The generated file is
the authority on where a key lives, never the decision note.

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

**A mod the server cannot enforce is not a mod this project keeps.** AdminQoL taught it: none of
its twenty-nine settings is server-synced, so its defaults — no durability loss from damage or use,
no equip delay, no crafting-station roof requirement — were live for everyone and unreachable from
the server. The 2026-09-16 review dropped every client-only mod, AdminQoL and BoneMod, and withheld
the server-only ones from the client Pack (`docs/modstack.md`, "Where each mod runs"; #70).

**Deploy complete package trees into the BepInEx root.** The install loop builds maintained plugins, stages adopted packages, then runs `scripts/install-plugins.sh <bepinex-dir>`. Staging checks package hashes against `docs/modstack.lock.json`; deployment preserves `plugins/`, `patchers/` and configuration seeds, including asset-bundle manifests and nested bundle directories. The installer target is the BepInEx directory itself, not its `plugins/` child (`docs/build.md:193-208,271-296`; `scripts/install-plugins.sh:94-103`; `test/install-plugins.test.sh:62-96,199-239`).

The installer records every deployed file in `.lembitu-installed` at that root. On subsequent installs it prunes previously owned files absent from `dist/`, removing directories only when empty. A same-name foreign file is overwritten with a warning and becomes owned; unrelated foreign files survive. Old plugins-only manifests are migrated so their files remain prunable (`scripts/install-plugins.sh:105-201`; `test/install-plugins.test.sh:98-170,286-299`).

**A persisted manifest is untrusted input to a destructive step.** Pruning is driven by `.lembitu-installed` alone, so an entry that escapes the BepInEx target would make `rm` delete outside it. The installer therefore validates every entry before the first removal, naming the offending line, and the check precedes both the `.lembitu-removed` append and the manifest rewrite, so a corrupt manifest never leaves a partial prune. The policy is shared with `dist/` names and the prune ledger: a character allowlist plus a refusal of traversal shapes (`.`, `..`, leading-dot components, absolute paths), either half of which aborts the run. Both writers of that manifest are covered — the install validates each name before copying, and the plugins/-era migration validates the legacy entries before rewriting them, while the legacy file is still on disk to correct rather than deleting it first (`scripts/lib/ledger.sh:5-12`; `scripts/install-plugins.sh:94-201,220`; `test/install-plugins.test.sh:394-442`).

**Launch and recovery remain acceptance requirements.** Freeze the game and Pack together only after the acceptance gate passes on the same candidate — one clean full-pack boot and one manual two-client session — with public releases checked again before the gate. Only then arrange controlled installations and disable automatic server updates. Everything planned for the Run ships at launch (`docs/adr/0007-frozen-game-version-and-pinned-pack.md:24-40`). The launch world must already have verified Max Dungeon Rooms and ValheimRAFT installed; they remain installed for the Run, and the playtest world must use the same two (`docs/adr/0009-world-permanent-mods-land-before-world-creation.md`). World Advancement Progression is not world-permanent, but it clears the world's global keys on startup, so it too belongs in the Pack before the launch world is created.

Recovery policy is rollback on the accepted versions, not an improvised mod upgrade. What a backup
can hold changed with ADR-0010: the character store — and therefore character level and personal
keys — is client-owned, so a server archive must not be described as capturing it. The implemented
capture, schedule, rotation, off-host copy and proven restore are in [Backups](#backups--20) below
(`docs/adr/0007-frozen-game-version-and-pinned-pack.md:39-40`).

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
`Resources default`, `Raids default`, `Portals hard` — and it was verified against the game's own log
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
| **not** `characters/` | client | character level and personal keys live in the player's own file (ADR-0010) |
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

**What a restore does not return.** Because characters are client-owned, restoring the world returns
the world — not each player's character, level or keys. Steam Cloud or the player's own copy is what
recovers those.

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

## Exclusions

- The overlay does not own every setting. PvPBiomeDominions' map-position rules are deliberately untouched even though they reuse biome key names; the server does not force PvP through biomes or Wards. Retention is based on the victim's flag, not the cause of death: a flagged drowning player also retains gear (`config/enforced/Turbero.PvPBiomeDominions.cfg:1-14,19-32`).
- Portal policy excludes fares, the map picker, admin portals and GlobalKey gates. The overlay explicitly disables the map; its comments distinguish default-off fares and unconfigured key gates from explicit overrides. Do not describe every exclusion as a separate enforced key (`docs/modstack.md:32`; `config/enforced/sighsorry.PortalRules.cfg:1-9`).
- DataForge is for tuning, not cloned or custom items; CreatureManager's empty overrides exclude cloning and customisation while leaving Karma and levels at mod defaults. Groups and Guilds are not fallback membership systems (`docs/adr/0004-two-power-curves.md:37-38`; `config/enforced/sighsorry.CreatureManager.cfg:1-5`; `docs/adr/0008-clan-is-the-only-membership-authority.md:23-27`).
- There are no planned mid-Run content injections. A newer release is declined by default unless it fixes something actually broken and passes replacement acceptance. Development pins and historical server boots are not approval to create the launch world (`docs/adr/0007-frozen-game-version-and-pinned-pack.md:27-48`).

## Lessons

**Deleting the bind-mounted plugin is not enough.** The real-server container copies plugins from `/config/bepinex/plugins` into `/opt/valheim/bepinex/BepInEx/plugins` using rsync without deletion. Old DLLs and bundle trees can therefore keep loading; renamed DLLs can produce duplicate GUIDs. After installer pruning, use `scripts/install-plugins.sh prune-mirror <bepinex-dir> <docker-container>` to replay `.lembitu-removed` against that second copy (`docs/build.md:232-263`). Only plugin entries are replayed; configuration and patcher entries are consumed without a container deletion. A failed replay retains the ledger for retry. The tests exercise this through a fake Docker command, not a live container (`scripts/install-plugins.sh:188-220`; `test/install-plugins.test.sh:8-9,301-391`).

**A retired plugin must also leave the build output.** The installer treats `dist/` as its source, so stale locally built DLLs can be reinstalled unless the output is cleaned after a rename or removal. This became concrete when official BossRules replaced the temporary local authority guard: the recorded cutover requires clean output, normal installer pruning and separate container-mirror pruning (`docs/build.md:210-213,646-650`). ADR-0009's DLL-only installer warning is historical: complete asset-bundle deployment and pruning are now covered by the current installer tests (`docs/adr/0009-world-permanent-mods-land-before-world-creation.md:31-35`; `test/install-plugins.test.sh:62-118`).

**Apparently cosmetic configuration can carry permissions.** PvPBiomeDominions bypasses its tombstone-looting restriction when the alert toggle is off or its message is empty. The overlay therefore pins both an enabled alert and a non-empty message; changing that text to empty is not a harmless presentation choice (`config/enforced/Turbero.PvPBiomeDominions.cfg:34-41`).

**Successful file application is narrower than gameplay proof.** The merge tests protect same-named keys in different sections and make missing targets fail visibly, but cannot prove client authority, death retention or capacity under simultaneous connections. Historical evidence names those gaps explicitly; the latest full-pack report likewise separates its passing scenario from exhaustive mod-feature and two-client acceptance (`test/apply-enforced-config.test.sh:27-95`; `docs/modstack.md:165-183`; `docs/build.md:704-706`).
